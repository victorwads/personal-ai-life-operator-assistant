const OriginalRequestAnimationFrame = window.requestAnimationFrame;
const OriginalBlob = Blob;
const OriginalCreateObjectURL = URL.createObjectURL;

(() => {
  let elementRegistry = {};
  let elementCounter = 0;

  function resetElementRegistry() {
    elementRegistry = {};
  }

  function registerInteractiveElement(element) {
    elementCounter += 1;
    const id = "amcp_el_" + elementCounter;
    elementRegistry[id] = element;
    return { "$element": true, id };
  }

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
    const raw = getReadableText(element).trim();
    return raw.length > 0 ? raw : null;
  }

  function getReadableText(node) {
    if (!node) return "";

    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent || "";
    }

    if (node.nodeType !== Node.ELEMENT_NODE) {
      return "";
    }

    const el = node;

    if (el.tagName === "IMG") {
      return (
        el.getAttribute("data-plain-text") ||
        el.getAttribute("alt") ||
        el.getAttribute("aria-label") ||
        ""
      );
    }

    if (el.getAttribute("aria-hidden") === "true") {
      return "";
    }

    return Array.from(el.childNodes)
      .map(getReadableText)
      .join("");
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

  function isInteractiveNode(node) {
    return Boolean(node && typeof node === "object" && node.interactive === true);
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
      const extracted = extractNode(children[key], context);
      if (extracted !== null && extracted !== undefined) {
        result[key] = extracted;
      }
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
    if (isInteractiveNode(node)) {
      return registerInteractiveElement(element);
    }
    const children = childrenFromNode(node);
    if (children) {
      return extractChildren(children, element);
    }
    return true;
  }

  function extractTree(spec) {
    try {
      resetElementRegistry();
      if (!spec || typeof spec !== "object") {
        return { web: {}, flows: {} };
      }

      const result = { web: {}, flows: {} };

      if (spec.web && typeof spec.web === "object") {
        for (const key of Object.keys(spec.web)) {
          const extracted = extractNode(spec.web[key], document);
          if (extracted !== null && extracted !== undefined) {
            result.web[key] = extracted;
          }
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

  function dispatchMouseSequence(element) {
    const rect = element.getBoundingClientRect();
    const clientX = rect.left + rect.width / 2;
    const clientY = rect.top + rect.height / 2;
    const mouseInit = {
      bubbles: true,
      cancelable: true,
      composed: true,
      view: window,
      clientX,
      clientY
    };
    const pointerInit = {
      bubbles: true,
      cancelable: true,
      composed: true,
      pointerType: "mouse",
      isPrimary: true,
      clientX,
      clientY
    };

    const pointerEvents = ["pointerover", "pointerenter", "pointerdown", "pointerup"];
    for (const type of pointerEvents) {
      try { element.dispatchEvent(new PointerEvent(type, pointerInit)); } catch (_) {}
    }

    const mouseEvents = ["mouseover", "mouseenter", "mousedown", "mouseup", "click"];
    for (const type of mouseEvents) {
      try { element.dispatchEvent(new MouseEvent(type, mouseInit)); } catch (_) {}
    }
  }

  function imageElementFrom(element) {
    if (!element) return null;
    if (element.tagName === "IMG") return element;

    try {
      const img = element.querySelector && element.querySelector("img");
      if (img) return img;
    } catch (_) {}

    return null;
  }

  function extractImageData(image) {
    try {
      if (!image) return null;

      const width = image.naturalWidth || image.width || 0;
      const height = image.naturalHeight || image.height || 0;
      if (width <= 0 || height <= 0) return null;

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;

      const context = canvas.getContext("2d");
      if (!context) return null;

      context.drawImage(image, 0, 0, width, height);

      const dataURL = canvas.toDataURL("image/png");
      if (typeof dataURL !== "string" || dataURL.length === 0) return null;

      const commaIndex = dataURL.indexOf(",");
      if (commaIndex < 0) return null;

      const header = dataURL.substring(0, commaIndex);
      const base64 = dataURL.substring(commaIndex + 1);

      const mimeMatch = header.match(/^data:(.*?);base64$/);
      const mimeType = mimeMatch ? mimeMatch[1] : "image/png";

      return {
        base64,
        mimeType,
        width,
        height,
        source: image.currentSrc || image.src || null
      };
    } catch (_) {
      return null;
    }
  }

  function isLargeEnoughImage(image) {
    try {
      if (!image) return false;
      const width = image.naturalWidth || image.width || 0;
      const height = image.naturalHeight || image.height || 0;
      return Number.isFinite(width) && Number.isFinite(height) && width >= 100 && height >= 100;
    } catch (_) {
      return false;
    }
  }

  function dedupeExtractedImages(items) {
    const result = [];
    const seen = new Set();

    for (const item of items) {
      if (!item || typeof item !== "object") continue;
      const width = Number(item.width || 0);
      const height = Number(item.height || 0);
      if (!Number.isFinite(width) || !Number.isFinite(height) || width < 100 || height < 100) continue;

      const source = typeof item.source === "string" && item.source.length > 0 ? item.source : null;
      const base64 = typeof item.base64 === "string" && item.base64.length > 0 ? item.base64 : null;
      const key = source
        ? `${source}|${width}|${height}`
        : `${width}|${height}|${base64 ? base64.length : 0}`;
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(item);
    }

    return result;
  }

  function extractImagesFromElements(elements) {
    try {
      if (!Array.isArray(elements) || elements.length === 0) return [];

      const extracted = [];
      for (const id of elements) {
        if (typeof id !== "string" || id.trim().length === 0) continue;
        const element = elementRegistry[id];
        if (!element) continue;

        const image = imageElementFrom(element);
        if (!image || !isLargeEnoughImage(image)) continue;

        try { image.scrollIntoView({ block: "center", inline: "center" }); } catch (_) {}
        focusFocusableAncestor(image);

        const record = extractImageData(image);
        if (record) {
          extracted.push(record);
          continue;
        }

        const source = image.currentSrc || image.src || null;
        if (!source) continue;
        extracted.push({
          width: image.naturalWidth || image.width || 0,
          height: image.naturalHeight || image.height || 0,
          source
        });
      }

      return dedupeExtractedImages(extracted);
    } catch (_) {
      return [];
    }
  }

  function focusFocusableAncestor(element) {
    try {
      let current = element;
      while (current) {
        try {
          if (typeof current.focus === "function") {
            current.focus();
            if (document.activeElement === current) return true;
          }
        } catch (_) {}
        current = current.parentElement || null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  function interactWithElement(id, action, payload) {
    try {
      if (typeof id !== "string" || id.trim().length === 0) return false;
      if (typeof action !== "string" || action.trim().length === 0) return false;
      const element = elementRegistry[id];
      if (!element) return false;

      const normalizedAction = action.trim();
      if (normalizedAction === "extractImage") {
        const image = imageElementFrom(element);
        if (!image) return null;
        try { image.scrollIntoView({ block: "center", inline: "center" }); } catch (_) {}
        focusFocusableAncestor(image);
        const extracted = extractImageData(image);
        if (extracted) return extracted;
        const source = image.currentSrc || image.src || null;
        if (!source) return null;
        return {
          width: image.naturalWidth || image.width || 0,
          height: image.naturalHeight || image.height || 0,
          source
        };
      }
      try { element.scrollIntoView({ block: "center", inline: "center" }); } catch (_) {}

      if (normalizedAction === "click") {
        try { if (typeof element.focus === "function") element.focus(); } catch (_) {}
        dispatchMouseSequence(element);
        try { if (typeof element.click === "function") element.click(); } catch (_) {}
        return true;
      }

      if (normalizedAction === "focus") {
        try { if (typeof element.focus === "function") element.focus(); } catch (_) {}
        return true;
      }

      if (normalizedAction === "type") {
        if (!payload || typeof payload !== "object") return false;
        if (typeof payload.text !== "string") return false;
        const text = payload.text;
        try { if (typeof element.focus === "function") element.focus(); } catch (_) {}

        if (element.isContentEditable) {
          let insertSucceeded = (() => {
            try {
              if (typeof document.execCommand === "function") {
                try { document.execCommand("selectAll", false, null); } catch (_) {}
                try { document.execCommand("delete", false, null); } catch (_) {}
                return document.execCommand("insertText", false, text) === true;
              }
            } catch (_) {}
            return false;
          })();

          if (!insertSucceeded) {
            try {
              element.textContent = text;
            } catch (_) {}
          }

          if (!insertSucceeded) {
            try {
              element.dispatchEvent(new InputEvent("input", {
                inputType: "insertText",
                data: text,
                bubbles: true,
                cancelable: true,
                composed: true
              }));
            } catch (_) {}
          }
          return true;
        }

        if ("value" in element && typeof element.value === "string") {
          try {
            if (typeof element.select === "function") {
              try { element.select(); } catch (_) {}
            }

            if (typeof element.setSelectionRange === "function" && typeof element.setRangeText === "function") {
              try {
                const current = String(element.value || "");
                element.setSelectionRange(0, current.length);
                element.setRangeText(text);
              } catch (_) {
                element.value = text;
              }
            } else {
              element.value = text;
            }

            element.dispatchEvent(new Event("input", { bubbles: true, cancelable: true, composed: true }));
            element.dispatchEvent(new Event("change", { bubbles: true, cancelable: true, composed: true }));
            return true;
          } catch (_) {
            return false;
          }
        }

        return false;
      }

      if (normalizedAction === "pressEnter") {
        try { if (typeof element.focus === "function") element.focus(); } catch (_) {}
        const init = {
          key: "Enter",
          code: "Enter",
          keyCode: 13,
          which: 13,
          bubbles: true,
          cancelable: true,
          composed: true
        };
        try {
          element.dispatchEvent(new KeyboardEvent("keydown", init));
          element.dispatchEvent(new KeyboardEvent("keyup", init));
          return true;
        } catch (_) {
          return false;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  function interactWithElements(ids, action, payload) {
    try {
      if (!Array.isArray(ids) || ids.length === 0) return [];
      if (typeof action !== "string" || action.trim().length === 0) return [];

      const normalizedAction = action.trim();
      if (normalizedAction === "extractImages") {
        return extractImagesFromElements(ids);
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  function interactWithElementCommand(command) {
    try {
      if (!command || typeof command !== "object") return false;
      const id = typeof command.id === "string" ? command.id : "";
      const action = typeof command.action === "string" ? command.action : "";
      const payload =
        command.payload && typeof command.payload === "object"
          ? command.payload
          : null;
      return interactWithElement(id, action, payload);
    } catch (_) {
      return false;
    }
  }

  function interactWithElementsCommand(command) {
    try {
      if (!command || typeof command !== "object") return [];
      const ids = Array.isArray(command.ids) ? command.ids : [];
      const action = typeof command.action === "string" ? command.action : "";
      const payload =
        command.payload && typeof command.payload === "object"
          ? command.payload
          : null;
      return interactWithElements(ids, action, payload);
    } catch (_) {
      return [];
    }
  }


  /**
   * Executes a keyboard shortcut on the currently focused element.
   *
   * Examples:
   *
   * executeShortcut({
   *   keys: ["Escape"]
   * });
   *
   * executeShortcut({
   *   keys: ["Control", "Shift", "D"]
   * });
   *
   * Supported modifiers:
   * - Control
   * - Shift
   * - Alt
   * - Meta
   *
   * The last non-modifier key becomes the primary key.
   *
   * @param {{
   *   keys: string[]
   * }} shortcut
   * @returns {boolean}
   */
  function executeShortcut(shortcut) {
    try {
      const keys = shortcut?.keys;

      if (!Array.isArray(keys) || keys.length === 0) {
        return false;
      }

      const normalized = keys
        .filter(key => typeof key === "string")
        .map(key => key.trim())
        .filter(Boolean);

      if (normalized.length === 0) {
        return false;
      }

      const modifiers = new Set(
        normalized.map(key => key.toLowerCase())
      );

      const key =
        normalized.findLast(key =>
          !["control", "ctrl", "shift", "alt", "meta", "command", "cmd"].includes(
            key.toLowerCase()
          )
        ) ?? normalized[normalized.length - 1];

      const event = {
        key,
        code: key.length === 1 ? `Key${key.toUpperCase()}` : key,
        ctrlKey: modifiers.has("control") || modifiers.has("ctrl"),
        shiftKey: modifiers.has("shift"),
        altKey: modifiers.has("alt"),
        metaKey:
          modifiers.has("meta") ||
          modifiers.has("command") ||
          modifiers.has("cmd"),
        bubbles: true,
        cancelable: true
      };

      const target =
        document.activeElement ??
        document.body ??
        document;

      target.dispatchEvent(
        new KeyboardEvent("keydown", event)
      );

      target.dispatchEvent(
        new KeyboardEvent("keyup", event)
      );

      return true;
    } catch {
      return false;
    }
  }

  window.AssistantMCP = {
    ...window.AssistantMCP || {},
    extractTree,
    executeShortcut,
    interactWithElement,
    interactWithElementCommand,
    interactWithElements,
    interactWithElementsCommand
  };
  // No Animation
//  window.requestAnimationFrame = () => 0;
  const noAnimationStyle = document.createElement("style");
  noAnimationStyle.innerHTML = `
*,
*::before,
*::after {
    animation: none !important;
    animation-duration: 0s !important;
    animation-delay: 0s !important;
    transition: none !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    scroll-behavior: auto !important;
}
`;
  document.head.appendChild(noAnimationStyle);
})();

(() => {
  let MediaInterceptor = {
    wantedMimeTypes: [
      "audio/ogg",
    ],
    running: false,
    entries: []
  };

  URL.createObjectURL = function(blob) {
    try {
      const mimeType = blob?.type ?? "";

      const shouldCapture = MediaInterceptor.running &&
        MediaInterceptor.wantedMimeTypes.some(
          wanted => mimeType.startsWith(wanted)
        );

      if (shouldCapture) {
        MediaInterceptor.entries.push({
          blob,
          mimeType,
          size: blob.size,
          timestamp: Date.now()
        });
        console.log(
          new Date().toISOString(),
          "[MediaInterceptor]",
          mimeType,
          blob.size
        );
      }
    } catch (error) {
      console.error(error);
    }

    return OriginalCreateObjectURL.call(this, blob);
  };

  MediaInterceptor.cleanup = function(stop = false) {
    MediaInterceptor.entries = [];
    if (MediaInterceptor.running && stop) {
      console.log(new Date().toISOString(), "[MediaInterceptor] Stopped and cleaned up");
    } else if (!MediaInterceptor.running && !stop) {
      console.log(new Date().toISOString(), "[MediaInterceptor] Started");
    } else {
      console.log(new Date().toISOString(), "[MediaInterceptor] Cleaned up");
    }
    MediaInterceptor.running = !stop;
    return true;
  };

  /**
   * Consumes a captured media entry and returns its data as base64.
   *
   * @param {number} index - The index of the captured media entry to consume
   * @param {string} type - The MIME type prefix to filter captured media (e.g., "audio/ogg"). optionally consume all media if not provided
   * @returns {Promise<{ mimeType: string, size: number, timestamp: number, base64: string }>}
   */
  MediaInterceptor.consume = async function(index, type) {
    const item = MediaInterceptor.entries
      .filter(entry => (!type) || entry.mimeType.startsWith(type))
      [index];

    if (!item) {
      console.log(new Date().toISOString(), "[MediaInterceptor] No media entry found at index", index, "with type", type);
      return null;
    }

    const buffer = await item.blob.arrayBuffer();

    let binary = "";
    const bytes = new Uint8Array(buffer);

    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }

    let result =  {
      mimeType: item.mimeType,
      size: item.size,
      timestamp: item.timestamp,
      base64: btoa(binary)
    };
    console.log(new Date().toISOString(), "[MediaInterceptor] Consumed media entry at index", index, result);
    return result;
  };

  // TO DEDUG:
  MediaInterceptor.play = function(capturedMedia) {
    const binary = atob(capturedMedia.base64);
    const bytes = new Uint8Array(binary.length);

    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
    }

    const blob = new OriginalBlob([bytes], { type: capturedMedia.mimeType });
    const url = OriginalCreateObjectURL(blob);

    const audio = document.createElement("audio");
    audio.src = url;
    audio.controls = true;

    document.body.appendChild(audio);
    audio.play();

    return {
      cancel() {
        audio.pause();
        audio.removeAttribute("src");
        audio.load();
        audio.remove();
        URL.revokeObjectURL(url);
      }
    };
  }

  window.AssistantMCP.MediaInterceptor = MediaInterceptor
})();
