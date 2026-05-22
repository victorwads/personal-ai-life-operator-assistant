import Foundation

struct WhatsAppAccessibilityMap {
    static let shared = WhatsAppAccessibilityMap()

    private let nativeSpec: [String: AnySendable]?

    init(bundle: Bundle = .main) {
        nativeSpec = Self.loadNativeSpec(from: bundle)
    }

    func chatList(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "chat_list_root", in: root)
    }

    func messageList(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "message_list_root", in: root)
    }

    func composeField(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "compose_field", in: root)
    }

    func composeContainer(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "compose_container", in: root)
    }

    func sendButton(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "send_button", in: root)
    }

    func searchField(in root: RawAXNode) -> RawAXNode? {
        resolveNode(named: "search_field", in: root)
    }

    private static func loadNativeSpec(from bundle: Bundle) -> [String: AnySendable]? {
        guard let url = bundle.url(forResource: "whatsapp_native_selectors", withExtension: "yaml"),
              let data = try? Data(contentsOf: url),
              let yaml = String(data: data, encoding: .utf8),
              let tree = try? YAMLTree.parse(yaml: yaml),
              let native = tree.root["native"]?.objectValue else {
            return nil
        }

        return native
    }

    private func resolveNode(named key: String, in root: RawAXNode) -> RawAXNode? {
        guard let spec = nativeSpec?[key]?.objectValue else {
            return nil
        }
        return findOne(dict: spec, in: root)
    }

    private func findOne(dict: [String: AnySendable], in root: RawAXNode) -> RawAXNode? {
        if let path = dict["path"]?.stringValue, let anchored = root.node(at: path) {
            if matchesFilters(dict: dict, node: anchored) {
                return anchored
            }
        }

        let scope = dict["scope"]?.stringValue ?? "descendants"
        let candidates: [RawAXNode] = scope == "children" ? root.children : root.flattened
        return candidates.first(where: { matchesFilters(dict: dict, node: $0) })
    }

    private func matchesFilters(dict: [String: AnySendable], node: RawAXNode) -> Bool {
        if let role = dict["role"]?.stringValue, !role.isEmpty, node.role != role {
            return false
        }
        if let roles = dict["role_any"]?.stringArrayValue, !roles.isEmpty {
            guard let nodeRole = node.role, roles.contains(nodeRole) else {
                return false
            }
        }
        if let subrole = dict["subrole"]?.stringValue, !subrole.isEmpty, node.subrole != subrole {
            return false
        }
        if let minHeight = dict["min_height"]?.doubleValue,
           (node.frame?.height ?? 0) < minHeight {
            return false
        }
        if let maxHeight = dict["max_height"]?.doubleValue,
           (node.frame?.height ?? 0) > maxHeight {
            return false
        }
        if let needle = dict["help_contains"]?.stringValue, !needle.isEmpty {
            let hay = node.help ?? ""
            if !hay.localizedCaseInsensitiveContains(needle) {
                return false
            }
        }
        if let needle = dict["description_contains"]?.stringValue, !needle.isEmpty {
            let hay = node.nodeDescription ?? ""
            if !hay.localizedCaseInsensitiveContains(needle) {
                return false
            }
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
}

private extension AnySendable {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: AnySendable]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    var stringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        let strings = values.compactMap { value -> String? in
            if case .string(let string) = value {
                return string
            }
            return nil
        }
        guard strings.count == values.count else { return nil }
        return strings
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }
}
