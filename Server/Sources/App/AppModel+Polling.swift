import Foundation
import WebKit

extension AppModel {
    func refreshConversations() async {
        let mode = whatsAppIntegrationSettings.mode

        switch mode {
        case .web:
            if selectedWhatsAppWebAccountId == nil {
                if let primaryWhatsAppWebAccountId,
                   whatsAppWebAccounts.contains(where: { $0.id == primaryWhatsAppWebAccountId }) {
                    selectedWhatsAppWebAccountId = primaryWhatsAppWebAccountId
                } else {
                    selectedWhatsAppWebAccountId = whatsAppWebAccounts.first?.id
                }
            }

            guard let accountId = selectedWhatsAppWebAccountId else {
                let count = whatsAppWebAccounts.count
                if count == 0 {
                    appendLog("WhatsApp Web polling waiting for accounts to load.", level: .info)
                } else {
                    appendLog("WhatsApp Web polling enabled but no account is selected (accounts=\(count)).", level: .warning)
                }
                return
            }

            if let account = whatsAppWebAccounts.first(where: { $0.id == accountId }) {
                let webView = whatsAppWebSessionStore.webView(for: account)
                do {
                    let snapshot = try await whatsAppWebBridge.captureSnapshot(from: webView)
                    whatsAppWebPageSnapshotsByAccountId[account.id] = snapshot
                } catch {
                    appendLog("WhatsApp Web snapshot failed: \(error.localizedDescription)", level: .warning)
                }
            }
            let provider = WebProvider(
                accountId: accountId,
                accounts: { [weak self] in self?.whatsAppWebAccounts ?? [] },
                sessionStore: whatsAppWebSessionStore,
                bridge: whatsAppWebBridge,
                messageSettleDelayMilliseconds: whatsAppWebSettings.messageSettleDelayMilliseconds
            )
            await whatsAppPollingOrchestrator.refresh(provider: provider, messageLimit: 50)
            lastRefreshDescription = "Web refreshed at \(Date().formatted(date: .omitted, time: .standard))"
            return

        case .desktopAX:
            guard prepareForWhatsAppInspection() else {
                return
            }
            let provider = DesktopAXProvider(accessibility: accessibility, parser: parser, interactor: interactor)
            await whatsAppPollingOrchestrator.refresh(provider: provider, messageLimit: 10)
            lastRefreshDescription = "Desktop refreshed at \(Date().formatted(date: .omitted, time: .standard))"
            return
        }
    }

