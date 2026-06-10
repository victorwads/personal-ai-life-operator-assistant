import Foundation

@MainActor
struct MarkEmailAsUnreadTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "mark_email_as_unread"
    let icon = "envelope.badge"
    let description = "Marks a specific email message as unread by adding the 'UNREAD' label."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "messageId": .object([
                "type": .string("string"),
                "description": .string("The unique ID of the message to mark as unread.")
            ])
        ]),
        "required": .array([.string("messageId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "messageId", value: .string("18a14b30c5e7b23f"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let messageId = MCPSupport.optionalString("messageId", from: call), !messageId.isEmpty else {
            throw NSError(domain: "MarkEmailAsUnreadTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing messageId parameter."
            ])
        }

        let service = serviceProvider()
        try await service.markEmailAsUnread(messageId: messageId)

        return .string("Successfully marked message \(messageId) as unread.")
    }
}
