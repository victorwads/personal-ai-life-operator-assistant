import SwiftUI

@MainActor
struct ProfilesHomeWindowHostView: View {
    @ObservedObject private var profilesController: ProfilesController

    init(profilesController: ProfilesController) {
        _profilesController = ObservedObject(wrappedValue: profilesController)
    }

    var body: some View {
        ProfilesHomeScreen(profilesController: profilesController)
    }
}
