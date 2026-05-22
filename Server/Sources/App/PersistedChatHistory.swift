import Foundation

struct PersistedChatHistory: Codable, Equatable {
    var version: Int = 1
    var updatedAt: Date = Date()
    var chatStatesByChatId: [String: ChatState] = [:]
}

