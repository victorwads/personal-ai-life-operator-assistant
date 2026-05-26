import AppKit
import SwiftUI

@MainActor
public final class ProfileWindowController: NSWindowController, NSWindowDelegate {
    private let windowId: String
    private let visibilityTracker: WindowVisibilityTracker
    private let onVisibilityChange: () -> Void

    public init(
        windowId: String,
        title: String,
        rootView: AnyView,
        visibilityTracker: WindowVisibilityTracker,
        onVisibilityChange: @escaping () -> Void
    ) {
        self.windowId = windowId
        self.visibilityTracker = visibilityTracker
        self.onVisibilityChange = onVisibilityChange

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(NSSize(width: 760, height: 520))
        window.styleMask.insert(.closable)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        visibilityTracker.setVisible(false, windowId: windowId)
        onVisibilityChange()
        return false
    }

    public func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        visibilityTracker.setVisible(true, windowId: windowId)
        onVisibilityChange()
    }

    public func hide() {
        window?.orderOut(nil)
        visibilityTracker.setVisible(false, windowId: windowId)
        onVisibilityChange()
    }
}

