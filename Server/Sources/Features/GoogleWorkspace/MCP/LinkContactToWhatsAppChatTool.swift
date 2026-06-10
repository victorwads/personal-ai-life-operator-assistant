import Foundation

@MainActor
struct LinkContactToWhatsAppChatTool: MCPToolDefinition {
    private let repositoryProvider: @MainActor () -> FirestoreAssistantContactRepository

    init(repositoryProvider: @escaping @MainActor () -> FirestoreAssistantContactRepository) {
        self.repositoryProvider = repositoryProvider
    }

    let name = "link_contact_to_whatsapp_chat"
    let icon = "link"
    let description = "Links a local AssistantContact to a WhatsApp Chat ID."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "contactId": .object(["type": .string("string"), "description": .string("The local AssistantContact ID.")]),
            "whatsappChatId": .object(["type": .string("string"), "description": .string("The WhatsApp Chat ID (e.g. '5511999999999@c.us').")])
        ]),
        "required": .array([.string("contactId"), .string("whatsappChatId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "contactId", value: .string("contact-123")),
        .init(name: "whatsappChatId", value: .string("5511999999999@c.us"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let contactId = try MCPSupport.string("contactId", from: call)
        let whatsappChatId = try MCPSupport.string("whatsappChatId", from: call)

        let repository = repositoryProvider()
        guard var contact = try await repository.getById(contactId) else {
            throw NSError(domain: "LinkContactToWhatsAppChatTool", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "AssistantContact with ID '\(contactId)' was not found."
            ])
        }

        contact.whatsappChatId = whatsappChatId
        try await repository.save(contact)

        return .string("Successfully linked contact '\(contact.displayName)' (ID: \(contactId)) to WhatsApp chat '\(whatsappChatId)'.")
    }
}
