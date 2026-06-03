import Foundation

@MainActor
final class WhatsAppWebViewSettingsWrapper {
    private static let scopeName = "whatsappWebView"
    private static let iso8601Formatter = ISO8601DateFormatter()

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let autoStart = "autoStart"
        static let url = "url"
        static let userAgent = "userAgent"
        static let userAgentAutoRefreshEnabled = "userAgentAutoRefreshEnabled"
        static let userAgentRefreshIntervalDays = "userAgentRefreshIntervalDays"
        static let lastUserAgentRefreshAt = "lastUserAgentRefreshAt"
        static let zoom = "zoom"
        static let viewportWidth = "viewportWidth"
        static let viewportHeight = "viewportHeight"
        static let enableWebInspector = "enableWebInspector"
        static let websiteDataStoreIdentifier = "websiteDataStoreIdentifier"
    }

    var autoStart: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.autoStart) ?? "") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.autoStart, value: newValue ? "true" : "false")
        }
    }

    var url: String {
        get {
            let value = settings.value(scope: Self.scopeName, key: Key.url) ?? ""
            return value.isEmpty ? "https://web.whatsapp.com" : value
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.url, value: newValue)
        }
    }

    var userAgent: String? {
        get {
            let trimmed = (settings.value(scope: Self.scopeName, key: Key.userAgent) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        set {
            let value = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            settings.setValue(scope: Self.scopeName, key: Key.userAgent, value: value)
        }
    }

    var userAgentAutoRefreshEnabled: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.userAgentAutoRefreshEnabled) ?? "false") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.userAgentAutoRefreshEnabled, value: newValue ? "true" : "false")
        }
    }

    var userAgentRefreshIntervalDays: Int {
        get {
            let value = Int(settings.value(scope: Self.scopeName, key: Key.userAgentRefreshIntervalDays) ?? "") ?? 7
            return max(1, value)
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.userAgentRefreshIntervalDays, value: String(max(1, newValue)))
        }
    }

    var lastUserAgentRefreshAt: String? {
        get {
            let value = (settings.value(scope: Self.scopeName, key: Key.lastUserAgentRefreshAt) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        set {
            let value = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            settings.setValue(scope: Self.scopeName, key: Key.lastUserAgentRefreshAt, value: value)
        }
    }

    var lastUserAgentRefreshDate: Date? {
        get {
            guard let raw = lastUserAgentRefreshAt else { return nil }
            return Self.iso8601Formatter.date(from: raw)
        }
        set {
            lastUserAgentRefreshAt = newValue.map { Self.iso8601Formatter.string(from: $0) }
        }
    }

    var zoom: Double {
        get {
            Double(settings.value(scope: Self.scopeName, key: Key.zoom) ?? "") ?? 1.0
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.zoom, value: String(newValue))
        }
    }

    var viewportWidth: Int {
        get {
            Int(settings.value(scope: Self.scopeName, key: Key.viewportWidth) ?? "") ?? 1080
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.viewportWidth, value: String(newValue))
        }
    }

    var viewportHeight: Int {
        get {
            Int(settings.value(scope: Self.scopeName, key: Key.viewportHeight) ?? "") ?? 1920
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.viewportHeight, value: String(newValue))
        }
    }

    var enableWebInspector: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.enableWebInspector) ?? "true") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.enableWebInspector, value: newValue ? "true" : "false")
        }
    }

    var websiteDataStoreIdentifier: String {
        let existing = (settings.value(scope: Self.scopeName, key: Key.websiteDataStoreIdentifier) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        settings.setValue(scope: Self.scopeName, key: Key.websiteDataStoreIdentifier, value: generated)
        return generated
    }
}
