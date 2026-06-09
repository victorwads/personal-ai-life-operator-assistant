import Foundation
import WebKit

// TODO: Revisit resume timing.
// `defer { Task { ... } }` schedules resume asynchronously and does not wait for it.
// This is probably fine for now, but if send/retry sequencing becomes strict,
// prefer an explicit async cleanup path that guarantees crawling resumed before returning.
@MainActor
final class WebViewMessageSender: WhatsAppMessageSending {
    private let webViewService: WebViewWhatsAppCrawlingService
    private weak var pollingService: WhatsAppCrawlingPollingService?
    private let logStore: WhatsAppCrawlingLogStore
    private let yamlTextProvider: @MainActor () throws -> String

    init(
        webViewService: WebViewWhatsAppCrawlingService,
        pollingService: WhatsAppCrawlingPollingService?,
        logStore: WhatsAppCrawlingLogStore,
        yamlTextProvider: @escaping @MainActor () throws -> String = {
            try WebYAMLSelectorLoader.loadBundledYAML()
        }
    ) {
        self.webViewService = webViewService
        self.pollingService = pollingService
        self.logStore = logStore
        self.yamlTextProvider = yamlTextProvider
    }

    func sendMessages(_ request: WhatsAppMessageSendRequest) async throws -> WhatsAppMessageSendResult {
        logStore.append(
            source: "Send",
            "Started chatId=\(request.chatId ?? "nil") phone=\(request.phone ?? "nil") messageCount=\(request.messages.count)"
        )

        guard !request.messages.isEmpty else {
            logStore.append(source: "Send", "No messages requested")
            return WhatsAppMessageSendResult(
                chatId: request.chatId ?? request.phone ?? "",
                receipts: []
            )
        }

        guard let webView = webViewService.webView else {
            logStore.append(source: "Send", "Failed: WebView unavailable")
            throw WhatsAppMessageSendingError.webViewUnavailable
        }

        await pollingService?.pauseCrawling(reason: "sendMessages")
        defer {
            Task { @MainActor [weak pollingService, logStore] in
                await pollingService?.resumeCrawling(reason: "sendMessages")
                logStore.append(source: "Send", "Crawling resume requested")
            }
        }

        let baselineChat = try await ensureChatSelected(request: request, in: webView)
        let resolvedChatId = baselineChat.chat.chatId
        let baselineMessageIds = Set(baselineChat.chat.messages.compactMap(\.id))
        let interactor = WebViewElementInteractor(webView: webView)

        for message in request.messages {
            let currentChatContext = try await ensureResolvedChatSelected(chatId: resolvedChatId, in: webView)
            guard let input = currentChatContext.inputElement else {
                logStore.append(source: "Send", "Failed: compose box unavailable")
                throw WhatsAppMessageSendingError.webViewUnavailable
            }

            let focused = try await interactor.focus(input)
            let typed = try await interactor.type(message, into: input)
            let submitted = try await interactor.pressEnter(input)
            guard focused, typed, submitted else {
                logStore.append(source: "Send", "Failed: compose interaction could not be confirmed")
                throw WhatsAppMessageSendingError.timeout
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
        }

        let result = try await waitForObservedReceipts(
            chatId: resolvedChatId,
            expectedMessages: request.messages,
            baselineMessageIds: baselineMessageIds,
            in: webView
        )
        logStore.append(source: "Send", "Observed receiptCount=\(result.receipts.count)")
        return result
    }

    private func ensureChatSelected(request: WhatsAppMessageSendRequest, in webView: WKWebView) async throws -> ChatContext {
        if let phone = request.phone?.trimmedNonEmpty {
            return try await ensureChatSelected(phone: phone, in: webView)
        }
        guard let chatId = request.chatId?.trimmedNonEmpty else {
            logStore.append(source: "Send", "Missing destination identifier")
            throw WhatsAppMessageSendingError.chatNotFound("missing destination")
        }
        return try await ensureChatSelected(chatId: chatId, in: webView)
    }

    private func ensureChatSelected(chatId: String, in webView: WKWebView) async throws -> ChatContext {
        let rootObject = try await extractRootObject(in: webView)
        if let currentChat = parseCurrentChatContext(from: rootObject), currentChat.chat.chatId == chatId {
            return currentChat
        }

        let headers = WhatsAppChatListParser.parse(from: rootObject)
        guard let chatHeader = headers.first(where: { $0.id == chatId }) else {
            logStore.append(source: "Send", "Chat not found chatId=\(chatId)")
            throw WhatsAppMessageSendingError.chatNotFound(chatId)
        }
        guard let openChatElement = chatHeader.openChatElement else {
            logStore.append(source: "Send", "Chat missing clickable handle chatId=\(chatId)")
            throw WhatsAppMessageSendingError.chatNotFound(chatId)
        }

        let interactor = WebViewElementInteractor(webView: webView)
        let clicked = try await interactor.click(openChatElement)
        guard clicked else {
            logStore.append(source: "Send", "Click failed chatId=\(chatId)")
            throw WhatsAppMessageSendingError.chatNotFound(chatId)
        }

        for attempt in 1...20 {
            if let currentChat = try await extractCurrentChatContext(in: webView), currentChat.chat.chatId == chatId {
                logStore.append(source: "Send", "Selected chatId=\(chatId) attempt=\(attempt)")
                return currentChat
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        logStore.append(source: "Send", "Timed out selecting chatId=\(chatId)")
        throw WhatsAppMessageSendingError.timeout
    }

    private func ensureChatSelected(phone: String, in webView: WKWebView) async throws -> ChatContext {
        try await dismissCurrentChatIfNeeded(in: webView)
        await webViewService.navigateToPhoneUsingJavaScript(phone)

        for attempt in 1...24 {
            if let currentChat = try await extractCurrentChatContext(in: webView) {
                logStore.append(
                    source: "Send",
                    "Selected by phone=\(phone) chatId=\(currentChat.chat.chatId) attempt=\(attempt)"
                )
                return currentChat
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        logStore.append(source: "Send", "Phone not found or did not enter currentChat phone=\(phone)")
        throw WhatsAppMessageSendingError.chatNotFound(phone)
    }

    private func dismissCurrentChatIfNeeded(in webView: WKWebView) async throws {
        guard try await extractCurrentChatContext(in: webView) != nil else {
            logStore.append(source: "Send", "Phone flow precondition already outside currentChat")
            return
        }

        let interactor = WebViewElementInteractor(webView: webView)

        for attempt in 1...8 {
            let escaped = try await interactor.pressEscape()
            logStore.append(source: "Send", "Pressed Escape before phone navigation attempt=\(attempt) escaped=\(escaped)")

            for waitAttempt in 1...8 {
                if try await extractCurrentChatContext(in: webView) == nil {
                    logStore.append(
                        source: "Send",
                        "Confirmed exit from currentChat after Escape attempt=\(attempt) waitAttempt=\(waitAttempt)"
                    )
                    return
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }

        logStore.append(source: "Send", "Timed out leaving currentChat before phone navigation")
        throw WhatsAppMessageSendingError.timeout
    }

    private func ensureResolvedChatSelected(chatId: String, in webView: WKWebView) async throws -> ChatContext {
        for attempt in 1...20 {
            if let currentChat = try await extractCurrentChatContext(in: webView), currentChat.chat.chatId == chatId {
                if attempt > 1 {
                    logStore.append(source: "Send", "Reconfirmed selected chatId=\(chatId) attempt=\(attempt)")
                }
                return currentChat
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        logStore.append(source: "Send", "Timed out confirming selected chatId=\(chatId)")
        throw WhatsAppMessageSendingError.timeout
    }

    private func waitForObservedReceipts(
        chatId: String,
        expectedMessages: [String],
        baselineMessageIds: Set<String>,
        in webView: WKWebView
    ) async throws -> WhatsAppMessageSendResult {
        let normalizedExpected = expectedMessages.map { WhatsAppCrawlingNormalizer.normalizeText($0) ?? $0 }
        var lastObservedReceipts: [WhatsAppMessageSendReceipt] = expectedMessages.map {
            WhatsAppMessageSendReceipt(requestedText: $0, observedMessage: nil)
        }

        for attempt in 1...24 {
            guard let currentChat = try await extractCurrentChatContext(in: webView), currentChat.chat.chatId == chatId else {
                try? await Task.sleep(nanoseconds: 250_000_000)
                continue
            }

            let observed = matchReceipts(
                requestedMessages: expectedMessages,
                expectedMessages: normalizedExpected,
                messages: currentChat.chat.messages,
                baselineMessageIds: baselineMessageIds
            )
            lastObservedReceipts = observed

            let observedCount = observed.filter { $0.chatMessageId != nil }.count
            if observedCount == normalizedExpected.count {
                return WhatsAppMessageSendResult(chatId: chatId, receipts: observed)
            }

            logStore.append(
                source: "Send",
                "Waiting for receipts chatId=\(chatId) observed=\(observedCount)/\(normalizedExpected.count) attempt=\(attempt)"
            )
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        let observedCount = lastObservedReceipts.filter { $0.chatMessageId != nil }.count
        logStore.append(
            source: "Send",
            "Timeout chatId=\(chatId) observed=\(observedCount)/\(expectedMessages.count)"
        )
        if observedCount > 0 {
            return WhatsAppMessageSendResult(chatId: chatId, receipts: lastObservedReceipts)
        }
        throw WhatsAppMessageSendingError.messageNotObserved(
            "Observed \(observedCount)/\(expectedMessages.count) messages for chat \(chatId)."
        )
    }

    private func matchReceipts(
        requestedMessages: [String],
        expectedMessages: [String],
        messages: [ChatMessage],
        baselineMessageIds: Set<String>
    ) -> [WhatsAppMessageSendReceipt] {
        let newMessages = messages.filter { message in
            guard let id = message.id else { return false }
            return !baselineMessageIds.contains(id)
        }

        var nextMessageIndex = 0
        return zip(requestedMessages, expectedMessages).map { requestedText, expected in
            while nextMessageIndex < newMessages.count {
                let candidate = newMessages[nextMessageIndex]
                nextMessageIndex += 1
                let candidateText = WhatsAppCrawlingNormalizer.normalizeText(candidate.text)
                if candidateText == expected {
                    return WhatsAppMessageSendReceipt(
                        requestedText: requestedText,
                        observedMessage: candidate
                    )
                }
            }

            return WhatsAppMessageSendReceipt(
                requestedText: requestedText,
                observedMessage: nil
            )
        }
    }

    private func extractCurrentChatContext(in webView: WKWebView) async throws -> ChatContext? {
        let rootObject = try await extractRootObject(in: webView)
        return parseCurrentChatContext(from: rootObject)
    }

    private func parseCurrentChatContext(from rootObject: [String: Any]) -> ChatContext? {
        guard let currentChat = WhatsAppCurrentChatParser.parse(from: rootObject, referenceDate: Date()) else {
            return nil
        }

        guard
            let web = rootObject["web"] as? [String: Any],
            let currentChatObject = web["currentChat"] as? [String: Any]
        else {
            return nil
        }

        let inputElement = WebViewInteractiveElementDetector.from(currentChatObject["chatInputMessageBox"] as Any)
        return ChatContext(chat: currentChat, inputElement: inputElement)
    }

    private func extractRootObject(in webView: WKWebView) async throws -> [String: Any] {
        let yamlText = try yamlTextProvider()
        let extractionJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
        guard let data = extractionJSON.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WhatsAppMessageSendingError.timeout
        }
        return object
    }
}

private struct ChatContext {
    let chat: ParsedCurrentChat
    let inputElement: WebViewInteractiveElement?
}
