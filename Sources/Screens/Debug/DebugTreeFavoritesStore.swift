import Foundation

enum DebugTreeFavoritesStore {
    private static let storageKey = "debugTreeFavoritesV1"

    static func load() -> [String: [Int]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: [Int]].self, from: data)
        } catch {
            return [:]
        }
    }

    static func save(_ favorites: [String: [Int]]) {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }
}

