import Foundation

@MainActor
struct RemoveLabelFromEmailTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "remove_label_from_email"
    let icon = "tag.slash"
    let description = "Removes a specific label (by ID) from an email message."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "messageId": .object([
                "type": .string("string"),
                "description": .string("The unique ID of the message to modify.")
            ]),
            "labelId": .object([
                "type": .string("string"),
                "description": .string("The ID of the label to remove.")
            ])
        ]),
        "required": .array([.string("messageId"), .string("labelId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "messageId", value: .string("18a14b30c5e7b23f")),
        .init(name: "labelId", value: .string("UNREAD"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let messageId = MCPSupport.optionalString("messageId", from: call), !messageId.isEmpty else {
            throw NSError(domain: "RemoveLabelFromEmailTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing messageId parameter."
            ])
        }
        guard let labelId = MCPSupport.optionalString("labelId", from: call), !labelId.isEmpty else {
            throw NSError(domain: "RemoveLabelFromEmailTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing labelId parameter."
            ])
        }

        let service = serviceProvider()
        try await service.removeLabelFromMessage(messageId: messageId, labelId: labelId)

        return .string("Successfully removed label '\(labelId)' from message \(messageId).")
    }
}
