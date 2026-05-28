import Foundation

enum WebViewJavaScripts {
    // Manual console examples:
    // window.AssistantMCP.extractTree({
    //   web: { body_text: { type: "text", selector: "body" } },
    //   flows: { body_exists: { selector: "body" } }
    // })
    // Expected: { web: { body_text: "..." }, flows: { body_exists: true } }
    //
    // window.AssistantMCP.executeShortcut({ key: "k", code: "KeyK", metaKey: true })
    static let assistantBridge = #"""
(() => {
  const root = window;
  const existing = root.AssistantMCP && typeof root.AssistantMCP === "object" ? root.AssistantMCP : {};

  function normalizeSelectors(node) {
    if (!node || typeof node !== "object") return [];
    const raw = [];
    if (typeof node.selector === "string") raw.push(node.selector);
    if (typeof node.query === "string") raw.push(node.query);
    if (Array.isArray(node.selectors)) raw.push(...node.selectors);
    if (Array.isArray(node.queries)) raw.push(...node.queries);
    return raw
      .filter((value) => typeof value === "string")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }

  function firstElement(context, node) {
    const selectors = normalizeSelectors(node);
    if (selectors.length === 0) return null;
    const searchRoot = context && typeof context.querySelector === "function" ? context : document;
    for (const selector of selectors) {
      try {
        const found = searchRoot.querySelector(selector);
        if (found) return found;
      } catch (_) {}
    }
    return null;
  }

  function allElements(context, node) {
    const selectors = normalizeSelectors(node);
    if (selectors.length === 0) return [];
    const searchRoot = context && typeof context.querySelectorAll === "function" ? context : document;
    for (const selector of selectors) {
      try {
        const found = Array.from(searchRoot.querySelectorAll(selector));
        if (found.length > 0) return found;
      } catch (_) {}
    }
    return [];
  }

  function textFromElement(element) {
    if (!element) return null;
    const raw = (element.innerText ?? element.textContent ?? "").trim();
    return raw.length > 0 ? raw : null;
  }

  function parseNumber(text) {
    if (typeof text !== "string") return null;
    const normalized = text.replace(/\./g, "").replace(",", ".");
    const match = normalized.match(/-?\d+(\.\d+)?/);
    if (!match) return null;
    const value = Number(match[0]);
    return Number.isFinite(value) ? value : null;
  }

  function normalizedType(node) {
    if (!node || typeof node !== "object") return "text";
    if (typeof node.type === "string" && node.type.trim().length > 0) return node.type.trim().toLowerCase();
    if (childrenFromNode(node)) return "element";
    return "text";
  }

  function childrenFromNode(node) {
    if (!node || typeof node !== "object") return null;
    const children = node.children ?? node.extract;
    if (children && typeof children === "object" && !Array.isArray(children)) return children;
    return null;
  }

  function fallbackNumberFromNode(node) {
    if (!node || typeof node !== "object") return null;
    if (typeof node.fallback_number === "number" && Number.isFinite(node.fallback_number)) {
      return node.fallback_number;
    }
    return null;
  }

  function nodeAttribute(node) {
    if (!node || typeof node !== "object") return null;
    if (typeof node.attribute === "string" && node.attribute.trim().length > 0) {
      return node.attribute.trim();
    }
    return null;
  }

  function valueFromRules(node) {
    if (!node || typeof node !== "object") return [];
    if (!Array.isArray(node.value_from)) return [];
    return node.value_from
      .filter((value) => typeof value === "string")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }

  function textIncludesAny(node) {
    if (!node || typeof node !== "object") return [];
    if (!Array.isArray(node.text_includes_any)) return [];
    return node.text_includes_any
      .filter((value) => typeof value === "string")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }

  function readValueFromElement(element, node) {
    if (!element) return null;

    const rules = valueFromRules(node);
    for (const rule of rules) {
      const [sourceKey, transform] = rule.split(":");
      const source = sourceKey.trim();
      const raw =
        source === "textContent"
          ? element.textContent
          : source === "innerText"
            ? element.innerText
            : source === "value"
              ? element.value
              : source === "ariaLabel"
                ? element.ariaLabel
                : source
                  ? element.getAttribute(source)
                  : null;

      if (typeof raw === "string") {
        const trimmed = raw.trim();
        if (trimmed.length === 0) continue;
        if (transform === "int") {
          const parsed = parseNumber(trimmed);
          if (parsed !== null) return String(parsed);
        } else {
          return trimmed;
        }
      }
    }

    const attribute = nodeAttribute(node);
    if (attribute) {
      const attr = element.getAttribute(attribute);
      if (typeof attr === "string") {
        const trimmed = attr.trim();
        if (trimmed.length > 0) return trimmed;
      }
      return null;
    }

    return textFromElement(element);
  }

  function extractChildren(children, context) {
    if (!children || typeof children !== "object") return {};
    const result = {};
    for (const key of Object.keys(children)) {
      result[key] = extractNode(children[key], context);
    }
    return result;
  }

  function extractNode(node, context) {
    const nodeType = normalizedType(node);

    const includesAny = textIncludesAny(node);
    if (includesAny.length > 0 && (nodeType === "boolean" || nodeType === "exists")) {
      const pageText = (document.body?.innerText ?? document.body?.textContent ?? "").toLowerCase();
      if (!pageText) return false;
      return includesAny.some((value) => pageText.includes(value.toLowerCase()));
    }

    if (nodeType === "elements") {
      const elements = allElements(context, node);
      if (elements.length === 0) return [];
      return elements.map((element) => {
        const children = childrenFromNode(node);
        if (children) {
          return extractChildren(children, element);
        }
        return readValueFromElement(element, node) ?? true;
      });
    }

    if (nodeType === "exists" || nodeType === "boolean") {
      const element = firstElement(context, node);
      return Boolean(element);
    }

    if (nodeType === "number") {
      const element = firstElement(context, node);
      if (!element) return fallbackNumberFromNode(node);
      const text = readValueFromElement(element, node);
      if (text === null) return fallbackNumberFromNode(node);
      const parsed = parseNumber(text);
      return parsed ?? fallbackNumberFromNode(node);
    }

    if (nodeType === "text") {
      const element = firstElement(context, node);
      if (!element) return null;
      return readValueFromElement(element, node);
    }

    const element = firstElement(context, node);
    if (!element) return null;
    const children = childrenFromNode(node);
    if (children) {
      return extractChildren(children, element);
    }
    return true;
  }

  function extractTree(spec) {
    try {
      if (!spec || typeof spec !== "object") {
        return { web: {}, flows: {} };
      }

      const result = { web: {}, flows: {} };

      if (spec.web && typeof spec.web === "object") {
        for (const key of Object.keys(spec.web)) {
          result.web[key] = extractNode(spec.web[key], document);
        }
      }

      if (spec.flows && typeof spec.flows === "object") {
        for (const key of Object.keys(spec.flows)) {
          const flowNode = spec.flows[key];
          const enforcedNode =
            flowNode && typeof flowNode === "object" && typeof flowNode.type === "string" && flowNode.type.trim().length > 0
              ? flowNode
              : { ...(flowNode || {}), type: "exists" };
          result.flows[key] = Boolean(extractNode(enforcedNode, document));
        }
      }

      return result;
    } catch (_) {
      return { web: {}, flows: {} };
    }
  }

  function parseShortcut(shortcut) {
    if (!shortcut || typeof shortcut !== "object") return null;

    let key = typeof shortcut.key === "string" ? shortcut.key : null;
    let code = typeof shortcut.code === "string" ? shortcut.code : null;
    let metaKey = Boolean(shortcut.metaKey);
    let ctrlKey = Boolean(shortcut.ctrlKey);
    let altKey = Boolean(shortcut.altKey);
    let shiftKey = Boolean(shortcut.shiftKey);

    if (Array.isArray(shortcut.keys) && shortcut.keys.length > 0) {
      const normalized = shortcut.keys
        .filter((item) => typeof item === "string")
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
      if (normalized.length > 0) {
        const last = normalized[normalized.length - 1];
        key = key ?? last;
        if (!code && last.length === 1) {
          code = "Key" + last.toUpperCase();
        }

        for (const item of normalized) {
          const upper = item.toUpperCase();
          if (upper === "META" || upper === "CMD" || upper === "COMMAND") metaKey = true;
          if (upper === "CTRL" || upper === "CONTROL") ctrlKey = true;
          if (upper === "ALT" || upper === "OPTION") altKey = true;
          if (upper === "SHIFT") shiftKey = true;
        }
      }
    }

    if (typeof key !== "string" || key.trim().length === 0) return null;
    key = key.trim();

    if (!code) {
      if (key.length === 1) code = "Key" + key.toUpperCase();
      else code = key;
    }

    return { key, code, metaKey, ctrlKey, altKey, shiftKey };
  }

  function executeShortcut(shortcut) {
    try {
      const parsed = parseShortcut(shortcut);
      if (!parsed) return false;

      const target = document.activeElement || document.body || document;
      if (!target || typeof target.dispatchEvent !== "function") return false;

      const base = {
        key: parsed.key,
        code: parsed.code,
        metaKey: parsed.metaKey,
        ctrlKey: parsed.ctrlKey,
        altKey: parsed.altKey,
        shiftKey: parsed.shiftKey,
        bubbles: true,
        cancelable: true
      };

      const downEvent = new KeyboardEvent("keydown", base);
      const upEvent = new KeyboardEvent("keyup", base);
      target.dispatchEvent(downEvent);
      target.dispatchEvent(upEvent);
      return true;
    } catch (_) {
      return false;
    }
  }

  root.AssistantMCP = {
    ...existing,
    extractTree,
    executeShortcut
  };
})();
"""#
}
