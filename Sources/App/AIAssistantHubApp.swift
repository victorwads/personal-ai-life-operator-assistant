import SwiftUI
import FirebaseCore

@main
struct AIAssistantHubApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleController.self) private var lifecycleController

    @StateObject private var authController: AuthStateController
    @StateObject private var appModel: AppModel

    init() {
        AppBootstrapper.configureFirebaseIfNeeded()
        AppBootstrapper.validateFirebaseConfigured()

        let authController = AuthStateController(repository: FirebaseAuthRepository())
        let trayIconController = TrayIconController()
        let appModel = AppModel(authController: authController, trayIconController: trayIconController)

        _authController = StateObject(wrappedValue: authController)
        _appModel = StateObject(wrappedValue: appModel)

        lifecycleController.configure(authController: authController, appModel: appModel)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
