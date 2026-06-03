import Foundation

struct SendMessageTool: MCPToolDefinition {
    private let executor: SendMessageExecutor

    init(
        repository: FirestoreSentMessageRepository,
        settings: SentMessagesSettingsWrapper,
        senderProvider: @escaping @MainActor () -> any WhatsAppMessageSending
    ) {
        self.executor = SendMessageExecutor(
            repository: repository,
            settings: settings,
            senderProvider: senderProvider
        )
    }

    let name = "send_message"
    let icon = "paperplane"
    let description = "Sends one or more outbound assistant messages, records a pending audit entry first, and updates the audit status from observed WhatsApp send receipts."
    let group = "sentMessages"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "chatId": .object(["type": .string("string")]),
            "messages": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ])
        ]),
        "required": .array([.string("issueId"), .string("chatId"), .string("messages")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "chatId", value: .string("chat-1")),
        .init(name: "messages", value: .array([
            .string("Testing send_message from the tools browser."),
            .string("Another batch message")
        ]))
    ]
    let traits: [MCPToolTrait] = [.writesState, .sideEffect]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let chatId = try MCPSupport.string("chatId", from: call)
        let messages = try SentMessageMCPToolSupport.messages(from: call)
        let outcome = try await executor.execute(
            issueId: issueId,
            chatId: chatId,
            messages: messages
        )
        return SentMessageMCPToolSupport.sendResultObject(outcome)
    }
}
