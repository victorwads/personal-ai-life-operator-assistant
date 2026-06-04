import AppKit
import SwiftUI

@MainActor
public final class AppWindowController: NSWindowController, NSWindowDelegate {
    private let windowId: String
    private let visibilityTracker: WindowVisibilityTracker
    private let onVisibilityChange: () -> Void
    private let onClose: (() -> Void)?

    init(
        request: AppWindowRequest,
        visibilityTracker: WindowVisibilityTracker,
        onVisibilityChange: @escaping () -> Void
    ) {
        windowId = request.id
        self.visibilityTracker = visibilityTracker
        self.onVisibilityChange = onVisibilityChange
        self.onClose = request.onClose

        let hostingController = NSHostingController(rootView: request.rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = request.title
        window.setContentSize(NSSize(width: request.size.width, height: request.size.height))
        window.styleMask.insert(.closable)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose?()
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
