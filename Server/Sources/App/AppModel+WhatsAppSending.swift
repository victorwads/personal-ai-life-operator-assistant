import Foundation

extension AppModel {
    func sendWhatsAppMessagesViaCurrentIntegration(_ texts: [String], to conversationId: String) async throws {
        isSendingMessage = true
        defer { isSendingMessage = false }

        let trimmedTexts = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedTexts.isEmpty else {
            throw MCPServerError.invalidParameter("messages")
        }

        switch whatsAppIntegrationSettings.mode {
        case .desktopAX:
            try await whatsappMessageSendCoordinator.sendMessagesViaScheduler(trimmedTexts, to: conversationId)

        case .web:
            try await sendWhatsAppWebMessages(trimmedTexts, to: conversationId)
        }
    }

    func sendWhatsAppMessageViaCurrentIntegration(_ text: String, to conversationId: String) async throws {
        try await sendWhatsAppMessagesViaCurrentIntegration([text], to: conversationId)
    }

    private func sendWhatsAppWebMessages(_ texts: [String], to conversationId: String) async throws {
        guard let conversation = memoryStore.conversation(for: conversationId) else {
            throw MCPServerError.invalidParameter("chatId")
        }
        guard let account = selectedWhatsAppWebAccount else {
            throw MCPServerError.invalidParameter("whatsappWebAccount")
        }

        let wasPolling = isPolling
        if wasPolling {
            stopPolling()
            appendLog("Send(Web) paused polling to avoid chat selection races.", level: .info)
        }
        defer {
            if wasPolling {
                startPolling()
                appendLog("Send(Web) resumed polling after send.", level: .info)
            }
        }

        let provider = WebProvider(
            accountId: account.id,
            accounts: { [weak self] in self?.whatsAppWebAccounts ?? [] },
            sessionStore: whatsAppWebSessionStore,
            bridge: whatsAppWebBridge,
            messageSettleDelayMilliseconds: whatsAppWebSettings.messageSettleDelayMilliseconds
        )

        let webView = whatsAppWebSessionStore.webView(for: account)
        for text in texts {
            appendLog("Send(Web) opening conversation '\(conversation.name)' (chatId='\(conversation.id)').", level: .info)
            try await provider.interactor.openConversation(conversation)

            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedText.isEmpty else {
                continue
            }

            let beforeCapture = try await whatsAppWebBridge.captureSelectedChat(from: webView, limit: 50)
            let beforeMatch = WhatsAppParserSupport.chatTitleMatch(expected: conversation.name, actual: beforeCapture.selectedChatTitle)
            let beforeFlow = beforeCapture.flow.rawValue
            if !beforeMatch.isMatch {
                appendLog(
                    "Send(Web) selection mismatch: expected '\(beforeMatch.expectedTitle)' but parsed '\(beforeMatch.actualTitle)'. expectedKey=\(beforeMatch.expectedKey) actualKey=\(beforeMatch.actualKey) flow=\(beforeMatch.flowLabel(beforeFlow)). Refusing to send.",
                    level: .error
                )
                throw WhatsAppWebBridgeError.elementNotFound(
                    "sendMessage refused due to selection mismatch. expectedTitle='\(beforeMatch.expectedTitle)' actualTitle='\(beforeMatch.actualTitle)' expectedKey=\(beforeMatch.expectedKey) actualKey=\(beforeMatch.actualKey) flow=\(beforeFlow)"
                )
            }

            if beforeMatch.didNormalizeOrTruncate {
                appendLog(
                    "Send(Web) selection confirmed: expected '\(beforeMatch.expectedTitle)' matched '\(beforeMatch.actualTitle)' via \(beforeMatch.methodLabel). expectedKey=\(beforeMatch.expectedKey) actualKey=\(beforeMatch.actualKey) flow=\(beforeMatch.flowLabel(beforeFlow)).",
                    level: .info
                )
            } else {
                appendLog(
                    "Send(Web) selection confirmed: expected '\(beforeMatch.expectedTitle)' matched '\(beforeMatch.actualTitle)'. expectedKey=\(beforeMatch.expectedKey) actualKey=\(beforeMatch.actualKey) flow=\(beforeMatch.flowLabel(beforeFlow)).",
                    level: .info
                )
            }

            if let draft = beforeCapture.composeDraftText, !draft.isEmpty {
                let draftPreview = String(draft.prefix(80))
                appendLog(
                    "Send(Web) composer draft before insert: \(draft.count) chars preview='\(draftPreview)'.",
                    level: .warning
                )
            }

            let beforeCount = beforeCapture.messages.count

            appendLog("Send(Web) sending \(normalizedText.count) chars to '\(conversation.name)'. beforeCount=\(beforeCount).", level: .info)
            let sendResult = try await whatsAppWebBridge.sendMessage(from: webView, text: normalizedText)
            guard sendResult.composerFound, sendResult.inserted else {
                throw WhatsAppWebBridgeError.elementNotFound(
                    "sendMessage(title='\(conversation.name)') result=\(sendResult.result) composerFound=\(sendResult.composerFound) inserted=\(sendResult.inserted) currentText=\(sendResult.currentText ?? "nil") observedOutgoingText=\(sendResult.observedOutgoingText ?? "nil")"
                )
            }
            appendLog(
                "Send(Web) bridge sendResult: result=\(sendResult.result) currentTextChars=\(sendResult.currentText?.count ?? -1) sendButtonFound=\(sendResult.sendButtonFound ?? false) sendButtonClicked=\(sendResult.sendButtonClicked ?? false) activeElementTag=\(sendResult.activeElementTag ?? "nil").",
                level: .info
            )

            let expectedNormalized = Self.messageComparisonText(normalizedText)
            var lastAfterCount = -1
            var lastAfterText: String? = nil

            var didObserveMessage = false
            var lastTailPreview: String = ""
            for attempt in 1...10 {
                try await Task.sleep(for: .milliseconds(250))
                let afterCapture = try await whatsAppWebBridge.captureSelectedChat(from: webView, limit: 50)
                let afterLastMessage = afterCapture.messages.last
                lastAfterText = afterLastMessage?.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                lastAfterCount = afterCapture.messages.count

                lastTailPreview = afterCapture.messages
                    .suffix(4)
                    .enumerated()
                    .map { idx, message in
                        let preview = message.text
                            .replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return "#\(idx):\(String(preview.prefix(80)))"
                    }
                    .joined(separator: " | ")

                if let draft = afterCapture.composeDraftText, !draft.isEmpty {
                    let draftPreview = String(draft.prefix(80))
                    appendLog(
                        "Send(Web) composer draft after send attempt \(attempt): \(draft.count) chars preview='\(draftPreview)'.",
                        level: .warning
                    )
                }

                didObserveMessage = afterCapture.messages
                    .suffix(16)
                    .contains { message in
                        let actualNormalized = Self.messageComparisonText(message.text)
                        guard !expectedNormalized.isEmpty, !actualNormalized.isEmpty else { return false }
                        if expectedNormalized.count >= 8, actualNormalized.contains(expectedNormalized) { return true }
                        if actualNormalized.count >= 8, expectedNormalized.contains(actualNormalized) { return true }
                        return false
                    }

                let draftEmpty = (afterCapture.composeDraftText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)
                if !didObserveMessage, draftEmpty, lastAfterCount > beforeCount {
                    appendLog(
                        "Send(Web) outgoing message not text-matched yet, but composer draft is empty and count increased (beforeCount=\(beforeCount) afterCount=\(lastAfterCount)). Accepting send as successful.",
                        level: .warning
                    )
                    didObserveMessage = true
                }

                if didObserveMessage {
                    appendLog(
                        "Send(Web) observed outgoing message in DOM for '\(conversation.name)' after \(attempt) checks. beforeCount=\(beforeCount) afterCount=\(lastAfterCount) afterLastText=\(lastAfterText ?? "nil").",
                        level: .info
                    )
                    break
                }
            }

            guard didObserveMessage else {
                throw WhatsAppWebBridgeError.elementNotFound(
                    "sendMessage(title='\(conversation.name)') did not observe the outgoing message after send. beforeCount=\(beforeCount) afterCount=\(lastAfterCount) afterLastText=\(lastAfterText ?? "nil") tailPreview=[\(lastTailPreview)]"
                )
            }
        }

        await forceUpdateSelectedWhatsAppWebChat(for: account)
    }
}

private extension AppModel {
    static func messageComparisonText(_ value: String) -> String {
        let normalized = value
            .normalizedAXText
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        // Remove punctuation/emojis so prefix/suffix formatting differences don't break matching.
        let stripped = normalized
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(String.init)
            .joined()

        return stripped
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
