import SwiftUI

@MainActor
struct ProfileWindowHostView: View {
    @ObservedObject private var profilesController: ProfilesController
    let profileId: String

    init(
        profileId: String,
        profilesController: ProfilesController
    ) {
        self.profileId = profileId
        _profilesController = ObservedObject(wrappedValue: profilesController)
    }

    var body: some View {
        if let profile = profilesController.profiles.first(where: { $0.id == profileId }) {
            let runtime = profilesController.runtimeController.runtime(for: profileId)
            CommandCenterScreen(
                profile: profile,
                runtimeState: profilesController.displayState(for: profile).runtimeState,
                windowState: profilesController.displayState(for: profile).windowState,
                settingsSectionRegistry: runtime?.container?.settingsSectionRegistry
            )
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading profile...")
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 760, minHeight: 520)
        }
    }
}
