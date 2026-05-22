import Foundation

struct WhatsAppWebPageSnapshot: Codable, Equatable {
    let url: String
    let title: String
    let documentReadyState: String
    let rawHTML: String
    let isLoggedIn: Bool
    let hasQrCanvas: Bool
    let chatRowCount: Int
    let unreadBadgeCount: Int
    let selectedChatTitle: String?
    let composePlaceholder: String?
    let bodyTextSample: String
    let flow: WhatsAppWebFlow
    let capturedAt: Date
}
