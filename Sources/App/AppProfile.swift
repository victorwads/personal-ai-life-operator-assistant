import Foundation

struct AppProfile: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let isDefault: Bool

    static let `default` = AppProfile(
        id: "default",
        displayName: "Default",
        isDefault: true
    )

    static func defaultNamed(_ name: String) -> AppProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppProfile(
            id: "default",
            displayName: trimmed.isEmpty ? "Default" : trimmed,
            isDefault: true
        )
    }

    static func forWhatsAppWebAccount(_ account: WhatsAppWebAccount, isDefault: Bool) -> AppProfile {
        if isDefault {
            return .default
        }
        return AppProfile(
            id: "waweb-\(account.id.uuidString)",
            displayName: account.name,
            isDefault: false
        )
    }
}
