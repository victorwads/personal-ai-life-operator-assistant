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
            "Started chatId=\(request.chatId) messageCount=\(request.messages.count)"
        )

        guard !request.messages.isEmpty else {
            logStore.append(source: "Send", "No messages requested")
            return WhatsAppMessageSendResult(chatId: request.chatId, receipts: [])
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

        let baselineChat = try await ensureChatSelected(chatId: request.chatId, in: webView)
        let baselineMessageIds = Set(baselineChat.chat.messages.compactMap(\.id))
        let interactor = WebViewElementInteractor(webView: webView)

        for message in request.messages {
            let currentChatContext = try await ensureChatSelected(chatId: request.chatId, in: webView)
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
            chatId: request.chatId,
            expectedMessages: request.messages,
            baselineMessageIds: baselineMessageIds,
            in: webView
        )
        logStore.append(source: "Send", "Observed receiptCount=\(result.receipts.count)")
        return result
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

    private func waitForObservedReceipts(
        chatId: String,
        expectedMessages: [String],
        baselineMessageIds: Set<String>,
        in webView: WKWebView
    ) async throws -> WhatsAppMessageSendResult {
        let normalizedExpected = expectedMessages.map { WhatsAppCrawlingNormalizer.normalizeText($0) ?? $0 }
        var lastObservedReceipts: [WhatsAppMessageSendReceipt] = normalizedExpected.map {
            WhatsAppMessageSendReceipt(text: $0, chatMessageId: nil)
        }

        for attempt in 1...24 {
            guard let currentChat = try await extractCurrentChatContext(in: webView), currentChat.chat.chatId == chatId else {
                try? await Task.sleep(nanoseconds: 250_000_000)
                continue
            }

            let observed = matchReceipts(
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
        expectedMessages: [String],
        messages: [ChatMessage],
        baselineMessageIds: Set<String>
    ) -> [WhatsAppMessageSendReceipt] {
        let newMessages = messages.filter { message in
            guard let id = message.id else { return false }
            return !baselineMessageIds.contains(id)
        }

        var nextMessageIndex = 0
        return expectedMessages.map { expected in
            while nextMessageIndex < newMessages.count {
                let candidate = newMessages[nextMessageIndex]
                nextMessageIndex += 1
                let candidateText = WhatsAppCrawlingNormalizer.normalizeText(candidate.text)
                if candidateText == expected {
                    return WhatsAppMessageSendReceipt(text: expected, chatMessageId: candidate.id)
                }
            }

            return WhatsAppMessageSendReceipt(text: expected, chatMessageId: nil)
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
