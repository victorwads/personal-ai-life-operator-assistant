import Foundation

actor AppProfilesRepository {
    static let shared = AppProfilesRepository()

    private let defaults: UserDefaults
    private let storageKey = "appProfiles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOrCreateDefaultProfiles() -> [AppProfile] {
        if let loaded = load(), !loaded.isEmpty {
            return loaded
        }

        // First implementation: ensure the app starts with 2 profiles.
        let profiles = [
            AppProfile.default,
            AppProfile(id: "profile-2", displayName: "Profile 2", isDefault: false)
        ]
        persist(profiles)
        return profiles
    }

    func load() -> [AppProfile]? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return (try? JSONDecoder().decode([AppProfile].self, from: data)) ?? nil
    }

    func persist(_ profiles: [AppProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}

