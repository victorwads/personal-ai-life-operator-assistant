import AppKit
import Foundation

@MainActor
public final class DockVisibilityController {
    public init() {}

    public func setDockVisible(_ visible: Bool) {
        let desired: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        if NSApp.activationPolicy() != desired {
            NSApp.setActivationPolicy(desired)
        }
    }
}

