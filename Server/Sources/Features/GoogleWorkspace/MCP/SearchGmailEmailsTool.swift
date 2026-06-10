import Foundation

@MainActor
struct SearchGmailEmailsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "search_gmail_emails"
    let icon = "magnifyingglass"
    let description = "Searches emails in the authenticated user's Gmail account using Gmail query syntax."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("The search query using Gmail syntax (e.g., 'from:boss', 'newer_than:30d', 'subject:Invoice').")
            ]),
            "maxResults": .object([
                "type": .string("integer"),
                "description": .string("Optional maximum number of messages to return (default 20).")
            ])
        ]),
        "required": .array([.string("query")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("is:unread")),
        .init(name: "maxResults", value: .integer(10))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let query = MCPSupport.optionalString("query", from: call), !query.isEmpty else {
            throw NSError(domain: "SearchGmailEmailsTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing query parameter."
            ])
        }
        let maxResults = MCPSupport.optionalInt("maxResults", from: call) ?? 20

        let service = serviceProvider()
        let emails = try await service.searchEmails(query: query, maxResults: maxResults)

        guard !emails.isEmpty else {
            return .string("No matching emails found.")
        }

        var lines: [String] = ["<emails count=\"\(emails.count)\">"]
        for email in emails {
            lines.append("  <email messageId=\"\(email.messageId)\" threadId=\"\(email.threadId)\">")
            lines.append("    <from>\(email.from)</from>")
            lines.append("    <subject>\(email.subject)</subject>")
            lines.append("    <date>\(email.date)</date>")
            lines.append("    <snippet>\(email.snippet)</snippet>")
            lines.append("  </email>")
        }
        lines.append("</emails>")

        return .string(lines.joined(separator: "\n"))
    }
}
