import Foundation

@MainActor
final class SentMessagesSettingsWrapper {
    private static let scopeName = "sentMessages"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let assistantName = "assistantName"
        static let messagePrefix = "messagePrefix"
        static let messagePostfix = "messagePostfix"
        static let messageHeader = "messageHeader"
        static let messageFooter = "messageFooter"
    }

    var assistantName: String {
        get {
            let value = settings.value(scope: Self.scopeName, key: Key.assistantName) ?? ""
            return value.trimmedNonEmpty ?? "Assistant"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.assistantName, value: newValue)
        }
    }

    var messagePrefix: String {
        get { settings.value(scope: Self.scopeName, key: Key.messagePrefix) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.messagePrefix, value: newValue) }
    }

    var messagePostfix: String {
        get { settings.value(scope: Self.scopeName, key: Key.messagePostfix) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.messagePostfix, value: newValue) }
    }

    var messageHeader: String {
        get { settings.value(scope: Self.scopeName, key: Key.messageHeader) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.messageHeader, value: newValue) }
    }

    var messageFooter: String {
        get { settings.value(scope: Self.scopeName, key: Key.messageFooter) ?? "" }
        set { settings.setValue(scope: Self.scopeName, key: Key.messageFooter, value: newValue) }
    }
}
