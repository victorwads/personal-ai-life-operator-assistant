import Foundation

enum WhatsAppWebAccountsBootstrap {
    static func peekAccounts() -> [WhatsAppWebAccount] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "whatsappWebAccounts.v1") else {
            return []
        }
        return (try? JSONDecoder().decode([WhatsAppWebAccount].self, from: data)) ?? []
    }

    static func peekFirstAccountId() -> UUID? {
        peekAccounts().sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }.first?.id
    }
}

