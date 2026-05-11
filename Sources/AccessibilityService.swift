import AppKit
import ApplicationServices

final class AccessibilityService {
    func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func currentAppIdentityDescription() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown bundle id"
        let executablePath = Bundle.main.executableURL?.path ?? "unknown executable path"
        let bundlePath = Bundle.main.bundleURL.path

        return """
        Current app identity:
          bundle id: \(bundleIdentifier)
          bundle path: \(bundlePath)
          executable: \(executablePath)
        """
    }

    func findWhatsAppApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.bundleIdentifier == "net.whatsapp.WhatsApp"
        }
    }

    func captureWhatsAppSnapshot(maxDepth: Int) throws -> String {
        guard let app = findWhatsAppApplication() else {
            throw AccessibilityError.whatsAppNotRunning
        }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        return describe(element: element, depth: 0, maxDepth: maxDepth)
    }

    private func describe(element: AXUIElement, depth: Int, maxDepth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        var parts: [String] = []

        if let role: String = value(element, attribute: kAXRoleAttribute) {
            parts.append("role=\(role)")
        }
        if let title: String = value(element, attribute: kAXTitleAttribute), !title.isEmpty {
            parts.append("title=\(title)")
        }
        if let description: String = value(element, attribute: kAXDescriptionAttribute), !description.isEmpty {
            parts.append("description=\(description)")
        }
        if let value: String = value(element, attribute: kAXValueAttribute), !value.isEmpty {
            parts.append("value=\(value)")
        }

        var output = "\(indent)- \(parts.joined(separator: ", "))\n"

        guard depth < maxDepth else {
            return output
        }

        let children: [AXUIElement]? = value(element, attribute: kAXChildrenAttribute)
        for child in children ?? [] {
            output += describe(element: child, depth: depth + 1, maxDepth: maxDepth)
        }

        return output
    }

    private func value<T>(_ element: AXUIElement, attribute: String) -> T? {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &raw)
        guard result == .success else { return nil }
        return raw as? T
    }
}

enum AccessibilityError: LocalizedError {
    case whatsAppNotRunning

    var errorDescription: String? {
        switch self {
        case .whatsAppNotRunning:
            return "WhatsApp is not running."
        }
    }
}
