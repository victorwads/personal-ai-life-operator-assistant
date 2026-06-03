import Foundation

struct WhatsAppMessageSendResult: Sendable, Equatable {
    let chatId: String
    let receipts: [WhatsAppMessageSendReceipt]
}

struct WhatsAppMessageSendReceipt: Sendable, Equatable {
    let text: String
    let chatMessageId: String?
}
