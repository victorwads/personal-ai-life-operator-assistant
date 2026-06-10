import Foundation

@MainActor
struct LinkGoogleContactToWhatsAppChatTool: MCPToolDefinition {
    private let repositoryProvider: @MainActor () -> FirestoreAssistantContactRepository
    private let contactsServiceProvider: @MainActor () -> GoogleContactsService

    init(
        repositoryProvider: @escaping @MainActor () -> FirestoreAssistantContactRepository,
        contactsServiceProvider: @escaping @MainActor () -> GoogleContactsService
    ) {
        self.repositoryProvider = repositoryProvider
        self.contactsServiceProvider = contactsServiceProvider
    }

    let name = "link_google_contact_to_whatsapp_chat"
    let icon = "link.badge.plus"
    let description = "Links a Google Contact (via Person ID) to a WhatsApp Chat ID, creating a local AssistantContact if it does not exist."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "googlePersonId": .object(["type": .string("string"), "description": .string("The Google People API Person ID (e.g. 'people/c12345' or just 'c12345').")]),
            "whatsappChatId": .object(["type": .string("string"), "description": .string("The WhatsApp Chat ID (e.g. '5511999999999@c.us').")])
        ]),
        "required": .array([.string("googlePersonId"), .string("whatsappChatId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "googlePersonId", value: .string("people/c123456")),
        .init(name: "whatsappChatId", value: .string("5511999999999@c.us"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let googlePersonId = try MCPSupport.string("googlePersonId", from: call)
        let whatsappChatId = try MCPSupport.string("whatsappChatId", from: call)

        var normalizedPersonId = googlePersonId
        if !normalizedPersonId.hasPrefix("people/") {
            normalizedPersonId = "people/" + normalizedPersonId
        }

        let repository = repositoryProvider()
        
        if var existing = try await repository.findByGooglePersonId(normalizedPersonId) {
            existing.whatsappChatId = whatsappChatId
            try await repository.save(existing)
            return .string("Successfully updated existing AssistantContact '\(existing.displayName)' (ID: \(existing.id ?? "")) with WhatsApp chat '\(whatsappChatId)'.")
        }

        // Fetch from Google Contacts
        let contactsService = contactsServiceProvider()
        guard let googleContact = try await contactsService.getContact(resourceName: normalizedPersonId) else {
            throw NSError(domain: "LinkGoogleContactToWhatsAppChatTool", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Google Contact with ID '\(normalizedPersonId)' was not found."
            ])
        }

        let newContact = AssistantContact(
            id: nil,
            displayName: googleContact.displayName,
            googlePersonId: normalizedPersonId,
            whatsappChatId: whatsappChatId,
            primaryPhone: googleContact.phoneNumbers.first,
            primaryEmail: googleContact.emailAddresses.first
        )

        let saved = try await repository.save(newContact)

        return .string("Successfully created new AssistantContact '\(saved.displayName)' (ID: \(saved.id ?? "")) linked to Google Person ID '\(normalizedPersonId)' and WhatsApp chat '\(whatsappChatId)'.")
    }
}
