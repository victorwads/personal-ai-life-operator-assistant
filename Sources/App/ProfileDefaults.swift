import Foundation

enum ProfileDefaults {
    static func defaults(for profile: AppProfile) -> UserDefaults {
        if profile.isDefault {
            return .standard
        }

        let suiteName = "dev.wads.AssistantMCPServer.profile.\(profile.id)"
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
}

