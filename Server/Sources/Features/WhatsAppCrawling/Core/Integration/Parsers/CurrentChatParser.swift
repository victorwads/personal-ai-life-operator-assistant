import Foundation

// TODO: Replace the current ChatHeaderParser + MessageListParser split with a
// CurrentChatParser that returns a CrawledChatSnapshot for the selected chat.
protocol CurrentChatParser: CrawlingParser where Output == CrawledChatSnapshot {}

struct ParsedCurrentChat: Sendable {
    let chatId: String
    let chatTitle: String
    let messages: [ChatMessage]
}

enum WhatsAppCurrentChatParser {
    static func parse(from rootObject: [String: Any], referenceDate: Date = .init()) -> ParsedCurrentChat? {
        guard
            let web = rootObject["web"] as? [String: Any],
            let currentChat = web["currentChat"] as? [String: Any]
        else {
            return nil
        }

        let title = WhatsAppCrawlingNormalizer.normalizeChatTitle(currentChat["chatTitle"] as? String)
        let chatId = WhatsAppCrawlingNormalizer.makeWhatsAppChatId(title: title)
        let rawMessages = currentChat["chatMessages"] as? [Any] ?? []

        let messages: [ChatMessage] = rawMessages.enumerated().compactMap { index, raw in
            guard let rawObject = raw as? [String: Any] else { return nil }
            guard let messageId = WhatsAppCrawlingNormalizer.makeWhatsAppMessageId(messageId: rawObject["messageId"] as? String) else {
                return nil
            }

            let rawDateTimeAndAuthor = WhatsAppCrawlingNormalizer.normalizeText(rawObject["messageDatetimeAndAuthor"] as? String)
            let author = WhatsAppCrawlingNormalizer.normalizeAuthor(
                messageAuthor: rawObject["messageAuthor"] as? String,
                messageDateTimeAndAuthor: rawDateTimeAndAuthor
            )
            let parsedDateTime = WhatsAppCrawlingNormalizer.normalizeMessageDateTime(
                messageDateTimeAndAuthor: rawDateTimeAndAuthor,
                messageTime: rawObject["messageTime"] as? String,
                referenceDate: referenceDate
            )
            let direction = detectDirection(
                rawObject: rawObject
            )

            return ChatMessage(
                id: messageId,
                chatId: chatId,
                author: author,
                text: WhatsAppCrawlingNormalizer.normalizeText(rawObject["messageText"] as? String),
                kind: WhatsAppCrawlingNormalizer.detectMessageKind(rawMessage: rawObject),
                direction: direction,
                listOrder: index,
                dateTime: parsedDateTime,
                quotedMessageText: WhatsAppCrawlingNormalizer.normalizeText(rawObject["quotedMessageText"] as? String),
                quotedMessageAuthor: WhatsAppCrawlingNormalizer.normalizeText(rawObject["quotedMessageAuthor"] as? String)
            )
        }

        return ParsedCurrentChat(chatId: chatId, chatTitle: title, messages: messages)
    }

    private static func detectDirection(
        rawObject: [String: Any]
    ) -> ChatMessage.Direction {
        if let sent = rawObject["sent"] as? Bool {
            return sent ? .sent : .received
        }
        return .received
    }
}
