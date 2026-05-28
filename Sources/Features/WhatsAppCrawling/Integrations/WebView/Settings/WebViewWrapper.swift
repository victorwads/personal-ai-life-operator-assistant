import Foundation

@MainActor
final class WhatsAppWebViewSettingsWrapper {
    private static let scopeName = "whatsappWebView"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let url = "url"
        static let userAgent = "userAgent"
        static let zoom = "zoom"
        static let viewportWidth = "viewportWidth"
        static let viewportHeight = "viewportHeight"
        static let enableWebInspector = "enableWebInspector"
        static let websiteDataStoreIdentifier = "websiteDataStoreIdentifier"
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
            Int(settings.value(scope: Self.scopeName, key: Key.viewportWidth) ?? "") ?? 1280
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.viewportWidth, value: String(newValue))
        }
    }

    var viewportHeight: Int {
        get {
            Int(settings.value(scope: Self.scopeName, key: Key.viewportHeight) ?? "") ?? 720
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
