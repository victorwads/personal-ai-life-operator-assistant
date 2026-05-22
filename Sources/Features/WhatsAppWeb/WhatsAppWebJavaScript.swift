import Foundation

enum WhatsAppWebJavaScript {
    static let dumpDocumentScript = """
    (() => {
      const safe = (value) => {
        try { return typeof value === 'string' ? value : ''; } catch { return ''; }
      };
      const rawHTML = safe(document.documentElement?.outerHTML || '');
      return JSON.stringify({
        url: safe(window.location.href || ''),
        title: safe(document.title || ''),
        documentReadyState: safe(document.readyState || ''),
        rawHTML,
        capturedAt: new Date().toISOString()
      });
    })();
    """

    static func makeShortcutScript(modifiersJSONLiteral: String, keyJSONLiteral: String) -> String {
        """
        (() => {
          const modifiers = \(modifiersJSONLiteral);
          const key = \(keyJSONLiteral);

          const normalizedModifiers = Array.isArray(modifiers) ? modifiers.map((value) => String(value || '').toLowerCase()) : [];
          const modifierState = {
            altKey: normalizedModifiers.includes('alt') || normalizedModifiers.includes('option'),
            ctrlKey: normalizedModifiers.includes('ctrl') || normalizedModifiers.includes('control'),
            metaKey: normalizedModifiers.includes('cmd') || normalizedModifiers.includes('meta') || normalizedModifiers.includes('command'),
            shiftKey: normalizedModifiers.includes('shift')
          };

          const target = document.activeElement || document.body || document;
          const eventInit = {
            bubbles: true,
            cancelable: true,
            composed: true,
            key: String(key || ''),
            code: String(key || ''),
            ...modifierState
          };

          try { target.focus?.(); } catch {}
          try { target.dispatchEvent(new KeyboardEvent('keydown', eventInit)); } catch {}
          try { target.dispatchEvent(new KeyboardEvent('keypress', eventInit)); } catch {}
          try { target.dispatchEvent(new KeyboardEvent('keyup', eventInit)); } catch {}

          return JSON.stringify({
            result: "ok",
            key,
            modifiers: normalizedModifiers,
            activeElementTag: document.activeElement?.tagName || null
          });
        })();
        """
    }

    static func makeExtractionScript(specJSONLiteral: String) -> String {
        """
        (() => {
          const spec = \(specJSONLiteral);

          const pickText = (value) => typeof value === 'string' ? value.trim() : '';
          const toArray = (value) => {
            if (Array.isArray(value)) return value;
            if (typeof value === 'string') return [value];
            return [];
          };
          const isObj = (value) => value && typeof value === 'object' && !Array.isArray(value);
          const joinPath = (base, segment) => {
            if (!base) return String(segment || '');
            return `${base}.${String(segment || '')}`;
          };
          const itemPath = (base, index) => `${base}.items[${index}]`;

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

          const evalTextValue = (node, attributeName) => {
            if (attributeName) {
              const v = pickText(safeAttr(node, String(attributeName)) || '');
              return v || null;
            }
            return pickText(safeInnerText(node) || safeTextContent(node) || '') || null;
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

          const evalNode = (nodeSpec, root, path) => {
            const type = String(nodeSpec?.type || 'element');
            const selectors = (nodeSpec?.selector != null) ? nodeSpec.selector : nodeSpec?.selectors;
            const extract = isObj(nodeSpec?.extract) ? nodeSpec.extract : {};
            const clipMax = (typeof nodeSpec?.clip_max_chars === 'number') ? nodeSpec.clip_max_chars : null;

            const withFound = (found, payload) => Object.assign({
              type,
              found: !!found,
              path: path || null,
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
                  const res = evalNode(child, document, joinPath(path || '', 'requires_any'));
                  return !!res.found;
                });
              }
              const ok = !!textMatch && !!requiresMatch;
              return withFound(ok, { ok });
            }

            if (type === 'elements') {
              const nodes = findMany(root, selectors);
              const limited = nodes.slice(0, 50);
              const items = limited.map((el, index) => {
                const children = {};
                for (const key of Object.keys(extract)) {
                  children[key] = evalNode(extract[key], el, joinPath(itemPath(path || '', index), `extract.${key}`));
                }
                return {
                  type: 'element',
                  found: true,
                  path: itemPath(path || '', index),
                  outerHTML: clipMax ? (safeOuterHTML(el) || '').slice(0, clipMax) : safeOuterHTML(el),
                  extract: children
                };
              });
              return withFound(items.length > 0, { count: items.length, items });
            }

            const found = findOne(root, selectors);
            if (!found) return withFound(false, { extract: {} });

            const children = {};
            for (const key of Object.keys(extract)) {
              children[key] = evalNode(extract[key], found, joinPath(path || '', `extract.${key}`));
            }

            if (type === 'text') {
              const value = evalTextValue(found, nodeSpec?.attribute);
              return withFound(true, { value, extract: children });
            }
            if (type === 'number') {
              const value = evalValueFrom(found, nodeSpec?.value_from);
              const n = (typeof value === 'number') ? value : null;
              const fallbackNumber = (typeof nodeSpec?.fallback_number === 'number') ? nodeSpec.fallback_number : null;
              return withFound(true, { value: n ?? fallbackNumber, extract: children });
            }
            // default: element
            const html = safeOuterHTML(found);
            const clipped = clipMax && typeof html === 'string' ? html.slice(0, clipMax) : html;
            return withFound(true, { outerHTML: clipped, extract: children });
          };

          const rootTree = {};
          for (const key of Object.keys(spec || {})) {
            rootTree[key] = evalNode(spec[key], document, key);
          }

          return JSON.stringify({
            result: "ok",
            tree: rootTree
          });
        })();
        """
    }

    static let installLockOverlayScript = """
    (() => {
      const overlayId = 'assistant-mcp-lock-overlay';
      if (document.getElementById(overlayId)) {
        const existing = document.getElementById(overlayId);
        existing.focus?.();
        return true;
      }

      const overlay = document.createElement('div');
      overlay.id = overlayId;
      overlay.tabIndex = 0;
      overlay.setAttribute('aria-hidden', 'true');
      overlay.style.position = 'fixed';
      overlay.style.top = '0';
      overlay.style.left = '0';
      overlay.style.width = '100vw';
      overlay.style.height = '100vh';
      overlay.style.zIndex = '2147483647';
      overlay.style.background = 'transparent';
      overlay.style.pointerEvents = 'auto';
      overlay.style.cursor = 'not-allowed';

      const stop = (e) => {
        try {
          e.preventDefault();
          e.stopPropagation();
          if (e.stopImmediatePropagation) e.stopImmediatePropagation();
        } catch {}
        return false;
      };

      const eventTypes = [
        'click','dblclick','mousedown','mouseup','mousemove','mouseover','mouseenter','mouseleave','mouseout',
        'contextmenu','wheel','scroll',
        'keydown','keyup','keypress',
        'touchstart','touchmove','touchend',
        'pointerdown','pointerup','pointermove','pointerenter','pointerleave','pointercancel',
        'dragstart','drag','dragend','drop'
      ];

      for (const type of eventTypes) {
        overlay.addEventListener(type, stop, { capture: true, passive: false });
      }

      const body = document.body || document.documentElement;
      body.appendChild(overlay);
      overlay.focus();
      return true;
    })();
    """

    static let removeLockOverlayScript = """
    (() => {
      const overlayId = 'assistant-mcp-lock-overlay';
      const overlay = document.getElementById(overlayId);
      if (!overlay) return true;
      overlay.remove();
      return true;
    })();
    """
}
