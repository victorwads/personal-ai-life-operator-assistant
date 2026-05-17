import AppKit
import SwiftUI

@MainActor
final class ProfileWindowManager {
    static let shared = ProfileWindowManager()

    private var controllersByProfileId: [String: NSWindowController] = [:]
    private var appModelsByProfileId: [String: AppModel] = [:]

    func showMainWindow(profile: AppProfile, appModel: AppModel) {
        appModelsByProfileId[profile.id] = appModel

        if let existing = controllersByProfileId[profile.id], let window = existing.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView()
            .environmentObject(appModel)
            .frame(minWidth: 980, minHeight: 680)

        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Assistant MCP — \(profile.displayName)"
        window.contentView = hosting
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        controllersByProfileId[profile.id] = controller

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

