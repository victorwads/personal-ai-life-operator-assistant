import Foundation

@MainActor
struct CreateGmailLabelTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "create_gmail_label"
    let icon = "tag.badge.plus"
    let description = "Creates a new Gmail label with the specified name."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "name": .object([
                "type": .string("string"),
                "description": .string("The name of the label to create (e.g. 'ProjectX', 'Assistant/Deleted').")
            ])
        ]),
        "required": .array([.string("name")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "name", value: .string("Assistant/Deleted"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let name = MCPSupport.optionalString("name", from: call), !name.isEmpty else {
            throw NSError(domain: "CreateGmailLabelTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing name parameter."
            ])
        }

        let service = serviceProvider()
        let label = try await service.createLabel(name: name)

        return .string("Successfully created label '\(label.name)' with ID: \(label.id).")
    }
}
