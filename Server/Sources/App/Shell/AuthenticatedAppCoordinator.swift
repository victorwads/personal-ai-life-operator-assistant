import Foundation
import SwiftUI

@MainActor
final class AuthenticatedAppCoordinator: ObservableObject {
    let profilesController: ProfilesController
    var onProfilesChanged: (([Profile]) -> Void)?

    private var currentSession: AuthSession?

    init(profilesController: ProfilesController) {
        self.profilesController = profilesController
        self.profilesController.onProfilesChanged = { [weak self] profiles in
            Task { @MainActor in
                await self?.handleProfilesUpdated(profiles)
            }
        }
    }

    func start(session: AuthSession) {
        currentSession = session
        profilesController.setAuthSession(session)
        profilesController.loadProfiles()
    }

    func stop(flushPendingSettings: Bool = true) async {
        await profilesController.stopAllRunningProfiles(flushPendingSettings: flushPendingSettings)
        profilesController.reset()
        currentSession = nil
    }

    var profileDisplayStates: [ProfileDisplayState] {
        profilesController.profileDisplayStates
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    func makeProfilesHomeContent() -> AnyView {
        AnyView(
            ProfilesHomeWindowHostView(
                profilesController: profilesController
            )
        )
    }

    private func handleProfilesUpdated(_ profiles: [Profile]) async {
        guard let session = currentSession else {
            onProfilesChanged?(profiles)
            return
        }

        await profilesController.startAutoStartProfiles()

        onProfilesChanged?(profiles)
    }
}
