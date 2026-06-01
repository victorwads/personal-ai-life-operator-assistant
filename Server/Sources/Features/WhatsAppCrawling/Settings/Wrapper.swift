import Foundation

@MainActor
final class WhatsAppCrawlingSettingsWrapper {
    private static let scopeName = "whatsappCrawling"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let activeIntegration = "activeIntegration"
        static let pollingIntervalSeconds = "pollingIntervalSeconds"
        static let chatPermissionMode = "chatPermissionMode"
        static let legacyAccessPolicy = "accessPolicy"
        static let autoStart = "autoStart"
    }

    var activeIntegration: WhatsAppCrawlingActiveIntegration {
        get {
            let raw = settings.value(scope: Self.scopeName, key: Key.activeIntegration) ?? ""
            return WhatsAppCrawlingActiveIntegration(rawValue: raw) ?? .webView
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.activeIntegration, value: newValue.rawValue)
        }
    }

    var pollingIntervalSeconds: Int {
        get {
            Int(settings.value(scope: Self.scopeName, key: Key.pollingIntervalSeconds) ?? "") ?? 5
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.pollingIntervalSeconds, value: String(newValue))
        }
    }

    var chatPermissionMode: ChatPermissionMode {
        get {
            let raw = settings.value(scope: Self.scopeName, key: Key.chatPermissionMode)
                ?? settings.value(scope: Self.scopeName, key: Key.legacyAccessPolicy)
                ?? ""
            switch raw {
            case ChatPermissionMode.allowAllExceptDenied.rawValue, "allowAllExceptDenyList":
                return .allowAllExceptDenied
            case ChatPermissionMode.denyAllExceptAllowed.rawValue, "denyAllExceptAllowList":
                return .denyAllExceptAllowed
            default:
                return .allowAllExceptDenied
            }
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.chatPermissionMode, value: newValue.rawValue)
        }
    }

    var autoStart: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.autoStart) ?? "") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.autoStart, value: newValue ? "true" : "false")
        }
    }
}
