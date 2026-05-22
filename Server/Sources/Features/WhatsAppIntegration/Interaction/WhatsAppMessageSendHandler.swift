import Foundation

@MainActor
struct WhatsAppMessageSendHandler {
    private let accessibilityMap = WhatsAppAccessibilityMap.shared

    private func normalizeComposeTextForComparison(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func composeLooksLikeTarget(_ current: String, target: String) -> Bool {
        if current == target { return true }
        if current.count >= 12, target.hasPrefix(current) { return true }
        if target.count >= 12, current.hasPrefix(target) { return true }
        let suffixLen = min(18, target.count)
        if suffixLen >= 12 {
            let suffix = String(target.suffix(suffixLen))
            if current.contains(suffix) { return true }
        }
        return false
    }

    func sendMessage(_ text: String, using accessibility: AccessibilityService) throws {
        let liveSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
        guard let composeContainerPath = accessibilityMap.composeContainer(in: liveSnapshot.rootNode)?.accessibilityPath else {
            throw AccessibilityError.nodeNotFound
        }

        try accessibility.sendText(text, inComposeContainer: composeContainerPath)

        // Lightweight pre-send check: ensure the compose field is not empty before pressing Enter.
        // (We cleared it right before typing, so non-empty is a good "text landed" signal.)
        var hasText = false
        for attempt in 1...2 {
            for _ in 0..<75 { // ~1.5s
                let current = normalizeComposeTextForComparison((try? accessibility.readComposeValue(in: composeContainerPath)) ?? "")
                if !current.isEmpty {
                    hasText = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.02)
            }

            if hasText { break }
            if attempt < 2 {
                try accessibility.sendText(text, inComposeContainer: composeContainerPath)
            }
        }
        if !hasText { throw AccessibilityError.actionFailed(-3) }

        try triggerSend(using: accessibility, composeContainerPath: composeContainerPath)

        // Post-send validation: WhatsApp clears the compose field after a successful send.
        var cleared = false
        for _ in 0..<75 { // ~1.5s
            let current = normalizeComposeTextForComparison((try? accessibility.readComposeValue(in: composeContainerPath)) ?? "")
            if current.isEmpty {
                cleared = true
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if !cleared {
            throw AccessibilityError.actionFailed(-4)
        }
    }

    private func triggerSend(using accessibility: AccessibilityService, composeContainerPath: [Int]) throws {
        try accessibility.ensureWhatsAppActive()
        try accessibility.pressComposeTextAreaAXOnly(in: composeContainerPath)
        try accessibility.focusComposeTextArea(in: composeContainerPath)
        Thread.sleep(forTimeInterval: 0.05)
        try accessibility.pressEnterKey()
    }
}
