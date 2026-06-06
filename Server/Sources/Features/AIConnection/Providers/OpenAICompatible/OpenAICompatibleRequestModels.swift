import Foundation

struct OpenAICompatibleChatCompletionsRequest: Encodable {
    let model: String
    let messages: [OpenAICompatibleChatMessage]
    let tools: [OpenAICompatibleTool]?
    let temperature: Double
    let reasoning: OpenAICompatibleReasoningPayload?
    let extraBody: OpenAICompatibleExtraBody?
    let maxTokens: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case temperature
        case reasoning
        case extraBody = "extra_body"
        case maxTokens = "max_tokens"
        case stream
    }

    init(request: AIProviderRequest) {
        self.model = request.model
        self.messages = request.messages.map { OpenAICompatibleChatMessage(message: $0) }
        self.tools = request.tools.isEmpty ? nil : request.tools.map { OpenAICompatibleTool(definition: $0) }
        self.temperature = request.temperature
        self.reasoning = request.reasoningEffort.reasoningPayload
        self.extraBody = request.reasoningEffort.extraBody
        self.maxTokens = request.maxOutputTokens
        self.stream = true
    }
}

enum OpenAICompatibleReasoningPayload: Encodable {
    case off
    case effort(String)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .off:
            var container = encoder.singleValueContainer()
            try container.encode("off")
        case let .effort(effort):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(effort, forKey: .effort)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case effort
    }
}

struct OpenAICompatibleExtraBody: Encodable {
    let chatTemplateKwargs: OpenAICompatibleChatTemplateKwargs

    enum CodingKeys: String, CodingKey {
        case chatTemplateKwargs = "chat_template_kwargs"
    }
}

struct OpenAICompatibleChatTemplateKwargs: Encodable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
    }
}

struct OpenAICompatibleChatMessage: Encodable {
    let role: String
    let content: String?
    let name: String?
    let toolCallID: String?
    let toolCalls: [OpenAICompatibleToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCallID = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    init(message: AIConversationMessage) {
        self.role = message.role.rawValue
        self.content = Self.normalizedContent(
            message.content,
            hasToolCalls: !message.toolCalls.isEmpty
        )
        self.name = message.name
        self.toolCallID = message.toolCallID
        self.toolCalls = message.toolCalls.isEmpty ? nil : message.toolCalls.map { OpenAICompatibleToolCall(toolCall: $0) }
    }

    private static func normalizedContent(_ content: String?, hasToolCalls: Bool) -> String? {
        guard let content else { return nil }
        if hasToolCalls && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return content
    }
}

struct OpenAICompatibleTool: Encodable {
    let type = "function"
    let function: OpenAICompatibleToolFunction

    init(definition: AIToolDefinition) {
        self.function = OpenAICompatibleToolFunction(definition: definition)
    }
}

struct OpenAICompatibleToolFunction: Encodable {
    let name: String
    let description: String
    let parameters: AIJSONValue

    init(definition: AIToolDefinition) {
        self.name = definition.name
        self.description = definition.description
        self.parameters = definition.inputSchema
    }
}

struct OpenAICompatibleToolCall: Encodable {
    let id: String
    let type = "function"
    let function: OpenAICompatibleToolCallFunction

    init(toolCall: AIRequestedToolCall) {
        self.id = toolCall.id
        self.function = OpenAICompatibleToolCallFunction(
            name: toolCall.name,
            arguments: Self.normalizedArgumentsJSON(toolCall.argumentsJSON)
        )
    }

    private static func normalizedArgumentsJSON(_ argumentsJSON: String) -> String {
        let trimmed = argumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "{}" : trimmed
    }
}

struct OpenAICompatibleToolCallFunction: Encodable {
    let name: String
    let arguments: String
}
