import AppKit
import Foundation

@MainActor
public final class TrayIconController {
    private let statusItem: NSStatusItem
    private let menuBuilder = TrayMenuBuilder()

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let trayImage = NSImage(named: "TrayIcon")
                ?? NSImage(systemSymbolName: "circle.grid.2x2", accessibilityDescription: "AI Assistant Hub")
            trayImage?.isTemplate = true
            trayImage?.size = NSSize(width: 18, height: 18)
            button.image = trayImage
            button.imagePosition = .imageOnly
            button.toolTip = "AI Assistant Hub"
        }
    }

    public func updateMenu(
        snapshot: TrayMenuBuilder.Snapshot,
        actions: TrayMenuBuilder.Actions,
        profileActions: @escaping (ProfileDisplayState) -> TrayMenuProfileItemBuilder.Actions
    ) {
        statusItem.menu = menuBuilder.buildMenu(snapshot: snapshot, actions: actions, profileActions: profileActions)
    }

    public func remove() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
