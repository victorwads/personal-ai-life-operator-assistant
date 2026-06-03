import SwiftUI

struct AuthenticatedRootView: View {
    @EnvironmentObject private var coordinator: AuthenticatedAppCoordinator

    var body: some View {
        ProfilesHomeWindowHostView(
            profilesController: coordinator.profilesController
        )
    }
}
