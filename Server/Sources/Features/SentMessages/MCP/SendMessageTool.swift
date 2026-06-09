import Foundation

struct SendMessageTool: MCPToolDefinition {
    private let executor: SendMessageExecutor

    init(
        repository: any SentMessageRepository,
        chatRepositoryProvider: @escaping @MainActor () -> any ChatRepository,
        settings: SentMessagesSettingsWrapper,
        senderProvider: @escaping @MainActor () -> any WhatsAppMessageSending
    ) {
        self.executor = SendMessageExecutor(
            repository: repository,
            chatRepositoryProvider: chatRepositoryProvider,
            settings: settings,
            senderProvider: senderProvider
        )
    }

    let name = "send_message"
    let icon = "paperplane"
    let description = "Sends one or more outbound assistant messages. Use `chatIdentification` with either a chat ID from chat listings or a phone number containing digits only."
    let group = "sentMessages"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "chatIdentification": .object([
                "type": .string("string"),
                "description": .string("Either a chat ID returned by chat-list tools or a phone number using digits only.")
            ]),
            "messages": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ])
        ]),
        "required": .array([.string("issueId"), .string("chatIdentification"), .string("messages")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "chatIdentification", value: .string("chat-1")),
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
        let chatIdentification = try MCPSupport.string("chatIdentification", from: call)
        let messages = try SentMessageMCPToolSupport.messages(from: call)
        let outcome = try await executor.execute(
            issueId: issueId,
            chatIdentification: chatIdentification,
            messages: messages
        )
        return SentMessageMCPToolSupport.sendResultObject(outcome)
    }
}
