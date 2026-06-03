import Foundation

struct GetAssistantNameTool: MCPToolDefinition {
    private let settings: SentMessagesSettingsWrapper

    init(settings: SentMessagesSettingsWrapper) {
        self.settings = settings
    }

    let name = "get_assistant_name"
    let icon = "person.crop.circle"
    let description = "Returns the configured outbound assistant identity and formatting settings for sent messages."
    let group = "sentMessages"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let assistantName = await MainActor.run { settings.assistantName }
        return .object([
            "assistantName": .string(assistantName)
        ])
    }
}
