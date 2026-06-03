import Foundation

enum WhatsAppCrawlingNormalizer {
    static func normalizeText(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func normalizeChatTitle(_ title: String?) -> String {
        normalizeText(title) ?? "Untitled"
    }

    static func makeWhatsAppChatId(title: String?) -> String {
        let normalizedTitle = normalizeChatTitle(title)
        let hash = stableHash(normalizedTitle)
        return "whatsapp-\(hash)"
    }

    static func makeWhatsAppMessageId(messageId: String?) -> String? {
        guard let messageId = normalizeText(messageId) else { return nil }
        return "whatsapp-\(messageId)"
    }

    static func makeChatStateHash(
        title: String,
        lastMessagePreview: String?,
        lastMessageTimeText: String?,
        unreadCount: Int
    ) -> String {
        let payload = [
            normalizeChatTitle(title),
            normalizeText(lastMessagePreview) ?? "",
            normalizeText(lastMessageTimeText) ?? "",
            String(unreadCount)
        ].joined(separator: "|")
        return stableHash(payload)
    }

    static func normalizeAuthor(messageAuthor: String?, messageDateTimeAndAuthor: String?) -> String? {
        if let explicit = normalizeText(messageAuthor) {
            return explicit
        }
        return parseAuthor(fromDateTimeAndAuthor: messageDateTimeAndAuthor)
    }

    static func normalizeMessageDateTime(
        messageDateTimeAndAuthor: String?,
        messageTime: String?,
        referenceDate: Date
    ) -> Date? {
        if let fullDateTime = parseDateTime(fromMessageDateTimeAndAuthor: messageDateTimeAndAuthor) {
            return fullDateTime
        }
        _ = messageTime
        _ = referenceDate
        return nil
    }

    static func detectMessageKind(rawMessage: [String: Any]) -> ChatMessage.Kind {
        if WebViewInteractiveElementDetector.from(rawMessage["image"] as Any) != nil {
            return .image
        }
        if WebViewInteractiveElementDetector.from(rawMessage["sticker"] as Any) != nil {
            return .sticker
        }
        if let isAudio = rawMessage["isAudio"] as? Bool, isAudio {
            return .audio
        }
        if normalizeText(rawMessage["messageText"] as? String) != nil {
            return .text
        }
        return .unknown
    }

    private static func parseAuthor(fromDateTimeAndAuthor raw: String?) -> String? {
        guard let raw = normalizeText(raw) else { return nil }
        guard let closeBracket = raw.firstIndex(of: "]") else { return nil }
        let remainder = raw[raw.index(after: closeBracket)...].trimmingCharacters(in: .whitespaces)
        guard let colon = remainder.lastIndex(of: ":") else { return nil }
        let author = remainder[..<colon].trimmingCharacters(in: .whitespaces)
        return author.isEmpty ? nil : String(author)
    }

    private static func parseDateTime(fromMessageDateTimeAndAuthor raw: String?) -> Date? {
        guard let raw = normalizeText(raw) else { return nil }
        guard let open = raw.firstIndex(of: "["), let close = raw.firstIndex(of: "]"), open < close else { return nil }
        let content = String(raw[raw.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.date(from: content)
    }

    private static func stableHash(_ text: String) -> String {
        let data = Array(text.utf8)
        var hash: UInt64 = 1469598103934665603
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
    }
}
