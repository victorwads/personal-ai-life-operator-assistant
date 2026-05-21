import Foundation

@MainActor
final class ConversationAccessRepository {
    static let shared = ConversationAccessRepository()

    private let defaults: UserDefaults

    private let conversationAccessModeDefaultsKey = "conversationAccessMode.v1"
    private let denyConversationNamesDefaultsKey = "denyConversationNames.v1"
    private let allowConversationNamesDefaultsKey = "allowConversationNames.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (mode: ConversationAccessMode, deny: [String], allow: [String]) {
        let mode: ConversationAccessMode = {
            if let raw = defaults.string(forKey: conversationAccessModeDefaultsKey),
               let decoded = ConversationAccessMode(rawValue: raw) {
                return decoded
            }
            return .allowAllExceptDeny
        }()

        let deny: [String] = {
            if let deny = defaults.stringArray(forKey: denyConversationNamesDefaultsKey) {
                return deny.sorted()
            }

            return []
        }()

        let allow = (defaults.stringArray(forKey: allowConversationNamesDefaultsKey) ?? []).sorted()
        return (mode: mode, deny: deny, allow: allow)
    }

    func save(mode: ConversationAccessMode, deny: [String], allow: [String]) {
        defaults.set(mode.rawValue, forKey: conversationAccessModeDefaultsKey)
        defaults.set(deny, forKey: denyConversationNamesDefaultsKey)
        defaults.set(allow, forKey: allowConversationNamesDefaultsKey)
    }
}
