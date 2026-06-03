import Foundation

enum SentMessageFormatter {
    static func format(
        rawMessages: [String],
        prefix: String,
        postfix: String,
        header: String,
        footer: String
    ) -> [String] {
        let bodyMessages = rawMessages
            .compactMap(\.trimmedNonEmpty)
            .map { "\(prefix)\($0)\(postfix)" }

        var messages: [String] = []
        if let header = header.trimmedNonEmpty {
            messages.append(header)
        }
        messages.append(contentsOf: bodyMessages)
        if let footer = footer.trimmedNonEmpty {
            messages.append(footer)
        }
        return messages
    }
}
