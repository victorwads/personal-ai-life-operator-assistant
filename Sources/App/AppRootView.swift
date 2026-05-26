import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var authController: AuthStateController
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            switch authController.state {
            case .authenticated:
                AuthenticatedRootView()
            default:
                AuthenticationRootView()
            }
        }
        .onChange(of: authController.state) { _, newState in
            switch newState {
            case .unauthenticated, .failed, .loading:
                Task { @MainActor in
                    await appModel.stopAuthenticatedShell()
                }
            case .authenticated:
                if let session = authController.currentSession {
                    appModel.startAuthenticatedShell(session: session)
                }
            }
        }
    }
}
