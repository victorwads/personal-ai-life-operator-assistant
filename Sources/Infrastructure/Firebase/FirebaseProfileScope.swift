import Foundation

public struct FirebaseProfileScope: Equatable, Sendable {
    public let profileId: String

    public init(profileId: String) {
        self.profileId = profileId
    }

    public var rootPath: String {
        "profiles/\(profileId)"
    }
}
