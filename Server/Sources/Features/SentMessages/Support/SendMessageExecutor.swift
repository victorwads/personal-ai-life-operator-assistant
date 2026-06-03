import Foundation

struct SentMessageSendOutcome {
    let sentMessage: SentMessage
    let receiptCount: Int
    let missingReceiptCount: Int
}

final class SendMessageExecutor {
    private let repository: FirestoreSentMessageRepository
    private let settings: SentMessagesSettingsWrapper
    private let senderProvider: @MainActor () -> any WhatsAppMessageSending

    init(
        repository: FirestoreSentMessageRepository,
        settings: SentMessagesSettingsWrapper,
        senderProvider: @escaping @MainActor () -> any WhatsAppMessageSending
    ) {
        self.repository = repository
        self.settings = settings
        self.senderProvider = senderProvider
    }

    func execute(
        issueId: String,
        chatId: String,
        messages: [String]
    ) async throws -> SentMessageSendOutcome {
        let (prefix, postfix, header, footer) = await MainActor.run {
            (
                settings.messagePrefix,
                settings.messagePostfix,
                settings.messageHeader,
                settings.messageFooter
            )
        }

        let formattedMessages = SentMessageFormatter.format(
            rawMessages: messages,
            prefix: prefix,
            postfix: postfix,
            header: header,
            footer: footer
        )

        guard !formattedMessages.isEmpty else {
            throw SendMessageMCPToolError.emptyMessages
        }

        var pendingRecord = try await repository.save(
            SentMessage(
                id: nil,
                issueId: issueId,
                // TODO: Resolve chat title from ChatsFeature when audit/detail views
                // need a stable human-readable target label.
                chatId: chatId,
                chatTitle: nil,
                messages: formattedMessages,
                status: .pending,
                chatMessageIds: [],
                errorMessage: nil,
                sentAt: nil
            )
        )

        let sender = await MainActor.run { senderProvider() }

        do {
            let result = try await sender.sendMessages(
                WhatsAppMessageSendRequest(chatId: chatId, messages: formattedMessages)
            )

            let chatMessageIds = result.receipts.compactMap(\.chatMessageId)
            let missingReceiptCount = max(0, result.receipts.count - chatMessageIds.count)
            pendingRecord.status = missingReceiptCount == 0 ? .sent : .partiallySent
            pendingRecord.chatMessageIds = chatMessageIds
            pendingRecord.errorMessage = missingReceiptCount == 0
                ? nil
                : "Observed \(chatMessageIds.count) of \(result.receipts.count) outbound messages."
            pendingRecord.sentAt = Date()

            let saved = try await repository.save(pendingRecord)
            return SentMessageSendOutcome(
                sentMessage: saved,
                receiptCount: result.receipts.count,
                missingReceiptCount: missingReceiptCount
            )
        } catch {
            pendingRecord.status = .failed
            pendingRecord.errorMessage = error.localizedDescription.trimmedNonEmpty ?? "Unknown send failure."
            pendingRecord.sentAt = Date()
            // TODO: Consider returning the failed audit record id in MCP failure metadata later.
            // The record is persisted, but the current thrown error path does not expose the
            // SentMessage id back to the model/tool caller.
            _ = try await repository.save(pendingRecord)
            throw error
        }
    }
}
