import AppKit
import SwiftUI

@MainActor
public final class AppWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosavePrefix = "appWindowFrame."

    private let frameAutosaveName: String
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
        frameAutosaveName = Self.frameAutosaveName(for: request.id)
        self.visibilityTracker = visibilityTracker
        self.onVisibilityChange = onVisibilityChange
        self.onClose = request.onClose

        let hostingController = NSHostingController(rootView: request.rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = request.title
        window.styleMask.insert(.closable)
        window.isReleasedWhenClosed = false
        _ = window.setFrameAutosaveName(frameAutosaveName)
        let restoredFrame = window.setFrameUsingName(frameAutosaveName)
        if !restoredFrame {
            window.setContentSize(NSSize(width: request.size.width, height: request.size.height))
        }

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose?()
        saveWindowFrame(sender)
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
        if let window {
            saveWindowFrame(window)
            window.orderOut(nil)
        }
        visibilityTracker.setVisible(false, windowId: windowId)
        onVisibilityChange()
    }

    public func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        saveWindowFrame(window)
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window else { return }
        saveWindowFrame(window)
    }

    private static func frameAutosaveName(for windowId: String) -> String {
        "\(frameAutosavePrefix)\(windowId)"
    }

    private func saveWindowFrame(_ window: NSWindow) {
        window.saveFrame(usingName: frameAutosaveName)
    }
}
