import Foundation

protocol WhatsAppMessageSending: Sendable {
    func sendMessages(_ request: WhatsAppMessageSendRequest) async throws -> WhatsAppMessageSendResult
}
