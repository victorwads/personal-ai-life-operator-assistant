import Foundation

@MainActor
struct ListGmailLabelsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GmailService

    init(serviceProvider: @escaping @MainActor () -> GmailService) {
        self.serviceProvider = serviceProvider
    }

    let name = "list_gmail_labels"
    let icon = "tag"
    let description = "Lists all Gmail labels defined in the authenticated user's account."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])

    let exampleParameters: [MCPToolExampleParameter] = []

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let service = serviceProvider()
        let labels = try await service.listLabels()

        guard !labels.isEmpty else {
            return .string("No labels found.")
        }

        var lines: [String] = ["<labels count=\"\(labels.count)\">"]
        for label in labels {
            lines.append("  <label id=\"\(label.id)\" name=\"\(label.name)\" type=\"\(label.type)\" />")
        }
        lines.append("</labels>")

        return .string(lines.joined(separator: "\n"))
    }
}
