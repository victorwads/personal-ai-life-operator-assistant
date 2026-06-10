import Foundation

@MainActor
struct SearchGoogleContactsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleContactsService

    init(serviceProvider: @escaping @MainActor () -> GoogleContactsService) {
        self.serviceProvider = serviceProvider
    }

    let name = "search_google_contacts"
    let icon = "person.crop.circle"
    let description = "Searches or lists the user's Google contacts via the People API."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("Optional search string (searches across names, emails, and phone numbers). If empty or omitted, returns the list of contacts.")
            ]),
            "maxResults": .object([
                "type": .string("integer"),
                "description": .string("Optional maximum number of contacts to return (default 20).")
            ])
        ])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("John")),
        .init(name: "maxResults", value: .integer(10))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let query = MCPSupport.optionalString("query", from: call) ?? ""
        let maxResults = MCPSupport.optionalInt("maxResults", from: call) ?? 20

        let service = serviceProvider()
        let contacts = try await service.searchContacts(query: query, pageSize: maxResults)

        guard !contacts.isEmpty else {
            return .string("No contacts found.")
        }

        var lines: [String] = ["<contacts count=\"\(contacts.count)\">"]
        for contact in contacts {
            lines.append("  <contact resourceName=\"\(contact.resourceName)\">")
            lines.append("    <displayName>\(contact.displayName)</displayName>")
            if let given = contact.givenName {
                lines.append("    <givenName>\(given)</givenName>")
            }
            if let family = contact.familyName {
                lines.append("    <familyName>\(family)</familyName>")
            }
            if !contact.emailAddresses.isEmpty {
                lines.append("    <emails>\(contact.emailAddresses.joined(separator: ", "))</emails>")
            }
            if !contact.phoneNumbers.isEmpty {
                lines.append("    <phones>\(contact.phoneNumbers.joined(separator: ", "))</phones>")
            }
            if let org = contact.organizationName {
                lines.append("    <organization>\(org)</organization>")
            }
            if let photo = contact.photoUrl {
                lines.append("    <photoUrl>\(photo)</photoUrl>")
            }
            lines.append("  </contact>")
        }
        lines.append("</contacts>")

        return .string(lines.joined(separator: "\n"))
    }
}
