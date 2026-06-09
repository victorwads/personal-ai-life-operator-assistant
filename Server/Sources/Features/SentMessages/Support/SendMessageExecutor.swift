import Foundation

struct SentMessageSendOutcome {
    let sentMessage: SentMessage
    let receiptCount: Int
    let missingReceiptCount: Int
}

final class SendMessageExecutor {
    private let repository: any SentMessageRepository
    private let chatRepositoryProvider: @MainActor () -> any ChatRepository
    private let settings: SentMessagesSettingsWrapper
    private let senderProvider: @MainActor () -> any WhatsAppMessageSending

    init(
        repository: any SentMessageRepository,
        chatRepositoryProvider: @escaping @MainActor () -> any ChatRepository,
        settings: SentMessagesSettingsWrapper,
        senderProvider: @escaping @MainActor () -> any WhatsAppMessageSending
    ) {
        self.repository = repository
        self.chatRepositoryProvider = chatRepositoryProvider
        self.settings = settings
        self.senderProvider = senderProvider
    }

    func execute(
        issueId: String,
        chatIdentification: String,
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

        let chatRepository = await MainActor.run { chatRepositoryProvider() }
        let resolvedDestination = try await resolveDestination(
            chatIdentification: chatIdentification,
            chatRepository: chatRepository
        )

        var pendingRecord = try await repository.save(
            SentMessage(
                id: nil,
                issueId: issueId,
                // TODO: Resolve chat title from ChatsFeature when audit/detail views
                // need a stable human-readable target label.
                chatId: resolvedDestination.auditChatId,
                chatTitle: nil,
                messages: formattedMessages,
                status: .pending,
                chatMessageIds: [],
                errorMessage: nil,
                sentAt: nil
            ),
            merge: true
        )

        let sender = await MainActor.run { senderProvider() }

        do {
            let result = try await sender.sendMessages(
                WhatsAppMessageSendRequest(
                    chatId: resolvedDestination.chatId,
                    phone: resolvedDestination.phone,
                    messages: formattedMessages
                )
            )

            let observedMessages = assistantMessages(
                from: result.receipts,
                destinationChatId: result.chatId
            )
            if !observedMessages.isEmpty {
                _ = try await chatRepository.insertMessages(observedMessages)
            }

            let chatMessageIds = result.receipts.compactMap(\.chatMessageId)
            let missingReceiptCount = max(0, result.receipts.count - chatMessageIds.count)
            pendingRecord.chatId = result.chatId
            pendingRecord.status = missingReceiptCount == 0 ? .sent : .partiallySent
            pendingRecord.chatMessageIds = chatMessageIds
            pendingRecord.errorMessage = missingReceiptCount == 0
                ? nil
                : "Observed \(chatMessageIds.count) of \(result.receipts.count) outbound messages."
            pendingRecord.sentAt = Date()

            let saved = try await repository.save(pendingRecord, merge: true)
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
            _ = try await repository.save(pendingRecord, merge: true)
            throw error
        }
    }

    private func resolveDestination(
        chatIdentification: String,
        chatRepository: any ChatRepository
    ) async throws -> SendDestination {
        if let chat = try await chatRepository.getChat(id: chatIdentification), let chatId = chat.id?.trimmedNonEmpty {
            return SendDestination(chatId: chatId, phone: nil, auditChatId: chatId)
        }

        let normalizedPhone = chatIdentification.filter(\.isNumber)
        guard !normalizedPhone.isEmpty else {
            throw MCPToolExtractionError.invalidField(
                "chatIdentification",
                reason: "provide either a real chat ID from chat listings or a phone number using digits only."
            )
        }

        return SendDestination(
            chatId: nil,
            phone: normalizedPhone,
            auditChatId: normalizedPhone
        )
    }

    private func assistantMessages(
        from receipts: [WhatsAppMessageSendReceipt],
        destinationChatId: String
    ) -> [ChatMessage] {
        receipts.compactMap { receipt in
            guard let chatMessageId = receipt.chatMessageId else {
                return nil
            }

            return ChatMessage(
                id: chatMessageId,
                chatId: receipt.chatId ?? destinationChatId,
                author: receipt.author,
                text: receipt.text,
                kind: receipt.kind,
                direction: .sent,
                listOrder: receipt.listOrder,
                dateTime: receipt.sentAt,
                quotedMessageText: receipt.observedMessage?.quotedMessageText,
                quotedMessageAuthor: receipt.observedMessage?.quotedMessageAuthor,
                localMediaPaths: receipt.observedMessage?.localMediaPaths ?? [],
                handled: true,
                sentByAssistant: true
            )
        }
    }
}

private struct SendDestination {
    let chatId: String?
    let phone: String?
    let auditChatId: String
}
