import AppKit
import Foundation

@MainActor
public final class TrayMenuProfileItemBuilder {
    public struct Actions {
        public let start: (String) -> Void
        public let stop: (String) -> Void
        public let showWindow: (String) -> Void
        public let hideWindow: (String) -> Void
        public let toggleAutoStart: (String) -> Void

        public init(
            start: @escaping (String) -> Void,
            stop: @escaping (String) -> Void,
            showWindow: @escaping (String) -> Void,
            hideWindow: @escaping (String) -> Void,
            toggleAutoStart: @escaping (String) -> Void
        ) {
            self.start = start
            self.stop = stop
            self.showWindow = showWindow
            self.hideWindow = hideWindow
            self.toggleAutoStart = toggleAutoStart
        }
    }

    public init() {}

    public func buildProfileSubmenu(displayState: ProfileDisplayState, actions: Actions) -> NSMenuItem {
        let item = NSMenuItem(title: displayState.profile.name, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let statusLine = NSMenuItem(
            title: "Status: \(displayState.runtimeState.rawValue) | Window: \(displayState.windowState.rawValue)",
            action: nil,
            keyEquivalent: ""
        )
        statusLine.isEnabled = false
        submenu.addItem(statusLine)

        submenu.addItem(NSMenuItem.separator())

        let profileId = displayState.profile.id ?? ""

        if displayState.runtimeState == .running || displayState.runtimeState == .starting {
            submenu.addItem(actionItem(title: "Stop") { actions.stop(profileId) })
        } else {
            submenu.addItem(actionItem(title: "Start") { actions.start(profileId) })
        }

        if displayState.runtimeState == .running {
            if displayState.windowState == .visible {
                submenu.addItem(actionItem(title: "Hide Window") { actions.hideWindow(profileId) })
            } else {
                submenu.addItem(actionItem(title: "Show Window") { actions.showWindow(profileId) })
            }
        }

        submenu.addItem(NSMenuItem.separator())

        let autoStartTitle = displayState.profile.autoStart ? "Disable Auto Start" : "Enable Auto Start"
        submenu.addItem(actionItem(title: autoStartTitle) { actions.toggleAutoStart(profileId) })

        submenu.addItem(NSMenuItem.separator())

        let diagnostics = NSMenuItem(
            title: "Port: \(displayState.profile.mcpPort) | ID: \(displayState.profile.id ?? "(unsaved)")",
            action: nil,
            keyEquivalent: ""
        )
        diagnostics.isEnabled = false
        submenu.addItem(diagnostics)

        item.submenu = submenu
        return item
    }

    private func actionItem(title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, actionHandler: action)
        item.target = item
        item.action = #selector(CallbackMenuItem.performAction)
        return item
    }
}

@MainActor
private final class CallbackMenuItem: NSMenuItem {
    private let actionHandler: () -> Void

    init(title: String, actionHandler: @escaping () -> Void) {
        self.actionHandler = actionHandler
        super.init(title: title, action: nil, keyEquivalent: "")
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func performAction() {
        actionHandler()
    }
}
