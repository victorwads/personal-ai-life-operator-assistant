import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var whatsappRunning = false
    @Published private(set) var runtimeDescription = ""

    private let accessibility = AccessibilityService()

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        accessibilityTrusted = accessibility.isTrusted(prompt: false)
        whatsappRunning = accessibility.findWhatsAppApplication() != nil
        runtimeDescription = accessibility.currentAppIdentityDescription()

        appendLog("Accessibility trusted: \(accessibilityTrusted ? "yes" : "no")")
        appendLog("WhatsApp running: \(whatsappRunning ? "yes" : "no")")
        appendLog(runtimeDescription)
    }

    func requestAccessibilityPermission() {
        _ = accessibility.isTrusted(prompt: true)
        appendLog("Requested Accessibility permission from macOS.")
        appendLog("If permission was just enabled, relaunch this app from Xcode and press Refresh.")
        refreshStatus()
    }

    func dumpWhatsAppSnapshot() {
        // TCC can change while the app is open, so never trust only the cached UI state here.
        let trustedNow = accessibility.isTrusted(prompt: false)
        accessibilityTrusted = trustedNow

        guard trustedNow else {
            appendLog("Cannot inspect WhatsApp before Accessibility permission is granted to this exact app binary.", level: .warning)
            appendLog(accessibility.currentAppIdentityDescription(), level: .warning)
            appendLog("When running from Xcode, macOS may require granting permission to the built app in DerivedData and then relaunching it.", level: .warning)
            return
        }

        do {
            let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 5)
            appendLog("Captured WhatsApp Accessibility snapshot.")
            appendLog(snapshot)
        } catch {
            appendLog("Failed to capture WhatsApp snapshot: \(error.localizedDescription)", level: .error)
        }
    }

    private func appendLog(_ message: String, level: LogLevel = .info) {
        logs.append(LogEntry(level: level, message: message))
    }
}
