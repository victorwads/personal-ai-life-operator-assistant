import Foundation
import WebKit

@MainActor
final class WhatsAppChatCrawlingOrchestrator {
    private let chatRepository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode
    private let yamlText: String
    private let logStore: WhatsAppCrawlingLogStore
    private let sharedLocks: SharedLockRegistry
    private var onStatusUpdate: ((String) -> Void)?
    private let debugForceRefreshFirstChat = false
    private let forcedStartupCrawlCycleCount = 5

    init(
        chatRepository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode,
        yamlText: String,
        logStore: WhatsAppCrawlingLogStore,
        sharedLocks: SharedLockRegistry,
        onStatusUpdate: ((String) -> Void)? = nil
    ) {
        self.chatRepository = chatRepository
        self.permissionModeProvider = permissionModeProvider
        self.yamlText = yamlText
        self.logStore = logStore
        self.sharedLocks = sharedLocks
        self.onStatusUpdate = onStatusUpdate
    }

    func setStatusUpdateHandler(_ handler: ((String) -> Void)?) {
        onStatusUpdate = handler
    }

    func runCycle(
        in webView: WKWebView,
        completedCycleCount: Int,
        shouldContinue: @escaping @MainActor () -> Bool
    ) async -> CrawlingResult<Void> {
        do {
            func shouldProceed() -> Bool {
                let proceed = shouldContinue()
                if !proceed {
                    logStore.append(source: "Orchestrator", "Crawling cycle interrupted by stop/pause.")
                }
                return proceed
            }

            guard shouldProceed() else { return .success(()) }

            let forceRefreshAllChats = completedCycleCount < forcedStartupCrawlCycleCount
            logStore.append(source: "Orchestrator", "Extraction started")
            onStatusUpdate?("Reading flows")
            let extractionJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
            guard let rootObject = parseJSONObject(from: extractionJSON) else {
                logStore.append(source: "Error", "Extraction parse failed")
                return .failure(.parsingFailed("Unable to parse extraction JSON."))
            }

            let blocked = blockedFlows(rootObject)
            if blocked.loginQr || blocked.downloading {
                logStore.append(source: "Flow", "Blocked flow loginQr=\(blocked.loginQr) downloading=\(blocked.downloading)")
                return .success(())
            }
            logStore.append(source: "Flow", "No blocked flows")

            onStatusUpdate?("Listing chats")
            let headers = WhatsAppChatListParser.parse(from: rootObject)
            logStore.append(source: "ChatList", "Found \(headers.count) chats")
            logStore.append(
                source: "ChatList",
                "Crawling order is bottom-to-top (oldest visible first); listOrder is preserved as visual top-to-bottom (top chat = 0)."
            )
            onStatusUpdate?("Found \(headers.count) chats")
            let interactor = WebViewElementInteractor(webView: webView)

            for (reverseIndex, header) in headers.reversed().enumerated() {
                guard shouldProceed() else { return .success(()) }

                let existingChat = try await chatRepository.getChat(id: header.id)
                let chat = Chat(
                    id: header.id,
                    title: header.title,
                    permission: existingChat?.permission,
                    listOrder: header.listOrder,
                    lastMessagePreview: header.lastMessagePreview,
                    lastMessageTimeText: header.lastMessageTimeText,
                    unreadCount: header.unreadCount,
                    stateHash: header.stateHash,
                    lastDigestedAt: Date()
                )

                if existingChat == nil {
                    try await chatRepository.upsertChat(chat)
                    logStore.append(
                        source: "Repository",
                        "Discovered new chat '\(header.title)'; saved chat before permission gating."
                    )
                }

                let mode = permissionModeProvider()
                let rawPermission = existingChat?.permission
                let effectiveAllowed = ChatPermissionResolver.isPermissionAllowed(rawPermission, mode: mode)
                logStore.append(
                    source: "Permission",
                    "title='\(header.title)' rawPermission=\(rawPermission?.rawValue ?? "nil") mode=\(mode.rawValue) allowed=\(effectiveAllowed)"
                )
                guard effectiveAllowed else {
                    logStore.append(source: "Permission", "Skip '\(header.title)': denied by permission policy.")
                    continue
                }

                let refreshByRule = shouldRefreshChatMessages(header: header, existingChat: existingChat)
                let forcedRefresh = debugForceRefreshFirstChat && reverseIndex == 0
                let shouldRefresh = forceRefreshAllChats || refreshByRule || forcedRefresh
                logStore.append(
                    source: "Decision",
                    "title='\(header.title)' id=\(header.id) unread=\(header.unreadCount) stateHash=\(header.stateHash) existing=\(existingChat != nil) existingStateHash=\(existingChat?.stateHash ?? "nil") refresh=\(shouldRefresh) clickable=\(header.openChatElement != nil)"
                )

                guard shouldRefresh else {
                    logStore.append(source: "Decision", "Skip '\(header.title)': shouldRefresh=false")
                    continue
                }

                if header.openChatElement != nil {
                    logStore.append(
                        source: "Interactor",
                        "Refusing cached clickable handle for '\(header.title)'; resolving a fresh chat-row handle from latest extraction."
                    )
                } else {
                    logStore.append(source: "Interactor", "No cached clickable handle for '\(header.title)'; resolving fresh handle.")
                }

                guard shouldProceed() else { return .success(()) }
                guard let openElement = try await resolveFreshOpenChatElement(
                    forTitle: header.title,
                    webView: webView
                ) else {
                    logStore.append(
                        source: "Interactor",
                        "Skip '\(header.title)': fresh chat-row handle missing/stale after latest extraction."
                    )
                    continue
                }

                guard shouldProceed() else { return .success(()) }
                onStatusUpdate?("Opening \(header.title)")
                logStore.append(source: "Interactor", "Click started for '\(header.title)'")
                let clicked = try await interactor.click(openElement)
                logStore.append(source: "Interactor", "Click result=\(clicked) for '\(header.title)'")
                guard clicked else {
                    logStore.append(
                        source: "Interactor",
                        "Skip '\(header.title)': click returned false (handle missing/stale or element no longer attached)."
                    )
                    continue
                }

                guard shouldProceed() else { return .success(()) }
                logStore.append(source: "CurrentChat", "Waiting selected chat '\(header.title)'")
                guard let selectedRoot = await waitForSelectedChat(
                    expectedChatId: header.id,
                    title: header.title,
                    webView: webView,
                    shouldContinue: shouldContinue
                ) else {
                    guard shouldProceed() else { return .success(()) }
                    logStore.append(source: "CurrentChat", "Selected chat did not match expected id=\(header.id)")
                    continue
                }

                guard let parsedCurrentChat = WhatsAppCurrentChatParser.parse(from: selectedRoot, referenceDate: Date()) else {
                    logStore.append(source: "CurrentChat", "Skip '\(header.title)': parse current chat failed")
                    continue
                }
                logStore.append(source: "CurrentChat", "Selected title='\(parsedCurrentChat.chatTitle)' id=\(parsedCurrentChat.chatId)")
                logStore.append(source: "CurrentChat", "Parsed \(parsedCurrentChat.messages.count) messages")
                onStatusUpdate?("Extracting messages from \(parsedCurrentChat.chatTitle)")

                guard shouldProceed() else { return .success(()) }
                let messagesToPersist = try await enrichMessagesWithLocalMedia(
                    parsedCurrentChat.messages,
                    mediaElementsByMessageId: parsedCurrentChat.mediaElementsByMessageId,
                    in: webView
                )
                let insertedMessages = try await chatRepository.insertMessages(messagesToPersist)
                if insertedMessages.isEmpty {
                    logStore.append(source: "Repository", "No new messages, global_event not unlocked")

                    if existingChat == nil {
                        logStore.append(
                            source: "Repository",
                            "No new messages inserted for new chat '\(parsedCurrentChat.chatTitle)'; chat was already saved during discovery."
                        )
                        continue
                    }

                    logStore.append(
                        source: "Repository",
                        "No new messages inserted for '\(parsedCurrentChat.chatTitle)'; skipping chat save."
                    )
                    continue
                }

                // TODO: review double saving chat
                var persistedChat = chat
                if let latestMessage = latestMessage(in: insertedMessages) {
                    persistedChat.lastMessagePreview = previewText(for: latestMessage, fallback: chat.lastMessagePreview)
                    persistedChat.lastMessageLocalMediaPath = latestMessage.localMediaPaths.first
                }
                try await chatRepository.upsertChat(persistedChat)
                try await chatRepository.updateUnhandledCount(chatId: chat.id ?? header.id, count: nil)
                logStore.append(
                    source: "Repository",
                    "Inserted \(insertedMessages.count) new messages (from \(parsedCurrentChat.messages.count) parsed) for '\(parsedCurrentChat.chatTitle)' and saved chat."
                )
                onStatusUpdate?("Persisted new messages")

                await sharedLocks.unlock(id: SharedLockIDs.globalEvent)
                logStore.append(
                    source: "Repository",
                    "Inserted \(insertedMessages.count) messages, unlocking global_event"
                )
            }

            return .success(())
        } catch {
            logStore.append(source: "Error", "Cycle failed: \(error.localizedDescription)")
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func shouldRefreshChatMessages(header: ParsedChatHeader, existingChat: Chat?) -> Bool {
        guard let existingChat else { return true }
        if header.unreadCount > 0 { return true }
        if header.stateHash != existingChat.stateHash { return true }
        return false
    }

    private func blockedFlows(_ rootObject: [String: Any]) -> (loginQr: Bool, downloading: Bool) {
        guard let flows = rootObject["flows"] as? [String: Any] else { return (false, false) }
        let loginQr = (flows["loginQr"] as? Bool) ?? false
        let downloading = (flows["downloading"] as? Bool) ?? false
        return (loginQr, downloading)
    }

    private func parseJSONObject(from text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    private func resolveFreshOpenChatElement(
        forTitle title: String,
        webView: WKWebView
    ) async throws -> WebViewInteractiveElement? {
        let latestExtractionJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
        guard let latestRootObject = parseJSONObject(from: latestExtractionJSON) else {
            logStore.append(
                source: "Interactor",
                "Fresh chat-list extraction parse failed while resolving clickable handle for '\(title)'."
            )
            return nil
        }

        let latestHeaders = WhatsAppChatListParser.parse(from: latestRootObject)
        let expectedNormalizedTitle = normalizedChatTitle(title)
        guard let freshHeader = latestHeaders.first(where: {
            normalizedChatTitle($0.title) == expectedNormalizedTitle
        }) else {
            logStore.append(
                source: "Interactor",
                "Fresh chat row not found for '\(title)' (normalized='\(expectedNormalizedTitle)')."
            )
            return nil
        }

        guard let freshHandle = freshHeader.openChatElement else {
            logStore.append(
                source: "Interactor",
                "Fresh chat row found for '\(title)' but clickable handle is missing."
            )
            return nil
        }

        logStore.append(
            source: "Interactor",
            "Resolved fresh chat-row handle id=\(freshHandle.id) for '\(title)' from latest extraction."
        )
        return freshHandle
    }

    private func normalizedChatTitle(_ title: String) -> String {
        WhatsAppCrawlingNormalizer.normalizeText(title)?.lowercased() ?? title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func waitForSelectedChat(
        expectedChatId: String,
        title: String,
        webView: WKWebView,
        shouldContinue: @escaping @MainActor () -> Bool
    ) async -> [String: Any]? {
        for attempt in 1...10 {
            if !shouldContinue() {
                logStore.append(source: "Orchestrator", "Crawling cycle interrupted by stop/pause.")
                return nil
            }
            do {
                let currentChatJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
                guard let currentChatObject = parseJSONObject(from: currentChatJSON) else {
                    logStore.append(source: "CurrentChat", "Retry \(attempt)/10 parse JSON failed")
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }
                if let parsed = WhatsAppCurrentChatParser.parse(from: currentChatObject, referenceDate: Date()) {
                    if parsed.chatId == expectedChatId {
                        logStore.append(source: "CurrentChat", "Matched '\(title)' on attempt \(attempt)/10")
                        return currentChatObject
                    }
                    logStore.append(source: "CurrentChat", "Retry \(attempt)/10 selected='\(parsed.chatTitle)' id=\(parsed.chatId) expected=\(expectedChatId)")
                } else {
                    logStore.append(source: "CurrentChat", "Retry \(attempt)/10 parse=nil for expected '\(title)'")
                }
            } catch {
                logStore.append(source: "Error", "Retry \(attempt)/10 extraction failed: \(error.localizedDescription)")
            }
            if !shouldContinue() {
                logStore.append(source: "Orchestrator", "Crawling cycle interrupted by stop/pause.")
                return nil
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
    }

    private func enrichMessagesWithLocalMedia(
        _ messages: [ChatMessage],
        mediaElementsByMessageId: [String: WebViewInteractiveElement],
        in webView: WKWebView
    ) async throws -> [ChatMessage] {
        guard let chatId = messages.first?.chatId else {
            return messages
        }

        let existingIds = try await chatRepository.existingMessageIds(chatId: chatId)
        var enrichedMessages = messages
        let imageExtractor = WebViewImageExtractor(webView: webView)

        for index in enrichedMessages.indices {
            guard let messageId = enrichedMessages[index].id else { continue }
            guard !existingIds.contains(messageId) else { continue }
            guard enrichedMessages[index].kind == .image || enrichedMessages[index].kind == .sticker else { continue }

            if let existingPaths = try? ChatMediaStorage.existingRelativeMediaPaths(forMessageId: messageId),
               !existingPaths.isEmpty {
                enrichedMessages[index].localMediaPaths = existingPaths
                logStore.append(source: "Media", "Reused \(existingPaths.count) local media file(s) for \(messageId).")
                continue
            }

            guard let mediaElement = mediaElementsByMessageId[messageId] else {
                logStore.append(source: "Media", "No media handle available for \(messageId); saving message without local media.")
                continue
            }

            do {
                guard let resolved = try await imageExtractor.extractImage(from: mediaElement) else {
                    logStore.append(source: "Media", "Extraction returned no media for \(messageId); saving message without local media.")
                    continue
                }
                let relativePaths = try ChatMediaStorage.savePNGData([resolved.pngData], forMessageId: messageId)
                enrichedMessages[index].localMediaPaths = relativePaths
                logStore.append(source: "Media", "Saved \(relativePaths.count) local media file(s) for \(messageId).")
            } catch {
                logStore.append(source: "Media", "Failed extracting media for \(messageId): \(error.localizedDescription)")
            }
        }

        return enrichedMessages
    }

    private func latestMessage(in messages: [ChatMessage]) -> ChatMessage? {
        messages.max { lhs, rhs in
            if lhs.listOrder != rhs.listOrder {
                return lhs.listOrder < rhs.listOrder
            }
            let leftDate = lhs.dateTime ?? .distantPast
            let rightDate = rhs.dateTime ?? .distantPast
            return leftDate < rightDate
        }
    }

    private func previewText(for message: ChatMessage, fallback: String?) -> String? {
        switch message.kind {
        case .image:
            return "[Image]"
        case .sticker:
            return "[Sticker]"
        case .text, .audio, .unknown:
            return fallback
        }
    }
}
