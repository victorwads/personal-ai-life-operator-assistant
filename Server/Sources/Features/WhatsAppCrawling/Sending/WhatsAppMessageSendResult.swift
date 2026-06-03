import Foundation

struct WhatsAppMessageSendResult: Sendable, Equatable {
    let chatId: String
    let receipts: [WhatsAppMessageSendReceipt]
}

struct WhatsAppMessageSendReceipt: Sendable, Equatable {
    let requestedText: String
    let observedMessage: ChatMessage?

    var text: String {
        observedMessage?.text ?? requestedText
    }

    var chatMessageId: String? {
        observedMessage?.id
    }

    var chatId: String? {
        observedMessage?.chatId
    }

    var author: String? {
        observedMessage?.author
    }

    var kind: ChatMessage.Kind {
        observedMessage?.kind ?? .text
    }

    var direction: ChatMessage.Direction {
        observedMessage?.direction ?? .sent
    }

    var sentAt: Date? {
        observedMessage?.dateTime
    }

    var listOrder: Int {
        observedMessage?.listOrder ?? 0
    }
}
