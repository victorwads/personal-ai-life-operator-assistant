import Foundation

struct ProfileContext: Sendable {
    let profileId: String
    let profile: Profile
    let scope: FirebaseProfileScope?
    let mcpPort: Int

    init(profile: Profile) {
        self.profile = profile
        self.profileId = profile.id ?? ""
        self.scope = profile.id.map { FirebaseProfileScope(profileId: $0) }
        self.mcpPort = profile.mcpPort
    }
}