    func startPolling() {
        guard pollingTask == nil else {
            return
        }

        // Persist last intent: if the user starts polling anywhere, next launch should also start polling.
        whatsAppPollingStateRepository.savePollingEnabled(true)

        isPolling = true
        appendLog("Started WhatsApp polling.")

        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.schedulePollingRefresh()
                try? await Task.sleep(for: .seconds(self.pollingIntervalSeconds))
            }
        }
    }

    func stopPolling() {
        // Persist last intent: if the user stops polling anywhere, next launch should stay paused.
        whatsAppPollingStateRepository.savePollingEnabled(false)

        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        appendLog("Stopped WhatsApp polling.")
    }

    private func schedulePollingRefresh() async {
        if whatsAppIntegrationSettings.mode == .desktopAX {
            await accessibilityScheduler.enqueue(priority: .background) { [weak self] in
                guard let self else { return }
                await self.refreshConversations()
            }
        } else {
            await refreshConversations()
        }
    }

    func updateSelectedChatState(from screenState: WhatsAppScreenState, preferredConversation: ConversationSummary) {
        let chatState = makeChatState(from: screenState, preferredConversation: preferredConversation)
        memoryStore.upsertChatState(chatState)
    }

    func makeChatState(from screenState: WhatsAppScreenState, preferredConversation: ConversationSummary) -> ChatState {
        let latestConversation = screenState.conversations.first { $0.id == preferredConversation.id } ?? preferredConversation

        return ChatState(
            chat: latestConversation,
            messages: screenState.messages,
            composeFocused: screenState.composeFocused,
            canSendText: screenState.canSendText
        )
    }

    private func refreshChangedChats(from conversations: [ConversationSummary]) async {
        var didUpdateSignatures = false
        for conversation in conversations {
            guard !isBlocked(conversation.name) else {
                continue
            }
            let previousSignature = listSignaturesById[conversation.id]
            let signatureChanged = previousSignature != conversation.listSignature
            if previousSignature == nil || signatureChanged {
                listSignaturesById[conversation.id] = conversation.listSignature
                didUpdateSignatures = true
            }

            let isMissingCachedMessages = memoryStore.chatState(for: conversation.id) == nil
            let needsMessages = isMissingCachedMessages || previousSignature == nil || signatureChanged

            guard needsMessages else {
                continue
            }

            await loadMessages(
                for: conversation,
                reason: previousSignature == nil ? "first mapping" : "list changed",
                updateSelectedChat: selectedChatState?.chat.id == conversation.id
            )
        }

        if didUpdateSignatures {
            persistChatListSignatures()
        }
    }

    func loadMessages(for conversation: ConversationSummary, reason: String, updateSelectedChat: Bool) async {
        guard !isBlocked(conversation.name) else {
            appendLog("Skipped loading messages for blocked conversation \(conversation.name) (\(reason)).", level: .warning)
            return
        }
        do {
            let beforeCount = memoryStore.chatState(for: conversation.id)?.messages.count ?? 0
            let snapshot = try await openConversationAndCapture(conversation)
            let screenState = parser.parse(snapshot: snapshot, messageLimit: 10)
            let chatState = makeChatState(from: screenState, preferredConversation: conversation)
            memoryStore.upsertChatState(chatState)
            let afterCount = memoryStore.chatState(for: conversation.id)?.messages.count ?? 0
            let added = max(0, afterCount - beforeCount)
            appendLog(
                "Loaded \(screenState.messages.count) messages for \(conversation.name) (desktopAX) ingestedAdded=\(added) storeTotal=\(afterCount) storeBefore=\(beforeCount) reason=\(reason)."
            )
        } catch {
            appendLog("Failed to load messages for \(conversation.name): \(error.localizedDescription)", level: .error)
        }
    }

    func ensureChatLoaded(chatId: String, reason: String) async {
        guard memoryStore.chatState(for: chatId) == nil else {
            return
        }
        guard let conversation = memoryStore.conversation(for: chatId) else {
            return
        }
        guard !isBlocked(conversation.name) else {
            appendLog("Skipped loading blocked conversation \(conversation.name) (\(reason)).", level: .warning)
            return
        }
        await loadMessages(for: conversation, reason: reason, updateSelectedChat: false)
    }

    func openConversationAndCapture(_ targetConversation: ConversationSummary) async throws -> WhatsAppSnapshot {
        let targetNameKey = WhatsAppParserSupport.chatNameComparisonKey(targetConversation.name)
        let targetName = targetConversation.name
        for attempt in 1...3 {
            let baselineSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            let baselineState = parser.parse(snapshot: baselineSnapshot, messageLimit: 10)

            if WhatsAppParserSupport.chatNamesMatch(targetName, baselineState.selectedChatName) {
                return baselineSnapshot
            }

            let liveConversation = baselineState.conversations.first {
                $0.id == targetConversation.id || WhatsAppParserSupport.chatNameComparisonKey($0.name) == targetNameKey || WhatsAppParserSupport.chatNamesMatch(targetName, $0.name)
            } ?? targetConversation

            try interactor.selectConversation(liveConversation, using: accessibility)
            try await Task.sleep(for: .milliseconds(500))

            let updatedSnapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            let updatedState = parser.parse(snapshot: updatedSnapshot, messageLimit: 10)
            if WhatsAppParserSupport.chatNamesMatch(targetConversation.name, updatedState.selectedChatName) {
                return updatedSnapshot
            }

            appendLog("Conversation selection retry \(attempt) failed for \(targetConversation.name); current chat is \(updatedState.selectedChatName ?? "unknown").", level: .warning)
        }

        throw AccessibilityError.actionFailed(-1)
    }
}
