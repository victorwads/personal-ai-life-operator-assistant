import Foundation

@MainActor
final class ChatHistoryRepository {
    static let shared = ChatHistoryRepository()

    private let defaults: UserDefaults
    private let storageKey = "chatHistory.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> PersistedChatHistory? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try JSONDecoder().decode(PersistedChatHistory.self, from: data)
    }

    func save(_ payload: PersistedChatHistory) throws {
        let data = try JSONEncoder().encode(payload)
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
