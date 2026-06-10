import Foundation

@MainActor
struct AddLabelToEmailTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "add_label_to_email"
    let icon = "tag.fill"
    let description = "Applies an existing label (by ID) to a specific email message."
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
                "description": .string("The ID of the label to apply (e.g. 'UNREAD', 'INBOX', or a custom label ID).")
            ])
        ]),
        "required": .array([.string("messageId"), .string("labelId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "messageId", value: .string("18a14b30c5e7b23f")),
        .init(name: "labelId", value: .string("Label_3"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let messageId = MCPSupport.optionalString("messageId", from: call), !messageId.isEmpty else {
            throw NSError(domain: "AddLabelToEmailTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing messageId parameter."
            ])
        }
        guard let labelId = MCPSupport.optionalString("labelId", from: call), !labelId.isEmpty else {
            throw NSError(domain: "AddLabelToEmailTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing labelId parameter."
            ])
        }

        let service = serviceProvider()
        try await service.addLabelToMessage(messageId: messageId, labelId: labelId)

        return .string("Successfully added label '\(labelId)' to message \(messageId).")
    }
}
