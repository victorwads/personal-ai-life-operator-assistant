import Foundation

struct WhatsAppMessageSendRequest: Sendable, Equatable {
    let chatId: String
    let messages: [String]
}
