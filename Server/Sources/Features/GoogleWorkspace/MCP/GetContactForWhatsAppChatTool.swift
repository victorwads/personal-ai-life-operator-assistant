import Foundation

@MainActor
struct GetContactForWhatsAppChatTool: MCPToolDefinition {
    private let repositoryProvider: @MainActor () -> FirestoreAssistantContactRepository

    init(repositoryProvider: @escaping @MainActor () -> FirestoreAssistantContactRepository) {
        self.repositoryProvider = repositoryProvider
    }

    let name = "get_contact_for_whatsapp_chat"
    let icon = "person.text.rectangle"
    let description = "Retrieves the linked AssistantContact details for a specific WhatsApp Chat ID."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "whatsappChatId": .object(["type": .string("string"), "description": .string("The WhatsApp Chat ID to look up.")])
        ]),
        "required": .array([.string("whatsappChatId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "whatsappChatId", value: .string("5511999999999@c.us"))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let whatsappChatId = try MCPSupport.string("whatsappChatId", from: call)

        let repository = repositoryProvider()
        guard let contact = try await repository.findByWhatsappChatId(whatsappChatId) else {
            return .string("No AssistantContact linked to WhatsApp chat '\(whatsappChatId)' was found.")
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(contact)
        return try JSONDecoder().decode(MCPJSONValue.self, from: data)
    }
}
