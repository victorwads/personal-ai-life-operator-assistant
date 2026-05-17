import Foundation

@MainActor
final class WhatsAppPollingOrchestrator {
    private let memoryStore: WhatsAppMemoryStore
    private let appendLog: (String, LogLevel) -> Void
    private var listSignaturesById: [String: String] = [:]

    init(
        memoryStore: WhatsAppMemoryStore,
        appendLog: @escaping (String, LogLevel) -> Void
    ) {
        self.memoryStore = memoryStore
        self.appendLog = appendLog
    }

    func refresh(provider: WhatsAppIntegrationProvider, messageLimit: Int) async {
        do {
            let conversationsBefore = memoryStore.conversations.count
            let conversations = try await provider.parser.listConversations()
            memoryStore.replaceConversations(conversations)
            let conversationsAfter = memoryStore.conversations.count
            let dedupedIncomingCount = Set(conversations.map(\.name)).count
            let conversationDelta = max(0, conversationsAfter - conversationsBefore)
            appendLog(
                "Polling(\(provider.kind.rawValue)) conversations: incoming=\(conversations.count) (dedupByName=\(dedupedIncomingCount)) storeBefore=\(conversationsBefore) storeAfter=\(conversationsAfter) added=\(conversationDelta).",
                .info
            )
            await refreshChangedChats(
                provider: provider,
                conversations: conversations,
                messageLimit: messageLimit
            )
        } catch {
            appendLog("Polling refresh failed: \(error.localizedDescription)", .error)
        }
    }

    private func refreshChangedChats(
        provider: WhatsAppIntegrationProvider,
        conversations: [ConversationSummary],
        messageLimit: Int
    ) async {
        for conversation in conversations {
            let previous = listSignaturesById[conversation.id]
            let signatureChanged = previous != conversation.listSignature
            if previous == nil || signatureChanged {
                listSignaturesById[conversation.id] = conversation.listSignature
            }

            let isMissingCachedMessages = memoryStore.chatState(for: conversation.id) == nil
            let needsMessages = isMissingCachedMessages || previous == nil || signatureChanged
            guard needsMessages else { continue }

            do {
                try await provider.interactor.openConversation(conversation)
                var read = try await provider.parser.readMessages(limit: messageLimit)

                if provider.kind == .web, let flow = read.flow, flow != "chatSelected" {
                    appendLog(
                        "WhatsApp Web chat '\(conversation.name)' header observed but flow='\(flow)'; waiting DOM settle before ingest.",
                        .info
                    )
                    try await Task.sleep(for: .milliseconds(350))
                    read = try await provider.parser.readMessages(limit: messageLimit)
                }

                let match = WhatsAppParserSupport.chatTitleMatch(expected: conversation.name, actual: read.selectedChatName)
                if !match.isMatch {
                    appendLog(
                        "Selection mismatch (\(provider.kind.rawValue)): expected '\(match.expectedTitle)' but parsed '\(match.actualTitle)'. expectedKey=\(match.expectedKey) actualKey=\(match.actualKey) flow=\(match.flowLabel(read.flow)). Skipping ingest.",
                        .warning
                    )
                    continue
                }

                if match.didNormalizeOrTruncate {
                    appendLog(
                        "Selection confirmed (\(provider.kind.rawValue)): expected '\(match.expectedTitle)' matched '\(match.actualTitle)' via \(match.methodLabel). expectedKey=\(match.expectedKey) actualKey=\(match.actualKey) flow=\(match.flowLabel(read.flow)).",
                        .info
                    )
                }

                let chatState = ChatState(
                    chat: conversation,
                    messages: read.messages,
                    composeFocused: read.composeFocused,
                    canSendText: read.canSendText
                )

                let beforeCount = memoryStore.chatState(for: conversation.id)?.messages.count ?? 0
                memoryStore.upsertChatState(chatState)
                let afterCount = memoryStore.chatState(for: conversation.id)?.messages.count ?? 0
                let added = max(0, afterCount - beforeCount)
                appendLog(
                    "Loaded \(read.messages.count) messages for \(conversation.name) (\(provider.kind.rawValue)) ingestedAdded=\(added) storeTotal=\(afterCount) storeBefore=\(beforeCount) flow=\(match.flowLabel(read.flow)).",
                    .info
                )
            } catch {
                appendLog("Failed to load messages for \(conversation.name): \(error.localizedDescription)", .warning)
            }
        }
    }
}
