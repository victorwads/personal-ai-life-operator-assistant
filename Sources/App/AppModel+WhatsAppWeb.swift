import Foundation

extension AppModel {
    func loadWhatsAppWebAccounts() async {
        let accounts = await whatsAppWebAccountsRepository.list()
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
            if snapshot.flow == .chatSelected, let title = snapshot.selectedChatTitle, !title.isEmpty {
                await captureAndIngestSelectedChat(for: account)
            }
        } catch {
            appendLog("WhatsApp Web snapshot failed for '\(account.name)': \(error.localizedDescription)", level: .warning)
        }
    }

    func captureAndSaveWhatsAppWebSnapshot(for account: WhatsAppWebAccount, named captureName: String?) async {
        let webView = whatsAppWebSessionStore.webView(for: account)

        do {
            let snapshot = try await whatsAppWebBridge.captureSnapshot(from: webView)
            whatsAppWebPageSnapshotsByAccountId[account.id] = snapshot
            _ = whatsAppWebDebugCaptureService.saveSnapshot(accountName: account.name, captureName: captureName, snapshot: snapshot)
            if snapshot.flow == .chatSelected {
                await captureAndIngestSelectedChat(for: account)
            }
        } catch {
            appendLog("WhatsApp Web snapshot failed for '\(account.name)': \(error.localizedDescription)", level: .warning)
        }
    }

    private func captureAndIngestSelectedChat(for account: WhatsAppWebAccount) async {
        let webView = whatsAppWebSessionStore.webView(for: account)
        do {
            let capture = try await whatsAppWebBridge.captureSelectedChat(from: webView, limit: 50)
            guard capture.flow == .chatSelected else { return }
            guard let title = capture.selectedChatTitle, !title.isEmpty else { return }

            let chatId = "web:\(account.id.uuidString):\(title)"
            let conversation = ConversationSummary(
                id: chatId,
                accessibilityPath: [],
                name: title,
                unreadCount: 0,
                isPinned: false,
                isSelected: true,
                lastMessagePreview: capture.messages.last?.text,
                lastMessageAtText: capture.messages.last?.timestampText,
                lastMessageDirection: capture.messages.last?.direction ?? .unknown,
                lastMessageStatus: .unknown,
                isTyping: false
            )

            let messages: [Message] = capture.messages.map { captured in
                let normalizedText = (captured.text).trimmingCharacters(in: .whitespacesAndNewlines)
                let ts = captured.timestampText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let id = "\(chatId)|\(captured.direction.rawValue)|text|\(normalizedText)|\(ts)"
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
                    status: .unknown,
                    rawAccessibilityText: captured.text,
                    whatsappTimestampText: captured.timestampText
                )
            }

            memoryStore.replaceConversations([conversation])
            memoryStore.upsertChatState(
                ChatState(
                    chat: conversation,
                    messages: messages,
                    composeFocused: true,
                    canSendText: true
                )
            )
        } catch {
            appendLog("WhatsApp Web message ingest failed for '\(account.name)': \(error.localizedDescription)", level: .warning)
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
}
