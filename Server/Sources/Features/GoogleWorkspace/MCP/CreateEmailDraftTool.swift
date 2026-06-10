import Foundation

@MainActor
struct CreateEmailDraftTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "create_email_draft"
    let icon = "envelope.badge.plus"
    let description = "Creates a new Gmail draft without sending it."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "to": .object(["type": .string("string"), "description": .string("Recipient email address.")]),
            "cc": .object(["type": .string("string"), "description": .string("Optional CC recipient email address.")]),
            "bcc": .object(["type": .string("string"), "description": .string("Optional BCC recipient email address.")]),
            "subject": .object(["type": .string("string"), "description": .string("Subject of the email.")]),
            "body": .object(["type": .string("string"), "description": .string("Plain text body content.")])
        ]),
        "required": .array([.string("to"), .string("subject"), .string("body")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "to", value: .string("recipient@example.com")),
        .init(name: "subject", value: .string("Hello")),
        .init(name: "body", value: .string("World"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let to = try MCPSupport.string("to", from: call)
        let cc = MCPSupport.optionalString("cc", from: call)
        let bcc = MCPSupport.optionalString("bcc", from: call)
        let subject = try MCPSupport.string("subject", from: call)
        let body = try MCPSupport.string("body", from: call)

        let service = serviceProvider()
        let draft = try await service.createDraftEmail(to: to, cc: cc, bcc: bcc, subject: subject, body: body)

        return .object([
            "draftId": .string(draft.draftId),
            "threadId": draft.threadId.map(MCPJSONValue.string) ?? .null,
            "subject": .string(draft.subject),
            "recipients": .object([
                "to": .string(draft.to),
                "cc": draft.cc.map(MCPJSONValue.string) ?? .null,
                "bcc": draft.bcc.map(MCPJSONValue.string) ?? .null
            ])
        ])
    }
}
