import Foundation

@MainActor
final class WhatsAppNativeYAMLExtractionRunner {
    struct RunResult: Sendable, Equatable {
        let tree: AnySendable
    }

    func run(yamlTree: YAMLTree, snapshotRoot: RawAXNode) throws -> RunResult {
        let specAny: AnySendable = .object(yamlTree.root)
        guard case .object(let specDict) = specAny else {
            throw YAMLTreeError.invalidRoot
        }

        let flowsSpec = (specDict["flows"]?.objectValue) ?? [:]
        let nativeSpec = (specDict["native"]?.objectValue) ?? [:]

        var flowsOut: [String: AnySendable] = [:]
        for key in flowsSpec.keys.sorted() {
            flowsOut[key] = evalNode(flowsSpec[key] ?? .null, in: snapshotRoot)
        }

        var nativeOut: [String: AnySendable] = [:]
        for key in nativeSpec.keys.sorted() {
            nativeOut[key] = evalNode(nativeSpec[key] ?? .null, in: snapshotRoot)
        }

        var rootOut: [String: AnySendable] = [:]
        rootOut["schema_version"] = specDict["schema_version"] ?? .null
        rootOut["version"] = specDict["version"] ?? .null
        rootOut["type"] = specDict["type"] ?? .null
        rootOut["flows"] = .object(flowsOut)
        rootOut["native"] = .object(nativeOut)
        return RunResult(tree: .object(rootOut))
    }

    private func evalNode(_ nodeSpec: AnySendable, in root: RawAXNode) -> AnySendable {
        guard case .object(let dict) = nodeSpec else {
            return .object(["found": .bool(false)])
        }

        let type = dict["type"]?.stringValue ?? "element"

        if type == "flow" {
            let requiresAny = dict["requires_any"]?.arrayValue ?? []
            let ok = requiresAny.isEmpty || requiresAny.contains { childSpec in
                if case .object(let resDict) = evalNode(childSpec, in: root),
                   case .bool(let found)? = resDict["found"] {
                    return found
                }
                return false
            }
            return .object(["type": .string(type), "found": .bool(ok), "ok": .bool(ok)])
        }

        if type == "elements" {
            let matches = findMany(dict: dict, in: root)
            let limited = Array(matches.prefix(50))
            let items: [AnySendable] = limited.enumerated().map { index, node in
                var out: [String: AnySendable] = [
                    "type": .string("element"),
                    "found": .bool(true),
                    "path": .string(node.accessibilityPath.map(String.init).joined(separator: ".")),
                    "role": .string(node.role ?? ""),
                ]
                if let extractAny = dict["extract"], case .object(let extractDict) = extractAny {
                    var extractOut: [String: AnySendable] = [:]
                    for key in extractDict.keys.sorted() {
                        extractOut[key] = evalNode(extractDict[key] ?? .null, in: node)
                    }
                    out["extract"] = .object(extractOut)
                } else {
                    out["extract"] = .object([:])
                }
                out["index"] = .int(index)
                return .object(out)
            }
            return .object([
                "type": .string(type),
                "found": .bool(!items.isEmpty),
                "count": .int(items.count),
                "items": .array(items),
            ])
        }

        guard let found = findOne(dict: dict, in: root) else {
            return .object(["type": .string(type), "found": .bool(false), "extract": .object([:])])
        }

        var childrenOut: [String: AnySendable] = [:]
        if let extractAny = dict["extract"], case .object(let extractDict) = extractAny {
            for key in extractDict.keys.sorted() {
                childrenOut[key] = evalNode(extractDict[key] ?? .null, in: found)
            }
        }

        if type == "text" {
            let value = extractText(from: found, dict: dict)
            return .object(["type": .string(type), "found": .bool(true), "value": value ?? .null, "extract": .object(childrenOut)])
        }

        if type == "number" {
            let value = extractNumber(from: found, dict: dict)
            return .object(["type": .string(type), "found": .bool(true), "value": value ?? .null, "extract": .object(childrenOut)])
        }

        // default: element
        return .object([
            "type": .string(type),
            "found": .bool(true),
            "path": .string(found.accessibilityPath.map(String.init).joined(separator: ".")),
            "role": .string(found.role ?? ""),
            "extract": .object(childrenOut),
        ])
    }

