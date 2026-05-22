import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        FirebaseBootstrap.shared.configure()
        configureStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        guard ProfileWindowManager.shared.isHomeWindowVisible else {
            return false
        }

        ProfileWindowManager.shared.showHomeWindow()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateStatusMenu(menu)
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(named: "TrayIcon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Assistant MCP")
        }
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Assistant MCP"

        let menu = NSMenu()
        menu.delegate = self
        let toggleItem = NSMenuItem(title: "Show Profiles Window", action: #selector(toggleProfilesWindow), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let showAllItem = NSMenuItem(title: "Show All Managed Windows", action: #selector(showAllManagedWindows), keyEquivalent: "")
        showAllItem.target = self
        menu.addItem(showAllItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Assistant MCP", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
        updateStatusMenu(menu)
    }

    private func updateStatusMenu(_ menu: NSMenu) {
        guard let firstItem = menu.items.first else { return }
        firstItem.title = ProfileWindowManager.shared.isHomeWindowVisible ? "Hide Profiles Window" : "Show Profiles Window"
    }

    @objc
    private func toggleProfilesWindow() {
        if ProfileWindowManager.shared.isHomeWindowVisible {
            ProfileWindowManager.shared.hideHomeWindow()
        } else {
            ProfileWindowManager.shared.showHomeWindow()
        }
    }

    @objc
    private func showAllManagedWindows() {
        ProfileWindowManager.shared.showAllManagedWindows()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
