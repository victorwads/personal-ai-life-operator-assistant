import AppKit
import Foundation

@MainActor
final class AppLifecycleController: NSObject, NSApplicationDelegate {
    weak var authController: AuthStateController?
    weak var appModel: AppModel?

    func configure(authController: AuthStateController, appModel: AppModel) {
        self.authController = authController
        self.appModel = appModel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appModel?.openDefaultWindowForCurrentState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return false
        }
        appModel?.openDefaultWindowForCurrentState()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            await authController?.handleOpenURL(url)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appModel else {
            return .terminateNow
        }

        if appModel.isPreparedForTermination {
            return .terminateNow
        }

        // Ensure background runtimes are stopped before quitting.
        Task { @MainActor in
            await appModel.prepareForTermination()
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
