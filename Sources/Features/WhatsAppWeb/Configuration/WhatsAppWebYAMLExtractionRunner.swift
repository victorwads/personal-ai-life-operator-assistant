import Foundation
import WebKit

enum WhatsAppWebYAMLExtractionRunnerError: LocalizedError {
    case invalidSpecRoot
    case invalidResultPayload

    var errorDescription: String? {
        switch self {
        case .invalidSpecRoot:
            return "Invalid YAML spec. Expected a root object."
        case .invalidResultPayload:
            return "Invalid extraction result payload."
        }
    }
}

@MainActor
final class WhatsAppWebYAMLExtractionRunner {
    struct RunResult: Sendable, Equatable {
        let json: String
        let tree: AnySendable
    }

    func run(yamlTree: YAMLTree, webView: WKWebView) async throws -> RunResult {
        let specAny: AnySendable = .object(yamlTree.root)
        let specJSON = try AnySendableJSON.encodeToJSONString(specAny)
        let script = Self.makeExtractionScript(specJSONLiteral: specJSON)
        let json = try await evaluateJavaScriptString(script, in: webView)

        guard let data = json.data(using: String.Encoding.utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let any = AnySendableJSON.decodeFromJSONObject(obj) else {
            throw WhatsAppWebYAMLExtractionRunnerError.invalidResultPayload
        }

        return RunResult(json: json, tree: any)
    }

    private func evaluateJavaScriptString(_ javaScript: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else if let result {
                    continuation.resume(returning: String(describing: result))
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private static func makeExtractionScript(specJSONLiteral: String) -> String {
        """
        (() => {
          const spec = \(specJSONLiteral);

          const pickText = (value) => typeof value === 'string' ? value.trim() : '';
          const toArray = (value) => Array.isArray(value) ? value : [];
          const isObj = (value) => value && typeof value === 'object' && !Array.isArray(value);

          const safeOuterHTML = (node) => {
            try { return node && node.outerHTML ? String(node.outerHTML) : null; } catch { return null; }
          };
          const safeInnerText = (node) => {
            try { return node && typeof node.innerText === 'string' ? node.innerText : null; } catch { return null; }
          };
          const safeTextContent = (node) => {
            try { return node && typeof node.textContent === 'string' ? node.textContent : null; } catch { return null; }
          };
          const safeAttr = (node, name) => {
            try { return node && node.getAttribute ? node.getAttribute(name) : null; } catch { return null; }
          };

          const evalValueFrom = (node, valueFrom) => {
            const ops = toArray(valueFrom);
            if (ops.length === 0) {
              // default heuristic
              return pickText(safeInnerText(node) || safeTextContent(node) || '') || null;
            }
            for (const op of ops) {
              const s = String(op || '');
              if (s === 'textContent') {
                const v = pickText(safeTextContent(node) || '');
                if (v) return v;
              } else if (s === 'innerText') {
                const v = pickText(safeInnerText(node) || '');
                if (v) return v;
              } else if (s.startsWith('attribute:')) {
                const name = s.slice('attribute:'.length);
                const v = pickText(safeAttr(node, name) || '');
                if (v) return v;
              } else if (s === 'textContent:int') {
                const v = pickText(safeTextContent(node) || '');
                const n = parseInt(v, 10);
                if (!Number.isNaN(n)) return n;
              }
            }
            return null;
          };

          const findOne = (root, selectors) => {
            for (const selector of toArray(selectors)) {
              const sel = String(selector || '');
              if (!sel) continue;
              if (sel === 'document') return document;
              try {
                const node = (root || document).querySelector(sel);
                if (node) return node;
              } catch {}
            }
            return null;
          };

          const findMany = (root, selectors) => {
            for (const selector of toArray(selectors)) {
              const sel = String(selector || '');
              if (!sel) continue;
              try {
                const nodes = Array.from((root || document).querySelectorAll(sel));
                if (nodes.length > 0) return nodes;
              } catch {}
            }
            return [];
          };

          const evalNode = (nodeSpec, root) => {
            const type = String(nodeSpec?.type || 'element');
            const selectors = nodeSpec?.selectors;
            const fallback = nodeSpec?.fallback;
            const extract = isObj(nodeSpec?.extract) ? nodeSpec.extract : {};
            const clipMax = (typeof nodeSpec?.clip_max_chars === 'number') ? nodeSpec.clip_max_chars : null;

            const withFound = (found, payload) => Object.assign({
              type,
              found: !!found,
            }, payload || {});

            if (type === 'flow') {
              const textIncludesAny = toArray(nodeSpec?.text_includes_any).map((s) => String(s || '')).filter(Boolean);
              const bodyText = pickText(document.body?.innerText || '');
              let textMatch = true;
              if (textIncludesAny.length > 0) {
                textMatch = textIncludesAny.some((needle) => bodyText.includes(needle));
              }
              const requiresAny = toArray(nodeSpec?.requires_any);
              let requiresMatch = true;
              if (requiresAny.length > 0) {
                requiresMatch = requiresAny.some((child) => {
                  const res = evalNode(child, document);
                  return !!res.found;
                });
              }
              const ok = !!textMatch && !!requiresMatch;
              return withFound(ok, { ok });
            }

            const resolveRoot = (rootCandidate) => {
              if (!fallback || !isObj(fallback)) return rootCandidate;
              const kind = String(fallback.kind || '');
              if (kind === 'document') return document;
              // ref is resolved by falling back to document for now.
              return rootCandidate;
            };

            if (type === 'elements') {
              const resolvedRoot = resolveRoot(root);
              const nodes = findMany(resolvedRoot, selectors);
              const limited = nodes.slice(0, 50);
              const items = limited.map((el) => {
                const children = {};
                for (const key of Object.keys(extract)) {
                  children[key] = evalNode(extract[key], el);
                }
                return {
                  type: 'element',
                  found: true,
                  outerHTML: clipMax ? (safeOuterHTML(el) || '').slice(0, clipMax) : safeOuterHTML(el),
                  extract: children
                };
              });
              return withFound(items.length > 0, { count: items.length, items });
            }

            const resolvedRoot = resolveRoot(root);
            const found = findOne(resolvedRoot, selectors);
            if (!found) return withFound(false, { extract: {} });

            const children = {};
            for (const key of Object.keys(extract)) {
              children[key] = evalNode(extract[key], found);
            }

            if (type === 'text') {
              const value = evalValueFrom(found, nodeSpec?.value_from);
              return withFound(true, { value, extract: children });
            }
            if (type === 'number') {
              const value = evalValueFrom(found, nodeSpec?.value_from);
              const n = (typeof value === 'number') ? value : null;
              const fallbackNumber = (typeof nodeSpec?.fallback_number === 'number') ? nodeSpec.fallback_number : null;
              return withFound(true, { value: n ?? fallbackNumber, extract: children });
            }
            if (type === 'html') {
              const html = safeOuterHTML(found);
              const clipped = clipMax && typeof html === 'string' ? html.slice(0, clipMax) : html;
              return withFound(true, { html: clipped, extract: children });
            }

            // default: element
            const html = safeOuterHTML(found);
            const clipped = clipMax && typeof html === 'string' ? html.slice(0, clipMax) : html;
            return withFound(true, { outerHTML: clipped, extract: children });
          };

          const rootExtract = {};
          const flows = isObj(spec?.flows) ? spec.flows : {};
          const web = isObj(spec?.web) ? spec.web : {};

          const flowsOut = {};
          for (const key of Object.keys(flows)) {
            flowsOut[key] = evalNode(flows[key], document);
          }

          const webOut = {};
          for (const key of Object.keys(web)) {
            webOut[key] = evalNode(web[key], document);
          }

          rootExtract.schema_version = spec?.schema_version ?? null;
          rootExtract.version = spec?.version ?? null;
          rootExtract.flows = flowsOut;
          rootExtract.web = webOut;
          return JSON.stringify(rootExtract);
        })();
        """
    }
}

enum AnySendableJSON {
    static func encodeToJSONString(_ value: AnySendable) throws -> String {
        let obj = encodeToJSONObject(value)
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func encodeToJSONObject(_ value: AnySendable) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let v):
            return v
        case .int(let v):
            return v
        case .double(let v):
            return v
        case .string(let v):
            return v
        case .array(let values):
            return values.map(encodeToJSONObject)
        case .object(let dict):
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, value) in dict {
                out[key] = encodeToJSONObject(value)
            }
            return out
        }
    }

    static func decodeFromJSONObject(_ value: Any?) -> AnySendable? {
        guard let value else { return .null }
        if value is NSNull { return .null }
        if let bool = value as? Bool { return .bool(bool) }
        if let int = value as? Int { return .int(int) }
        if let double = value as? Double { return .double(double) }
        if let number = value as? NSNumber {
            let type = String(cString: number.objCType)
            if type == "c" { return .bool(number.boolValue) }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            if fabs(doubleValue - Double(intValue)) < .ulpOfOne {
                return .int(intValue)
            }
            return .double(doubleValue)
        }
        if let string = value as? String { return .string(string) }
        if let array = value as? [Any] {
            return .array(array.compactMap { decodeFromJSONObject($0) })
        }
        if let dict = value as? [String: Any] {
            var out: [String: AnySendable] = [:]
            out.reserveCapacity(dict.count)
            for (key, value) in dict {
                out[key] = decodeFromJSONObject(value) ?? .null
            }
            return .object(out)
        }
        return nil
    }
}
