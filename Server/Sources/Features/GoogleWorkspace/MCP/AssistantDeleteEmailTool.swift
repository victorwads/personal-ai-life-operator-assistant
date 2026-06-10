import Foundation

@MainActor
struct AssistantDeleteEmailTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "assistant_delete_email"
    let icon = "trash.slash"
    let description = "Safely deletes an email by moving it to the 'Assistant/Deleted' label instead of permanently purging it or using the Trash folder."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "messageId": .object([
                "type": .string("string"),
                "description": .string("The unique ID of the message to delete.")
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
            throw NSError(domain: "AssistantDeleteEmailTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing messageId parameter."
            ])
        }

        let service = serviceProvider()
        let result = try await service.assistantDeleteEmail(messageId: messageId)

        return .string(result)
    }
}
