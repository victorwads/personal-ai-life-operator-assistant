import SwiftUI

public struct MyProfileScreen: View {
    public let profile: Profile
    public let runtimeState: ProfileRuntimeState
    public let windowState: ProfileWindowState

    public init(profile: Profile, runtimeState: ProfileRuntimeState, windowState: ProfileWindowState) {
        self.profile = profile
        self.runtimeState = runtimeState
        self.windowState = windowState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(profile.name)
                .font(.largeTitle.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                labeled("Profile ID", profile.id ?? "(unsaved)")
                labeled("MCP Port", "\(profile.mcpPort)")
                labeled("Runtime", runtimeState.rawValue)
                labeled("Window", windowState.rawValue)
            }

            Divider()

            Text("This profile workspace will host runtime services, MCP server, WhatsApp crawler, assistant loop, settings and logs.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}
