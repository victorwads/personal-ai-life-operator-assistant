import Foundation

/// Generic contract for "how to find something in the DOM and optionally extract children".
///
/// This is intentionally WebView-agnostic: it only models the YAML structure in typed form.
protocol WebElementFinder: Sendable {
    var type: String { get }
    var selectors: [String] { get }
    var textIncludesAny: [String]? { get }
    var extract: [String: WebElementSpec] { get }
}

struct WebElementSpec: WebElementFinder, Sendable, Equatable {
    let type: String
    let selectors: [String]
    let textIncludesAny: [String]?
    let extract: [String: WebElementSpec]

    // Extra generic knobs (used by some node types).
    let valueFrom: [String]?
    let attribute: String?
    let clipMaxChars: Int?

    static func from(any: AnySendable) -> WebElementSpec? {
        guard case .object(let dict) = any else { return nil }

        let type = dict["type"].flatMap { $0.stringValue } ?? "element"
        let selectors =
            dict["selector"]?.stringOrStringArrayValue ??
            dict["selectors"]?.stringOrStringArrayValue ??
            []
        let textIncludesAny = dict["text_includes_any"]?.stringArrayValue
        let valueFrom = dict["value_from"]?.stringArrayValue
        let attribute = dict["attribute"]?.stringValue
        let clipMaxChars = dict["clip_max_chars"]?.intValue

        var extract: [String: WebElementSpec] = [:]
        if let extractAny = dict["extract"], case .object(let extractDict) = extractAny {
            for (key, value) in extractDict {
                if let spec = WebElementSpec.from(any: value) {
                    extract[key] = spec
                }
            }
        }

        return WebElementSpec(
            type: type,
            selectors: selectors,
            textIncludesAny: textIncludesAny,
            extract: extract,
            valueFrom: valueFrom,
            attribute: attribute,
            clipMaxChars: clipMaxChars
        )
    }
}

private extension AnySendable {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var stringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        let strings = values.compactMap { $0.stringValue }
        guard strings.count == values.count else { return nil }
        return strings
    }

    var stringOrStringArrayValue: [String]? {
        if let s = stringValue { return [s] }
        return stringArrayValue
    }
}
