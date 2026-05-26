import AppKit
import Foundation

@MainActor
public final class TrayMenuBuilder {
    public struct Snapshot: Sendable {
        public enum Phase: Sendable, Equatable {
            case booting
            case unauthenticated
            case authenticated
            case failed(message: String)
        }

        public let profiles: [ProfileDisplayState]
        public let phase: Phase
    }

    public struct Actions {
        public let openDefaultWindow: () -> Void
        public let signOut: (() -> Void)?
        public let quit: () -> Void

        public init(openProfiles: @escaping () -> Void, signOut: (() -> Void)?, quit: @escaping () -> Void) {
            self.openDefaultWindow = openProfiles
            self.signOut = signOut
            self.quit = quit
        }
    }

    private let profileItemBuilder = TrayMenuProfileItemBuilder()

    public init() {}

    public func buildMenu(snapshot: Snapshot, actions: Actions, profileActions: (ProfileDisplayState) -> TrayMenuProfileItemBuilder.Actions) -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "AI Assistant Hub", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        switch snapshot.phase {
        case .booting:
            let starting = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
            starting.isEnabled = false
            menu.addItem(starting)
        case .unauthenticated:
            menu.addItem(actionItem(title: "Open Login Window", action: actions.openDefaultWindow))
        case .failed(let message):
            let failed = NSMenuItem(title: "Authentication Failed", action: nil, keyEquivalent: "")
            failed.isEnabled = false
            menu.addItem(failed)

            if !message.isEmpty {
                let messageItem = NSMenuItem(title: message, action: nil, keyEquivalent: "")
                messageItem.isEnabled = false
                menu.addItem(messageItem)
            }

            menu.addItem(actionItem(title: "Open Login Window", action: actions.openDefaultWindow))
        case .authenticated:
            menu.addItem(actionItem(title: "Open Profiles Window", action: actions.openDefaultWindow))
            menu.addItem(NSMenuItem.separator())

            if snapshot.profiles.isEmpty {
                let none = NSMenuItem(title: "No profiles", action: nil, keyEquivalent: "")
                none.isEnabled = false
                menu.addItem(none)
            } else {
                for displayState in snapshot.profiles {
                    let actionsForProfile = profileActions(displayState)
                    menu.addItem(profileItemBuilder.buildProfileSubmenu(displayState: displayState, actions: actionsForProfile))
                }
            }

            if let signOut = actions.signOut {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(actionItem(title: "Sign Out", action: signOut))
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(title: "Quit", action: actions.quit))

        return menu
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
