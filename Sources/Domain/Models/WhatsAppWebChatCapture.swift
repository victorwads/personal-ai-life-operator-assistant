import Foundation

struct WhatsAppWebChatCapture: Codable, Equatable {
    struct CapturedMessage: Codable, Equatable {
        let direction: MessageDirection
        let authorName: String?
        let text: String
        let timestampText: String?
    }

    let flow: WhatsAppWebFlow
    let selectedChatTitle: String?
    let messages: [CapturedMessage]
}

