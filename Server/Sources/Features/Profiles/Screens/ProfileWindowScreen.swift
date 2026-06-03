import SwiftUI

public struct ProfileWindowScreen: View {
    public let profile: Profile
    public let runtimeState: ProfileRuntimeState
    public let windowState: ProfileWindowState

    public init(profile: Profile, runtimeState: ProfileRuntimeState, windowState: ProfileWindowState) {
        self.profile = profile
        self.runtimeState = runtimeState
        self.windowState = windowState
    }

    public var body: some View {
        MyProfileScreen(
            profile: profile,
            runtimeState: runtimeState,
            windowState: windowState
        )
        .frame(minWidth: 760, minHeight: 520, alignment: .topLeading)
    }
}
