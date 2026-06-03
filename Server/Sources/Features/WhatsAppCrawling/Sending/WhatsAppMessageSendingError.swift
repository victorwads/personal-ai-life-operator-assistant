import Foundation

enum WhatsAppMessageSendingError: Error, Equatable, LocalizedError {
    case notImplemented
    case webViewUnavailable
    case chatNotFound(String)
    case timeout
    case messageNotObserved(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "WhatsApp message sending is not implemented yet."
        case .webViewUnavailable:
            return "WhatsApp WebView is unavailable."
        case let .chatNotFound(chatId):
            return "Chat not found: \(chatId)"
        case .timeout:
            return "Timed out while sending WhatsApp messages."
        case let .messageNotObserved(text):
            return "Sent message was not observed in chat: \(text)"
        }
    }
}
