import Foundation

struct ChatMessagesReadReceipt: Equatable, Sendable {
    let chatId: String
    let lastChatMessageId: String
}

enum ChatMessagesReadReceiptCoder {
    static func encode(chatId: String, lastChatMessageId: String) throws -> String {
        guard !chatId.isEmpty, !lastChatMessageId.isEmpty else {
            throw ChatMessagesReadReceiptCoderError.invalidComponents
        }

        let payload = "\(chatId)|\(lastChatMessageId)"
        return Data(payload.utf8).base64EncodedString()
    }

    static func decode(_ token: String) throws -> ChatMessagesReadReceipt {
        guard let data = Data(base64Encoded: token),
              let decoded = String(data: data, encoding: .utf8) else {
            throw ChatMessagesReadReceiptCoderError.invalidToken
        }

        let parts = decoded.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
            throw ChatMessagesReadReceiptCoderError.invalidToken
        }

        return ChatMessagesReadReceipt(chatId: parts[0], lastChatMessageId: parts[1])
    }
}

private enum ChatMessagesReadReceiptCoderError: LocalizedError {
    case invalidComponents
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .invalidComponents:
            return "Chat read receipt components must not be empty."
        case .invalidToken:
            return "Invalid chat read receipt token. Expected a base64-encoded 'chatId|lastChatMessageId' string."
        }
    }
}
