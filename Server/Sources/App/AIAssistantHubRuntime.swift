import Foundation

@MainActor
final class AIAssistantHubRuntime {
    let authController: AuthStateController
    let appModel: AppModel

    init(lifecycleController: AppLifecycleController) {
        FirebaseAppConfigurator.configure()

        let authController = AuthStateController(repository: FirebaseAuthRepository())
        let trayIconController = TrayIconController()
        let appModel = AppModel(authController: authController, trayIconController: trayIconController)

        self.authController = authController
        self.appModel = appModel

        lifecycleController.configure(authController: authController, appModel: appModel)
    }
}
