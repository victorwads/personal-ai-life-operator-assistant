import Foundation

@MainActor
struct WhatsAppMessageSendHandler {
    private let accessibilityMap = WhatsAppAccessibilityMap()

    func sendMessageConfirmed(
        _ text: String,
        expectedChatName: String,
        using accessibility: AccessibilityService,
        parser: WhatsAppAppParser
    ) async throws -> (snapshot: WhatsAppSnapshot, state: WhatsAppScreenState) {
        try sendMessage(text, using: accessibility)
        do {
            let verified = try await verifyRecentlySentMessage(
                text,
                expectedChatName: expectedChatName,
                using: accessibility,
                parser: parser,
                timeoutSeconds: 28,
                pollIntervalMs: 500,
                messageWindow: 12
            )
            try? clearComposeIfNeeded(using: accessibility)
            return verified
        } catch let error as MCPServerError {
            guard case .sendNotConfirmed = error else { throw error }
        }

        if let alreadyVisible = try? await verifyRecentlySentMessage(
            text,
            expectedChatName: expectedChatName,
            using: accessibility,
            parser: parser,
            timeoutSeconds: 3,
            pollIntervalMs: 250,
            messageWindow: 12
        ) {
            try? clearComposeIfNeeded(using: accessibility)
            return alreadyVisible
        }

        let liveSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
        guard let composePath = accessibilityMap.composeField(in: liveSnapshot.rootNode)?.accessibilityPath else {
            throw AccessibilityError.nodeNotFound
        }
        let composeText = (try? accessibility.readValue(at: composePath)) ?? ""
        if composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MCPServerError.sendNotConfirmed("compose empty; skipping Enter retry to avoid duplicate send")
        }

        try triggerSend(using: accessibility, composePath: composePath)
        let verified2 = try await verifyRecentlySentMessage(
            text,
            expectedChatName: expectedChatName,
            using: accessibility,
            parser: parser,
            timeoutSeconds: 28,
            pollIntervalMs: 500,
            messageWindow: 12
        )
        try? clearComposeIfNeeded(using: accessibility)
        return verified2
    }

    func clearComposeIfNeeded(using accessibility: AccessibilityService) throws {
        let liveSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
        guard let composePath = accessibilityMap.composeField(in: liveSnapshot.rootNode)?.accessibilityPath else {
            throw AccessibilityError.nodeNotFound
        }

        let current = (try? accessibility.readValue(at: composePath)) ?? ""
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? accessibility.setValue("", at: composePath)
        }
    }

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

    private func sendMessage(_ text: String, using accessibility: AccessibilityService) throws {
        let liveSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
        guard let composePath = accessibilityMap.composeField(in: liveSnapshot.rootNode)?.accessibilityPath else {
            throw AccessibilityError.nodeNotFound
        }

        let normalizedTarget = normalizeComposeTextForComparison(text)
        var typedOK = false
        for attempt in 1...3 {
            try accessibility.sendText(text, to: composePath)

            var lastSeen: String?
            for _ in 0..<100 {
                let current = (try? accessibility.readValue(at: composePath)).map(normalizeComposeTextForComparison(_:)) ?? ""
                if composeLooksLikeTarget(current, target: normalizedTarget) {
                    typedOK = true
                    break
                }
                if current != lastSeen {
                    lastSeen = current
                }
                Thread.sleep(forTimeInterval: 0.02)
            }

            if typedOK { break }
            if attempt < 3 {
                continue
            }
        }

        if !typedOK {
            throw AccessibilityError.actionFailed(-3)
        }

        try triggerSend(using: accessibility, composePath: composePath)
    }

    private func normalizeMessageTextForVerification(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .lowercased()
    }

    @MainActor
    private func verifyRecentlySentMessage(
        _ text: String,
        expectedChatName: String,
        using accessibility: AccessibilityService,
        parser: WhatsAppAppParser,
        timeoutSeconds: Int,
        pollIntervalMs: Int,
        messageWindow: Int
    ) async throws -> (snapshot: WhatsAppSnapshot, state: WhatsAppScreenState) {
        let normalizedTarget = normalizeMessageTextForVerification(text)
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        var attempts = 0
        var lastState: WhatsAppScreenState?

        while Date() < deadline {
            attempts += 1
            try await Task.sleep(for: .milliseconds(pollIntervalMs))

            let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            let state = parser.parse(snapshot: snapshot, messageLimit: max(10, messageWindow))

            lastState = state

            if let selected = state.selectedChatName, !selected.isEmpty, selected != expectedChatName {
                continue
            }

            if let convo = state.conversations.first(where: { $0.name == expectedChatName }) {
                if convo.lastMessageDirection == .outgoing,
                   let preview = convo.lastMessagePreview
                {
                    let normalizedPreview = normalizeMessageTextForVerification(preview)
                    if normalizedPreview == normalizedTarget { return (snapshot, state) }
                    if normalizedPreview.count >= 6 && normalizedTarget.contains(normalizedPreview) { return (snapshot, state) }
                    if normalizedTarget.count >= 6 && normalizedPreview.contains(normalizedTarget) { return (snapshot, state) }
                }
            }

            let recent = Array(state.messages.suffix(messageWindow))
            if recent.contains(where: { message in
                guard message.direction == .outgoing else { return false }
                guard let raw = message.text else { return false }
                let candidate = normalizeMessageTextForVerification(raw)
                if candidate == normalizedTarget { return true }
                if candidate.count >= 6 && normalizedTarget.contains(candidate) { return true }
                if normalizedTarget.count >= 6 && candidate.contains(normalizedTarget) { return true }
                return false
            }) {
                return (snapshot, state)
            }
        }

        let selectedName = lastState?.selectedChatName ?? "nil"
        let lastPreview = lastState?.conversations.first(where: { $0.name == expectedChatName })?.lastMessagePreview ?? "nil"
        let recentDump = (lastState?.messages.suffix(messageWindow) ?? []).map { message in
            let dir = message.direction.rawValue
            let txt = message.text ?? "nil"
            return "\(dir): \(txt)"
        }.joined(separator: " | ")

        throw MCPServerError.sendNotConfirmed(
            "chat='\(expectedChatName)' selected='\(selectedName)' attempts=\(attempts) lastPreview='\(lastPreview)' recent=[\(recentDump)]"
        )
    }

    private func triggerSend(using accessibility: AccessibilityService, composePath: [Int]) throws {
        try accessibility.ensureWhatsAppActive()
        try? accessibility.pressNodeAXOnly(at: composePath)
        try accessibility.focusNode(at: composePath)
        Thread.sleep(forTimeInterval: 0.05)
        try accessibility.pressEnterKey()
    }
}
