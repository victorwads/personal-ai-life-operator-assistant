import Foundation

enum SentMessageMCPToolSupport {
    static func messages(from call: MCPToolCall) throws -> [String] {
        // TODO: Move array item validation to centralized MCP validators when nested
        // schema validation supports `items`. Until then, keep this extraction guard
        // to ensure `messages` contains at least one non-empty string.
        guard case .array(let values)? = call.arguments["messages"] else {
            throw MCPToolExtractionError.invalidField(
                "messages",
                reason: "expected an array containing only non-empty strings."
            )
        }

        let messages = try values
            // ignore empty strings
            .filter({ message in
                message.stringValue?.trimmedNonEmpty != nil
            })
            .map { value in
            guard let text = value.stringValue?.trimmedNonEmpty else {
                throw MCPToolExtractionError.invalidField(
                    "messages",
                    reason: "each item must be a non-empty string. just remove ONLY the empty items."
                )
            }
            return text
        }

        guard !messages.isEmpty else {
            throw SendMessageMCPToolError.emptyMessages
        }

        return messages
    }

    static func sentMessageObject(_ sentMessage: SentMessage) -> MCPJSONValue {
        .object([
            "id": sentMessage.id.map(MCPJSONValue.string) ?? .null,
            "issueId": .string(sentMessage.issueId),
            "chatId": .string(sentMessage.chatId),
            "chatTitle": sentMessage.chatTitle.map(MCPJSONValue.string) ?? .null,
            "messages": .array(sentMessage.messages.map(MCPJSONValue.string)),
            "status": .string(sentMessage.status.rawValue),
            "chatMessageIds": .array(sentMessage.chatMessageIds.map(MCPJSONValue.string)),
            "errorMessage": sentMessage.errorMessage.map(MCPJSONValue.string) ?? .null,
            "sentAt": sentMessage.sentAt.map { .string(ISO8601DateFormatter().string(from: $0)) } ?? .null
        ])
    }

    static func sendResultObject(_ outcome: SentMessageSendOutcome) -> MCPJSONValue {
        .object([
            "sentMessage": sentMessageObject(outcome.sentMessage),
            "sentMessageId": outcome.sentMessage.id.map(MCPJSONValue.string) ?? .null,
            "status": .string(outcome.sentMessage.status.rawValue),
            "issueId": .string(outcome.sentMessage.issueId),
            "chatId": .string(outcome.sentMessage.chatId),
            "chatMessageIds": .array(outcome.sentMessage.chatMessageIds.map(MCPJSONValue.string)),
            "receiptCount": .int(outcome.receiptCount),
            "missingReceiptCount": .int(outcome.missingReceiptCount)
        ])
    }
}

enum SendMessageMCPToolError: Error, MCPServerErrorProviding {
    case emptyMessages

    var serverError: MCPServerError {
        switch self {
        case .emptyMessages:
            return .invalidArguments("`messages` must contain at least one non-empty string.")
        }
    }
}
