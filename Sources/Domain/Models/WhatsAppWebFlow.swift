import Foundation

enum WhatsAppWebFlow: String, Codable, Equatable {
    case loginQr
    case downloading
    case chatList
    case chatSelected
    case unknown
}

