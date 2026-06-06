import Foundation

struct MarkChatMessagesAsHandledTool: MCPToolDefinition {
    private let repository: any ChatRepository

    init(repository: any ChatRepository) {
        self.repository = repository
    }

    let name = "mark_chat_messages_as_handled"
    let icon = "checkmark.circle"
    let description = "Marks chat messages as handled using a read receipt."
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "readReceipt": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("issueId"),
            .string("readReceipt")
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "readReceipt", value: .string("Y2hhdC1pZHxsYXN0LW1lc3NhZ2UtaWQ="))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !issueId.isEmpty else {
            throw MCPServerError.invalidArguments("`issueId` must not be empty.")
        }

        let readReceiptToken = try MCPSupport.string("readReceipt", from: call)

        let readReceipt: ChatMessagesReadReceipt
        do {
            readReceipt = try ChatMessagesReadReceiptCoder.decode(readReceiptToken)
        } catch {
            throw MCPServerError.invalidArguments(error.localizedDescription)
        }

        let changedCount: Int
        do {
            changedCount = try await repository.markMessagesHandledThrough(
                chatId: readReceipt.chatId,
                lastChatMessageId: readReceipt.lastChatMessageId
            )
        } catch {
            throw MCPServerError.invalidArguments(error.localizedDescription)
        }

        if changedCount == 0 {
            return .string("No chat messages were marked as handled.")
        }

        return .string("Marked \(changedCount) chat messages as handled for issue \(issueId).")
    }
}
