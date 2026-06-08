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
    let streamOptions: OpenAICompatibleStreamOptions?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case temperature
        case reasoning
        case extraBody = "extra_body"
        case maxTokens = "max_tokens"
        case stream
        case streamOptions = "stream_options"
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
        self.streamOptions = OpenAICompatibleStreamOptions(includeUsage: true)
    }
}

struct OpenAICompatibleStreamOptions: Encodable {
    let includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
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
    let contentValue: AIConversationContent?
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
        self.contentValue = Self.normalizedContent(
            message.contentValue,
            hasToolCalls: !message.toolCalls.isEmpty
        )
        self.name = message.name
        self.toolCallID = message.toolCallID
        self.toolCalls = message.toolCalls.isEmpty ? nil : message.toolCalls.map { OpenAICompatibleToolCall(toolCall: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        switch contentValue {
        case let .text(content):
            try container.encode(content, forKey: .content)
        case let .parts(parts):
            try container.encode(parts.map(OpenAICompatibleChatMessageContentPart.init), forKey: .content)
        case nil:
            break
        }

        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(toolCallID, forKey: .toolCallID)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
    }

    private static func normalizedContent(
        _ content: AIConversationContent?,
        hasToolCalls: Bool
    ) -> AIConversationContent? {
        guard let content else { return nil }
        switch content {
        case let .text(text):
            if hasToolCalls && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            return .text(text)
        case let .parts(parts):
            return parts.isEmpty ? nil : .parts(parts)
        }
    }
}

private struct OpenAICompatibleChatMessageContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: OpenAICompatibleChatMessageImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    init(_ part: AIConversationContentPart) {
        switch part {
        case let .text(text):
            self.type = "text"
            self.text = text
            self.imageURL = nil
        case let .imageURL(url):
            self.type = "image_url"
            self.text = nil
            self.imageURL = OpenAICompatibleChatMessageImageURL(url: url)
        }
    }
}

private struct OpenAICompatibleChatMessageImageURL: Encodable {
    let url: String
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
