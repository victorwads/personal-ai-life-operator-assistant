import SwiftUI

@main
struct AssistantMCPServerApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
