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
            ProfileWindowScreen(
                profile: profile,
                runtimeState: profilesController.displayState(for: profile).runtimeState,
                windowState: profilesController.displayState(for: profile).windowState
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
