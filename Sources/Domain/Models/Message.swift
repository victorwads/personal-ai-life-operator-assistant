import Foundation

enum MessageDirection: String, Codable, Equatable {
    case incoming
    case outgoing
    case unknown
}

enum MessageKind: String, Codable, Equatable {
    case text
    case voice
    case image
    case document
    case deleted
    case unknown
}

enum MessageStatus: String, Codable, Equatable {
    case sent
    case delivered
    case read
    case unknown
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let direction: MessageDirection
    let kind: MessageKind
    let text: String?
    let durationSeconds: Double?
    let timestamp: Date?
    let status: MessageStatus
    let rawAccessibilityText: String
    let whatsappTimestampText: String?
    let ingestedAt: Date?
    let handledAt: Date?

    init(
        id: String,
        chatId: String,
        direction: MessageDirection,
        kind: MessageKind,
        text: String?,
        durationSeconds: Double?,
        timestamp: Date?,
        status: MessageStatus,
        rawAccessibilityText: String,
        whatsappTimestampText: String? = nil,
        ingestedAt: Date? = nil,
        handledAt: Date? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.direction = direction
        self.kind = kind
        self.text = text
        self.durationSeconds = durationSeconds
        self.timestamp = timestamp
        self.status = status
        self.rawAccessibilityText = rawAccessibilityText
        self.whatsappTimestampText = whatsappTimestampText
        self.ingestedAt = ingestedAt
        self.handledAt = handledAt
    }

    var isHandled: Bool {
        handledAt != nil
    }
}

extension Message {
    var semanticDeduplicationKey: String {
        let normalizedText = Message.normalizedDeduplicationText(text ?? rawAccessibilityText)
        let timestampKey = Message.normalizedDeduplicationText(
            whatsappTimestampText ?? timestamp.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        )

        return [
            chatId,
            direction.rawValue,
            kind.rawValue,
            normalizedText,
            timestampKey
        ].joined(separator: "|")
    }

    func replacing(
        id: String? = nil,
        text: String? = nil,
        durationSeconds: Double?? = nil,
        timestamp: Date?? = nil,
        status: MessageStatus? = nil,
        rawAccessibilityText: String? = nil,
        whatsappTimestampText: String?? = nil,
        ingestedAt: Date?? = nil,
        handledAt: Date?? = nil
    ) -> Message {
        Message(
            id: id ?? self.id,
            chatId: chatId,
            direction: direction,
            kind: kind,
            text: text ?? self.text,
            durationSeconds: durationSeconds ?? self.durationSeconds,
            timestamp: timestamp ?? self.timestamp,
            status: status ?? self.status,
            rawAccessibilityText: rawAccessibilityText ?? self.rawAccessibilityText,
            whatsappTimestampText: whatsappTimestampText ?? self.whatsappTimestampText,
            ingestedAt: ingestedAt ?? self.ingestedAt,
            handledAt: handledAt ?? self.handledAt
        )
    }

    private static func normalizedDeduplicationText(_ value: String) -> String {
        value
            .normalizedAXText
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
