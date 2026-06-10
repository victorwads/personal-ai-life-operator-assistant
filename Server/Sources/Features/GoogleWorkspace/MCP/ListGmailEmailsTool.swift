import Foundation

@MainActor
struct ListGmailEmailsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "list_gmail_emails"
    let icon = "envelope"
    let description = "Lists recent emails from the authenticated user's Gmail inbox."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "maxResults": .object([
                "type": .string("integer"),
                "description": .string("Optional maximum number of messages to return (default 10).")
            ]),
            "query": .object([
                "type": .string("string"),
                "description": .string("Optional search query filter matching Gmail search operators (e.g. 'is:unread', 'from:boss').")
            ])
        ])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "maxResults", value: .integer(5)),
        .init(name: "query", value: .string("is:unread"))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let maxResults = MCPSupport.optionalInt("maxResults", from: call) ?? 10
        let query = MCPSupport.optionalString("query", from: call)

        let service = serviceProvider()
        let emails = try await service.listRecentEmails(maxResults: maxResults, query: query)

        guard !emails.isEmpty else {
            return .string("No emails found.")
        }

        var lines: [String] = ["<emails count=\"\(emails.count)\">"]
        for email in emails {
            lines.append("  <email id=\"\(email.id)\" threadId=\"\(email.threadId)\">")
            lines.append("    <from>\(email.from)</from>")
            lines.append("    <to>\(email.to)</to>")
            lines.append("    <subject>\(email.subject)</subject>")
            lines.append("    <date>\(email.date)</date>")
            lines.append("    <snippet>\(email.snippet)</snippet>")
            lines.append("  </email>")
        }
        lines.append("</emails>")

        return .string(lines.joined(separator: "\n"))
    }
}
