import Foundation

struct WhatsAppWebActionShortcutSpec: Sendable, Equatable {
    let modifiers: [String]
    let key: String
}

struct WhatsAppWebActionShortcuts: Sendable, Equatable {
    let archiveConversation: WhatsAppWebActionShortcutSpec?
    let search: WhatsAppWebActionShortcutSpec?

    static func from(yamlTree: YAMLTree) -> WhatsAppWebActionShortcuts {
        guard case .object(let actions) = yamlTree.root["actions"],
              case .object(let shortcuts) = actions["shortcuts"] else {
            return WhatsAppWebActionShortcuts(archiveConversation: nil, search: nil)
        }

        return WhatsAppWebActionShortcuts(
            archiveConversation: shortcut(from: shortcuts["archive_conversation"]),
            search: shortcut(from: shortcuts["search"])
        )
    }

    private static func shortcut(from any: AnySendable?) -> WhatsAppWebActionShortcutSpec? {
        guard case .object(let dict)? = any else {
            return nil
        }

        let modifiers = dict["modifiers"]?.shortcutStringArrayValue ?? []
        guard let key = dict["key"]?.shortcutStringValue, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return WhatsAppWebActionShortcutSpec(
            modifiers: modifiers,
            key: key
        )
    }
}

private extension AnySendable {
    var shortcutStringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var shortcutStringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        let strings = values.compactMap { value -> String? in
            if case .string(let string) = value { return string }
            return nil
        }
        return strings.count == values.count ? strings : nil
    }
}
