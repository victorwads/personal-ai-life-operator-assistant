import Foundation

struct ChatMessage: PersistableModel, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case text
        case image
        case sticker
        case audio
        case unknown
    }
    
    enum Direction: String, Codable, Sendable {
        case sent
        case received
    }

    @DocumentID var id: String?
    var chatId: String
    var author: String?
    var text: String?
    var kind: Kind
    var direction: Direction = .received
    var listOrder: Int = 0
    var dateTime: Date?
    var quotedMessageText: String?
    var quotedMessageAuthor: String?
    var localMediaPaths: [String] = []
    var handled: Bool = false
    var sentByAssistant: Bool? = false

}
