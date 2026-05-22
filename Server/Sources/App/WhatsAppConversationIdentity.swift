import Foundation

enum WhatsAppConversationIdentity {
    static func canonicalChatId(for chatName: String?) -> String {
        let title = chatName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = chatNameComparisonKey(for: title)
        return stableId(for: key.isEmpty ? title : key)
    }

    private static func chatNameComparisonKey(for value: String) -> String {
        let normalized = value
            .normalizedAXText
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        return normalized
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func stableId(for value: String) -> String {
        let scalars = value.unicodeScalars.map(\.value)
        let hash = scalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
        return String(hash, radix: 16)
    }
}
