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
        guardContent
            .frame(minWidth: 760, minHeight: 520)
    }

    @ViewBuilder
    private var guardContent: some View {
        if let profile = resolvedProfile, let container = resolvedContainer {
            CommandCenterScreen(
                profile: profile,
                runtimeState: profilesController.displayState(for: profile).runtimeState,
                windowState: profilesController.displayState(for: profile).windowState,
                statusRegistry: container.statusRegistry,
                settingsFeature: container.feature(SettingsFeature.self),
                memoriesFeature: container.feature(MemoriesFeature.self),
                whatsAppCrawlingFeature: container.feature(WhatsAppCrawlingFeature.self)
            )
        } else if resolvedProfile == nil {
            loading("Loading profile...")
        } else {
            loading("Loading profile runtime...")
        }
    }

    private func loading(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
    }

    private var resolvedProfile: Profile? {
        profilesController.profiles.first(where: { $0.id == profileId })
    }

    private var resolvedContainer: ProfileRuntimeContainer? {
        profilesController.runtimeController.runtime(for: profileId)?.container
    }
}
