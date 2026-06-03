import Foundation

struct OpenAICompatibleChatCompletionsRequest: Encodable {
    let model: String
    let messages: [OpenAICompatibleChatMessage]
    let tools: [OpenAICompatibleTool]?
    let temperature: Double
    let maxTokens: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }

    init(request: AIProviderRequest) {
        self.model = request.model
        self.messages = request.messages.map { OpenAICompatibleChatMessage(message: $0) }
        self.tools = request.tools.isEmpty ? nil : request.tools.map { OpenAICompatibleTool(definition: $0) }
        self.temperature = request.temperature
        self.maxTokens = request.maxOutputTokens
        self.stream = true
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
        self.content = message.content
        self.name = message.name
        self.toolCallID = message.toolCallID
        self.toolCalls = message.toolCalls.isEmpty ? nil : message.toolCalls.map { OpenAICompatibleToolCall(toolCall: $0) }
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
            arguments: toolCall.argumentsJSON
        )
    }
}

struct OpenAICompatibleToolCallFunction: Encodable {
    let name: String
    let arguments: String
}
