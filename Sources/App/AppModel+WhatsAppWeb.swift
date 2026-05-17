import Foundation
import WebKit

extension AppModel {
    func loadWhatsAppWebAccounts() async {
        let accounts = await whatsAppWebAccountsRepository.list()
        if let primaryWhatsAppWebAccountId,
           let match = accounts.first(where: { $0.id == primaryWhatsAppWebAccountId }) {
            whatsAppWebAccounts = [match]
            whatsAppWebSessionStore.warmSessions(for: [match])
            selectedWhatsAppWebAccountId = match.id
            restartWhatsAppWebBridgePolling()
            return
        }

        whatsAppWebAccounts = accounts
        whatsAppWebSessionStore.warmSessions(for: accounts)
        restartWhatsAppWebBridgePolling()

        if let selectedWhatsAppWebAccountId,
           accounts.contains(where: { $0.id == selectedWhatsAppWebAccountId }) {
            return
        }

        selectedWhatsAppWebAccountId = accounts.first?.id
    }

    func addWhatsAppWebAccount(named name: String) async {
        do {
            let account = try await whatsAppWebAccountsRepository.create(name: name)
            whatsAppWebAccounts.append(account)
            whatsAppWebAccounts.sort { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            _ = whatsAppWebSessionStore.webView(for: account)
            selectedWhatsAppWebAccountId = account.id
            appendLog("Created WhatsApp Web account '\(account.name)'.")
            restartWhatsAppWebBridgePolling()
        } catch {
            appendLog("Failed to create WhatsApp Web account: \(error.localizedDescription)", level: .error)
        }
    }

    func deleteWhatsAppWebAccount(id: UUID) async {
        let deleted = await whatsAppWebAccountsRepository.delete(id: id)
        guard deleted else {
            appendLog("Could not delete WhatsApp Web account.", level: .warning)
            return
        }

        let removedWasSelected = selectedWhatsAppWebAccountId == id
        whatsAppWebSessionStore.removeSession(accountId: id)
        whatsAppWebAccounts.removeAll { $0.id == id }
        if removedWasSelected {
            selectedWhatsAppWebAccountId = whatsAppWebAccounts.first?.id
        }
        whatsAppWebPageSnapshotsByAccountId.removeValue(forKey: id)
        restartWhatsAppWebBridgePolling()
        appendLog("Deleted WhatsApp Web account.")
    }

    var selectedWhatsAppWebAccount: WhatsAppWebAccount? {
        guard let selectedWhatsAppWebAccountId else {
            return nil
        }

        return whatsAppWebAccounts.first { $0.id == selectedWhatsAppWebAccountId }
    }

    var selectedWhatsAppWebPageSnapshot: WhatsAppWebPageSnapshot? {
        guard let selectedWhatsAppWebAccountId else {
            return nil
        }

        return whatsAppWebPageSnapshotsByAccountId[selectedWhatsAppWebAccountId]
    }

    func captureWhatsAppWebSnapshot(for account: WhatsAppWebAccount) async {
        let webView = whatsAppWebSessionStore.webView(for: account)

        do {
            let snapshot = try await whatsAppWebBridge.captureSnapshot(from: webView)
            whatsAppWebPageSnapshotsByAccountId[account.id] = snapshot
        } catch {
            appendLog("WhatsApp Web snapshot failed for '\(account.name)': \(error.localizedDescription)", level: .warning)
        }
    }

    func captureAndSaveWhatsAppWebSnapshot(for account: WhatsAppWebAccount, named captureName: String?) async {
        let webView = whatsAppWebSessionStore.webView(for: account)

        do {
            let snapshot = try await whatsAppWebBridge.captureSnapshot(from: webView)
            whatsAppWebPageSnapshotsByAccountId[account.id] = snapshot
            let dom = try? await whatsAppWebBridge.captureDebugDOM(from: webView)
            _ = whatsAppWebDebugCaptureService.saveSnapshot(
                accountName: account.name,
                captureName: captureName,
                snapshot: snapshot,
                dom: dom
            )
        } catch {
            appendLog("WhatsApp Web snapshot failed for '\(account.name)': \(error.localizedDescription)", level: .warning)
        }
    }

    func forceUpdateSelectedWhatsAppWebChat(for account: WhatsAppWebAccount) async {
        let webView = whatsAppWebSessionStore.webView(for: account)

        do {
            let capture = try await captureSettledWhatsAppWebChat(from: webView, limit: 50)
            guard let selectedChatTitle = capture.selectedChatTitle,
                  !selectedChatTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                appendLog("Could not update current WhatsApp Web chat for '\(account.name)': selected chat title is missing.", level: .warning)
                return
            }

            let conversation = makeWhatsAppWebConversation(
                accountId: account.id,
                chatTitle: selectedChatTitle,
                capture: capture
            )
            let chatState = makeWhatsAppWebChatState(
                accountId: account.id,
                conversation: conversation,
                capture: capture
            )

            memoryStore.replaceConversations([conversation])
            memoryStore.upsertChatState(chatState)
            appendLog("Updated current WhatsApp Web chat '\(conversation.name)' with \(chatState.messages.count) messages.")
        } catch {
            appendLog("Failed to update current WhatsApp Web chat for '\(account.name)': \(error.localizedDescription)", level: .error)
        }
    }

