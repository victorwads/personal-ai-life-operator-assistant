import Foundation

@MainActor
struct GetEmailContentTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "get_email_content"
    let icon = "doc.plaintext"
    let description = "Retrieves the full content of a specific email by its message ID, including headers, body, and labels."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "messageId": .object([
                "type": .string("string"),
                "description": .string("The unique ID of the Gmail message to retrieve.")
            ])
        ]),
        "required": .array([.string("messageId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "messageId", value: .string("18a14b30c5e7b23f"))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        guard let messageId = MCPSupport.optionalString("messageId", from: call), !messageId.isEmpty else {
            throw NSError(domain: "GetEmailContentTool", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing messageId parameter."
            ])
        }

        let service = serviceProvider()
        let email = try await service.getEmailContent(messageId: messageId)

        var lines: [String] = ["<email messageId=\"\(email.messageId)\" threadId=\"\(email.threadId)\">"]
        lines.append("  <subject>\(email.subject)</subject>")
        lines.append("  <sender>\(email.from)</sender>")
        lines.append("  <recipients>\(email.to)</recipients>")
        if let cc = email.cc {
            lines.append("  <cc>\(cc)</cc>")
        }
        if let bcc = email.bcc {
            lines.append("  <bcc>\(bcc)</bcc>")
        }
        lines.append("  <labels>\(email.labelIds.joined(separator: ", "))</labels>")
        lines.append("  <date>\(email.date)</date>")
        lines.append("  <snippet>\(email.snippet)</snippet>")
        
        let bodyToUse = email.plainTextBody.isEmpty ? email.htmlBody : email.plainTextBody
        lines.append("  <body>\n\(bodyToUse)\n  </body>")
        
        if !email.attachmentsMetadata.isEmpty {
            lines.append("  <attachments>")
            for attachment in email.attachmentsMetadata {
                lines.append("    <attachment id=\"\(attachment.attachmentId)\" filename=\"\(attachment.filename)\" mimeType=\"\(attachment.mimeType)\" size=\"\(attachment.size)\" />")
            }
            lines.append("  </attachments>")
        }
        
        lines.append("</email>")

        return .string(lines.joined(separator: "\n"))
    }
}
