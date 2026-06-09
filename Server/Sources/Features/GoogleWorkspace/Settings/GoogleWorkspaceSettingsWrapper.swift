import Foundation

@MainActor
final class GoogleWorkspaceSettingsWrapper {
    private static let scopeName = "googleWorkspace"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let clientId = "clientId"
        static let clientSecret = "clientSecret"
        static let redirectPort = "redirectPort"
    }

    var clientId: String {
        get { settings.value(scope: Self.scopeName, key: Key.clientId) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.clientId, value: newValue) }
    }

    var clientSecret: String {
        get { settings.value(scope: Self.scopeName, key: Key.clientSecret) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.clientSecret, value: newValue) }
    }

    var redirectPort: Int {
        get {
            if let val = settings.value(scope: Self.scopeName, key: Key.redirectPort), let port = Int(val) {
                return port
            }
            return 8089
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.redirectPort, value: String(newValue))
        }
    }

    var enabledScopes: [String] {
        [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/calendar.readonly",
            "https://www.googleapis.com/auth/contacts.readonly"
        ]
    }

    static func parseCredentials(from data: Data) throws -> (clientId: String, clientSecret: String) {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var clientInfo: [String: Any]? = nil
        if let installed = json?["installed"] as? [String: Any] {
            clientInfo = installed
        } else if let web = json?["web"] as? [String: Any] {
            clientInfo = web
        }
        
        guard let info = clientInfo,
              let id = info["client_id"] as? String,
              let secret = info["client_secret"] as? String else {
            throw NSError(domain: "GoogleWorkspaceSettings", code: 301, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Google OAuth credentials JSON format."
            ])
        }
        return (id, secret)
    }
}