    func restartWhatsAppWebBridgePolling() {
        whatsAppWebBridgePollingTask?.cancel()
        whatsAppWebBridgePollingTask = nil

        guard whatsAppWebSettings.bridgePollingEnabled, !whatsAppWebAccounts.isEmpty else {
            return
        }

        let intervalSeconds = max(1.0, whatsAppWebSettings.bridgePollingIntervalSeconds)
        whatsAppWebBridgePollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let accounts = self.whatsAppWebAccounts
                for account in accounts {
                    if Task.isCancelled { return }
                    await self.captureWhatsAppWebSnapshot(for: account)
                }

                do {
                    try await Task.sleep(for: .seconds(intervalSeconds))
                } catch {
                    return
                }
            }
        }
    }

    private func captureSettledWhatsAppWebChat(from webView: WKWebView, limit: Int) async throws -> WhatsAppWebChatCapture {
        let first = try await whatsAppWebBridge.captureSelectedChat(from: webView, limit: limit)
        let settleDelay = max(0, Int(whatsAppWebSettings.messageSettleDelayMilliseconds.rounded()))
        if settleDelay > 0 {
            try await Task.sleep(for: .milliseconds(settleDelay))
        }
        let second = try await whatsAppWebBridge.captureSelectedChat(from: webView, limit: limit)
        return second.messages.count > first.messages.count ? second : first
    }

    private func makeWhatsAppWebConversation(
        accountId: UUID,
        chatTitle: String,
        capture: WhatsAppWebChatCapture
    ) -> ConversationSummary {
        let chatId = "web:\(accountId.uuidString):\(chatTitle)"
        let lastMessage = capture.messages.last
        let lastMessageStatus: MessageStatus = {
            switch lastMessage?.statusTestId {
            case "msg-check":
                return .sent
            case "msg-dblcheck":
                return .delivered
            default:
                return .unknown
            }
        }()

        return ConversationSummary(
            id: chatId,
            accessibilityPath: [],
            name: chatTitle,
            unreadCount: 0,
            isPinned: false,
            isSelected: capture.flow == .chatSelected,
            lastMessagePreview: lastMessage?.text,
            lastMessageAtText: lastMessage?.timestampText,
            lastMessageDirection: lastMessage?.direction ?? .unknown,
            lastMessageStatus: lastMessageStatus,
            isTyping: false
        )
    }

    private func makeWhatsAppWebChatState(
        accountId: UUID,
        conversation: ConversationSummary,
        capture: WhatsAppWebChatCapture
    ) -> ChatState {
        let chatId = "web:\(accountId.uuidString):\(conversation.name)"
        let messages: [Message] = capture.messages.map { captured in
            let normalizedText = captured.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let ts = captured.timestampText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let id = "\(chatId)|\(captured.direction.rawValue)|text|\(normalizedText)|\(ts)"

            let status: MessageStatus = {
                switch captured.statusTestId {
                case "msg-check":
                    return .sent
                case "msg-dblcheck":
                    return .delivered
                default:
                    return .unknown
                }
            }()

            return Message(
                id: id,
                chatId: chatId,
                direction: captured.direction,
                kind: .text,
                authorName: captured.authorName,
                origin: .unknown,
                text: captured.text,
                durationSeconds: nil,
                timestamp: nil,
                status: status,
                rawAccessibilityText: captured.text,
                whatsappTimestampText: captured.timestampText
            )
        }

        return ChatState(
            chat: conversation,
            messages: messages,
            composeFocused: capture.flow == .chatSelected,
            canSendText: capture.flow == .chatSelected
        )
    }
}
