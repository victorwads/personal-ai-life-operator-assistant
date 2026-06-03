import Foundation

public struct ProfileDisplayState: Identifiable, Equatable, Sendable {
    public var id: String {
        profile.id ?? profile.name
    }

    public let profile: Profile
    public let runtimeState: ProfileRuntimeState
    public let windowState: ProfileWindowState

    public init(profile: Profile, runtimeState: ProfileRuntimeState, windowState: ProfileWindowState) {
        self.profile = profile
        self.runtimeState = runtimeState
        self.windowState = windowState
    }

    public var isAutoStartEnabled: Bool {
        profile.autoStart
    }

    public var mcpPort: Int {
        profile.mcpPort
    }
}
