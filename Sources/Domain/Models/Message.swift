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

enum MessageOrigin: String, Codable, Equatable {
    /// Sent by the MCP assistant (i.e. through `send_message`).
    case assistant
    /// Sent by a human (the user) on this machine/account.
    case human
    /// Unknown or not inferred.
    case unknown
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let direction: MessageDirection
    let kind: MessageKind
    /// Parsed sender name when available (primarily for incoming group messages).
    let authorName: String?
    /// Best-effort origin for outgoing messages (assistant vs human).
    let origin: MessageOrigin
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
        authorName: String? = nil,
        origin: MessageOrigin = .unknown,
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
        self.authorName = authorName
        self.origin = origin
        self.text = text
        self.durationSeconds = durationSeconds
        self.timestamp = timestamp
        self.status = status
        self.rawAccessibilityText = rawAccessibilityText
        self.whatsappTimestampText = whatsappTimestampText
        self.ingestedAt = ingestedAt
        self.handledAt = handledAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case chatId
        case direction
        case kind
        case authorName
        case origin
        case text
        case durationSeconds
        case timestamp
        case status
        case rawAccessibilityText
        case whatsappTimestampText
        case ingestedAt
        case handledAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        chatId = try container.decode(String.self, forKey: .chatId)
        direction = try container.decode(MessageDirection.self, forKey: .direction)
        kind = try container.decode(MessageKind.self, forKey: .kind)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        origin = (try? container.decode(MessageOrigin.self, forKey: .origin)) ?? .unknown
        text = try container.decodeIfPresent(String.self, forKey: .text)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        status = (try? container.decode(MessageStatus.self, forKey: .status)) ?? .unknown
        rawAccessibilityText = (try? container.decode(String.self, forKey: .rawAccessibilityText)) ?? ""
        whatsappTimestampText = try container.decodeIfPresent(String.self, forKey: .whatsappTimestampText)
        ingestedAt = try container.decodeIfPresent(Date.self, forKey: .ingestedAt)
        handledAt = try container.decodeIfPresent(Date.self, forKey: .handledAt)
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
        authorName: String?? = nil,
        origin: MessageOrigin? = nil,
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
            authorName: authorName ?? self.authorName,
            origin: origin ?? self.origin,
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
