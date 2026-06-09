import Foundation

struct WhatsAppMessageSendRequest: Sendable, Equatable {
    let chatId: String?
    let phone: String?
    let messages: [String]
}
