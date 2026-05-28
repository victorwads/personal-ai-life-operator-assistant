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
        static let accessPolicy = "accessPolicy"
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

    var accessPolicy: WhatsAppCrawlingAccessPolicy {
        get {
            let raw = settings.value(scope: Self.scopeName, key: Key.accessPolicy) ?? ""
            return WhatsAppCrawlingAccessPolicy(rawValue: raw) ?? .allowAllExceptDenyList
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.accessPolicy, value: newValue.rawValue)
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
