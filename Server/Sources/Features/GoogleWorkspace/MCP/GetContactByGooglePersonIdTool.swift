import Foundation

@MainActor
struct GetContactByGooglePersonIdTool: MCPToolDefinition {
    private let repositoryProvider: @MainActor () -> FirestoreAssistantContactRepository

    init(repositoryProvider: @escaping @MainActor () -> FirestoreAssistantContactRepository) {
        self.repositoryProvider = repositoryProvider
    }

    let name = "get_contact_by_google_person_id"
    let icon = "person.crop.circle.badge.questionmark"
    let description = "Retrieves the local AssistantContact details associated with a Google Person ID."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "googlePersonId": .object(["type": .string("string"), "description": .string("The Google Person ID to look up.")])
        ]),
        "required": .array([.string("googlePersonId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "googlePersonId", value: .string("people/c123456"))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let googlePersonId = try MCPSupport.string("googlePersonId", from: call)

        var normalizedPersonId = googlePersonId
        if !normalizedPersonId.hasPrefix("people/") {
            normalizedPersonId = "people/" + normalizedPersonId
        }

        let repository = repositoryProvider()
        guard let contact = try await repository.findByGooglePersonId(normalizedPersonId) else {
            return .string("No AssistantContact linked to Google Person ID '\(normalizedPersonId)' was found.")
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(contact)
        return try JSONDecoder().decode(MCPJSONValue.self, from: data)
    }
}