    private func extractText(from node: RawAXNode, dict: [String: AnySendable]) -> AnySendable? {
        let source = dict["from"]?.stringValue ?? "all_text"
        let parse = dict["parse"]?.stringValue

        let raw: String = switch source {
        case "title":
            node.title ?? ""
        case "description":
            node.nodeDescription ?? ""
        case "help":
            node.help ?? ""
        case "value":
            node.stringValue ?? ""
        default:
            node.ownTextFragments.joined(separator: " ")
        }

        let normalized = raw.normalizedAXText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty, parse == nil { return nil }

        if let parse {
            switch parse {
            case "conversation_name":
                let value = parseConversationName(fromDescription: normalized)
                return value.map(AnySendable.string)
            case "conversation_preview":
                let parsed = parseConversationValue(fromValue: normalized)
                return parsed.preview.map(AnySendable.string)
            case "conversation_time":
                let parsed = parseConversationValue(fromValue: normalized)
                return parsed.timeText.map(AnySendable.string)
            case "message_text":
                let parsed = parseMessageDescription(normalized)
                return parsed.text.map(AnySendable.string)
            case "message_timestamp":
                let parsed = parseMessageDescription(normalized)
                return parsed.timestampText.map(AnySendable.string)
            case "message_author":
                let parsed = parseMessageDescription(normalized)
                return parsed.authorName.map(AnySendable.string)
            case "message_direction":
                let parsed = parseMessageDescription(normalized)
                return .string(parsed.direction.rawValue)
            case "message_kind":
                let parsed = parseMessageDescription(normalized)
                return .string(parsed.kind.rawValue)
            case "message_status":
                let parsed = parseMessageDescription(normalized)
                return .string(parsed.status.rawValue)
            default:
                break
            }
        }

        return normalized.isEmpty ? nil : .string(normalized)
    }

    private func extractNumber(from node: RawAXNode, dict: [String: AnySendable]) -> AnySendable? {
        if let parse = dict["parse"]?.stringValue, parse == "unread_count" {
            let texts = WhatsAppParserSupport.normalizedUniqueTexts(node.textFragments)
            let count = WhatsAppParserSupport.unreadCount(in: texts)
            return .int(count)
        }
        return nil
    }

    private func findOne(dict: [String: AnySendable], in root: RawAXNode) -> RawAXNode? {
        if let path = dict["path"]?.stringValue, let anchored = root.node(at: path) {
            if matchesFilters(dict: dict, node: anchored) {
                return anchored
            }
        }
        return root.firstDescendant { node in
            matchesFilters(dict: dict, node: node)
        }
    }

    private func findMany(dict: [String: AnySendable], in root: RawAXNode) -> [RawAXNode] {
        let scope = dict["scope"]?.stringValue ?? "descendants"
        let candidates: [RawAXNode]
        if scope == "children" {
            candidates = root.children
        } else {
            candidates = root.flattened
        }

        return candidates.filter { node in
            matchesFilters(dict: dict, node: node)
        }
    }

    private func matchesFilters(dict: [String: AnySendable], node: RawAXNode) -> Bool {
        if let role = dict["role"]?.stringValue, !role.isEmpty, node.role != role { return false }
        if let roles = dict["role_any"]?.stringArrayValue, !roles.isEmpty {
            if let nodeRole = node.role {
                if !roles.contains(nodeRole) { return false }
            } else {
                return false
            }
        }
        if let subrole = dict["subrole"]?.stringValue, !subrole.isEmpty, node.subrole != subrole {
            return false
        }

        if let minHeight = dict["min_height"]?.doubleValue {
            if (node.frame?.height ?? 0) < minHeight { return false }
        }
        if let maxHeight = dict["max_height"]?.doubleValue {
            if (node.frame?.height ?? 0) > maxHeight { return false }
        }

        if let needle = dict["help_contains"]?.stringValue, !needle.isEmpty {
            let hay = node.help ?? ""
            if !hay.contains(needle) { return false }
        }

        if let needle = dict["description_contains"]?.stringValue, !needle.isEmpty {
            let hay = node.nodeDescription ?? ""
            if !hay.contains(needle) { return false }
        }

        if let any = dict["description_contains_any"]?.stringArrayValue, !any.isEmpty {
            let hay = (node.nodeDescription ?? "").lowercased()
            if !any.contains(where: { hay.contains($0.lowercased()) }) {
                return false
            }
        }

        if let any = dict["text_contains_any"]?.stringArrayValue, !any.isEmpty {
            let hay = node.ownTextFragments.joined(separator: " ").lowercased()
            if !any.contains(where: { hay.contains($0.lowercased()) }) {
                return false
            }
        }

        return true
    }

