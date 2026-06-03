import SwiftUI

@main
struct AIAssistantHubApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleController.self) private var lifecycleController

    private var runtime: AIAssistantHubRuntime?

    init() {
        if !RuntimeEnvironment.isStandardAppRuntime {
            runtime = nil
            return
        }

        runtime = AIAssistantHubRuntime(lifecycleController: lifecycleController)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
