import Foundation

@MainActor
struct GetEmailThreadTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "get_email_thread"
    let icon = "bubble.left.and.bubble.right"
    let description = "Retrieves all messages in a specific conversation thread in chronological order."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "threadId": .object([
                "type": .string("string"),
                "description": .string("The unique ID of the conversation thread.")
            ])
        ]),
        "required": .array([.string("threadId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "threadId", value: .string("18a14b30c5e7b23f"))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let threadId = MCPSupport.optionalString("threadId", from: call), !threadId.isEmpty else {
            throw NSError(domain: "GetEmailThreadTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing threadId parameter."
            ])
        }

        let service = serviceProvider()
        let thread = try await service.getThread(threadId: threadId)

        var lines: [String] = ["<thread id=\"\(thread.threadId)\" messagesCount=\"\(thread.messages.count)\">"]
        
        // Sort messages chronologically by internalDate (oldest first, so we read as a timeline)
        let chronologicalMessages = thread.messages.sorted { (a, b) -> Bool in
            let aTime = Int64(a.internalDate) ?? 0
            let bTime = Int64(b.internalDate) ?? 0
            return aTime < bTime
        }

        for msg in chronologicalMessages {
            lines.append("  <message messageId=\"\(msg.messageId)\">")
            lines.append("    <sender>\(msg.from)</sender>")
            lines.append("    <recipients>\(msg.to)</recipients>")
            lines.append("    <timestamp>\(msg.date)</timestamp>")
            lines.append("    <subject>\(msg.subject)</subject>")
            lines.append("    <snippet>\(msg.snippet)</snippet>")
            
            // Extract body preview/content
            let bodyText = msg.plainTextBody.isEmpty ? msg.htmlBody : msg.plainTextBody
            let previewLength = 1000
            let preview = bodyText.count > previewLength ? String(bodyText.prefix(previewLength)) + "... (truncated)" : bodyText
            lines.append("    <body>\n\(preview)\n    </body>")
            
            lines.append("  </message>")
        }
        lines.append("</thread>")

        return .string(lines.joined(separator: "\n"))
    }
}