    private func parseConversationName(fromDescription description: String) -> String? {
        let fragments = description
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = fragments.first else { return nil }

        if fragments.count > 1, fragments.allSatisfy({ looksLikePhoneFragment($0) }) {
            let rebuilt = fragments
                .map(compactPhoneFragment(_:))
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return rebuilt.isEmpty ? first : rebuilt
        }

        return first
    }

    private func parseConversationValue(fromValue value: String) -> (preview: String?, timeText: String?) {
        let tokens = WhatsAppParserSupport.axTokens(value)
        guard !tokens.isEmpty else { return (nil, nil) }

        let timeIndex = tokens.firstIndex(where: WhatsAppParserSupport.looksLikeDateOrTime)
        let timeText = timeIndex.map { tokens[$0] }

        let first = tokens.first
        let previewStart = first?.lowercased().contains("your message") == true
            || first?.lowercased().contains("message from") == true
            || first?.lowercased() == "message"
            || first?.lowercased().contains("your voice message") == true
            ? 1
            : 0
        let previewEnd = timeIndex ?? tokens.count
        let previewTokens = previewStart < previewEnd ? Array(tokens[previewStart..<previewEnd]) : []
        let preview = previewTokens.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)

        return (preview.isEmpty ? nil : preview, timeText)
    }

    private func parseMessageDescription(_ description: String) -> (text: String?, direction: MessageDirection, kind: MessageKind, status: MessageStatus, timestampText: String?, authorName: String?) {
        let tokens = WhatsAppParserSupport.axTokens(description)
        guard let first = tokens.first else {
            return (nil, .unknown, .unknown, .unknown, nil, nil)
        }

        let combined = tokens.joined(separator: " ").lowercased()
        let direction = WhatsAppParserSupport.messageDirection(in: combined)
        let kind = WhatsAppParserSupport.messageKind(in: combined)
        let status = WhatsAppParserSupport.messageStatus(in: combined)
        let metadataIndex = tokens.firstIndex(where: WhatsAppParserSupport.isMessageMetadata(_:)) ?? tokens.count
        let timestampText = WhatsAppParserSupport.messageTimestampText(in: Array(tokens[metadataIndex..<tokens.count]))
        let authorName = WhatsAppParserSupport.messageAuthorName(from: tokens, combinedLowercased: combined)

        if first.lowercased().contains("voice message") {
            return ("Voice message", direction, .voice, status, timestampText, authorName)
        }

        let firstLowercased = first.lowercased()
        let messageStart = firstLowercased.contains("your message")
            || firstLowercased == "message"
            || firstLowercased.contains("message from")
            || firstLowercased.contains("mensagem de")
            ? 1 : 0
        let messageTokens = messageStart < metadataIndex ? Array(tokens[messageStart..<metadataIndex]) : []
        let messageText = messageTokens.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)

        return (messageText.isEmpty ? first : messageText, direction, kind, status, timestampText, authorName)
    }

    private func compactPhoneFragment(_ fragment: String) -> String {
        fragment.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private func looksLikePhoneFragment(_ fragment: String) -> Bool {
        let compact = compactPhoneFragment(fragment)
        return compact.range(of: #"^[+\d]+$"#, options: .regularExpression) != nil
    }
}

private extension AnySendable {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var arrayValue: [AnySendable]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var objectValue: [String: AnySendable]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var stringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        let strings = values.compactMap { v in
            if case .string(let s) = v { return s }
            return nil
        }
        guard strings.count == values.count else { return nil }
        return strings
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }
}
