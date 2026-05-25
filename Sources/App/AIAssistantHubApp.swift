import SwiftUI
import FirebaseCore

@main
struct AIAssistantHubApp: App {
    @StateObject private var authController = AuthStateController(repository: FirebaseAuthRepository())

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        guard FirebaseApp.app() != nil else {
            fatalError("Firebase failed to configure. Ensure GoogleService-Info.plist is included in the app bundle Resources.")
        }
    }

    var body: some Scene {
        Window("AI Assistant Hub", id: "main") {
            AuthenticationRootView()
                .environmentObject(authController)
        }
    }
}
