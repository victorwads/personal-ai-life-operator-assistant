import Foundation

@MainActor
struct CreateEmailReplyDraftTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "create_email_reply_draft"
    let icon = "arrowshape.turn.up.left.badge.ellipsis"
    let description = "Creates a new Gmail reply draft within a thread."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "threadId": .object(["type": .string("string"), "description": .string("The Gmail thread ID of the thread to reply to.")]),
            "messageId": .object(["type": .string("string"), "description": .string("The Gmail message ID of the specific message to reply to.")]),
            "body": .object(["type": .string("string"), "description": .string("Plain text body content of the reply.")])
        ]),
        "required": .array([.string("threadId"), .string("messageId"), .string("body")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "threadId", value: .string("thread-123")),
        .init(name: "messageId", value: .string("msg-456")),
        .init(name: "body", value: .string("This is my reply."))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let threadId = try MCPSupport.string("threadId", from: call)
        let messageId = try MCPSupport.string("messageId", from: call)
        let body = try MCPSupport.string("body", from: call)

        let service = serviceProvider()
        let draft = try await service.createDraftReply(threadId: threadId, messageId: messageId, body: body)

        return .object([
            "draftId": .string(draft.draftId),
            "threadId": draft.threadId.map(MCPJSONValue.string) ?? .string(threadId)
        ])
    }
}
