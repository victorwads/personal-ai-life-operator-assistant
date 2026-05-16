import Foundation

struct WhatsAppConversationSelectionHandler {
    func selectConversation(_ conversation: ConversationSummary, using accessibility: AccessibilityService) throws {
        do {
            try accessibility.pressNode(at: conversation.accessibilityPath)
        } catch {
            try openConversationBySearch(conversation.name, using: accessibility)
        }
    }

    private func openConversationBySearch(_ name: String, using accessibility: AccessibilityService) throws {
        let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 10)
        let root = snapshot.rootNode

        guard let searchField = root.firstDescendant(where: { node in
            if node.subrole == "AXSearchField" { return true }
            return node.nodeDescription?.normalizedAXText.trimmingCharacters(in: .whitespacesAndNewlines) == "Search"
        }) else {
            throw AccessibilityError.nodeNotFound
        }

        try accessibility.sendText(name, to: searchField.accessibilityPath)
        try accessibility.pressEnterKey()
    }
}
