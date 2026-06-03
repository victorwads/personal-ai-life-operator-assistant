import Foundation

struct OpenAICompatibleStreamParser {
    private let provider: AIConnectionProviderKind
    private let requestedModel: String

    private var responseStarted = false
    private var responseID: String?
    private var responseModel: String
    private var finishReason: String?
    private var accumulatedText = ""
    private var accumulatedReasoning = ""
    private var accumulatedUsage: AIUsage?
    private var partialToolCalls: [Int: PartialToolCall] = [:]

    init(provider: AIConnectionProviderKind, requestedModel: String) {
        self.provider = provider
        self.requestedModel = requestedModel
        self.responseModel = requestedModel
    }

    mutating func parse(line: String) throws -> [AIStreamEvent] {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix("data:") else {
            return []
        }

        let payload = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty else {
            return []
        }

        if payload == "[DONE]" {
            return finalizedEvents()
        }

        let chunk = try JSONDecoder().decode(OpenAICompatibleStreamChunk.self, from: Data(payload.utf8))
        return merge(chunk: chunk)
    }

    private mutating func merge(chunk: OpenAICompatibleStreamChunk) -> [AIStreamEvent] {
        var events: [AIStreamEvent] = []

        if !responseStarted {
            responseStarted = true
            responseID = chunk.id
            events.append(.responseStarted(id: chunk.id))
        } else if responseID == nil, let chunkID = chunk.id {
            responseID = chunkID
        }

        if let chunkModel = chunk.model, !chunkModel.isEmpty {
            responseModel = chunkModel
        }

        if let usage = chunk.usage?.normalizedUsage {
            accumulatedUsage = usage
            events.append(.usage(usage))
        }

        for choice in chunk.choices {
            if let content = choice.delta?.content, !content.isEmpty {
                accumulatedText += content
                events.append(.textDelta(content))
            }

            if let reasoning = choice.delta?.reasoningDelta, !reasoning.isEmpty {
                accumulatedReasoning += reasoning
                events.append(.reasoningDelta(reasoning))
            }

            for toolCallDelta in choice.delta?.toolCalls ?? [] {
                let result = mergeToolCall(toolCallDelta)
                events.append(contentsOf: result)
            }

            if let choiceFinishReason = choice.finishReason {
                finishReason = choiceFinishReason
            }
        }

        return events
    }

    private mutating func mergeToolCall(_ delta: OpenAICompatibleToolCallDelta) -> [AIStreamEvent] {
        var events: [AIStreamEvent] = []
        var partial = partialToolCalls[delta.index] ?? PartialToolCall()

        if let id = delta.id, !id.isEmpty {
            partial.id = id
        }

        if let name = delta.function?.name, !name.isEmpty {
            partial.name = name
        }

        if !partial.didEmitStarted, let id = partial.id, let name = partial.name {
            partial.didEmitStarted = true
            events.append(.toolCallStarted(id: id, name: name))
        }

        if let argumentsDelta = delta.function?.arguments, !argumentsDelta.isEmpty {
            partial.arguments += argumentsDelta
            if let id = partial.id {
                events.append(.toolCallArgumentsDelta(id: id, delta: argumentsDelta))
            }
        }

        partialToolCalls[delta.index] = partial
        return events
    }

    private mutating func finalizedEvents() -> [AIStreamEvent] {
        // TODO: Revisit tool-call completion timing when implementing the real tool loop.
        // This currently emits completed tool calls only after `[DONE]`, which is enough for the foundation,
        // but later we may want to detect tool-call completion before the full response finishes.
        let completedToolCalls = partialToolCalls
            .sorted { $0.key < $1.key }
            .compactMap { _, partial in partial.completedToolCall }

        let completionEvents = completedToolCalls.map(AIStreamEvent.toolCallCompleted)
        let response = AIProviderResponse(
            id: responseID,
            model: responseModel,
            provider: provider,
            finishReason: finishReason,
            text: accumulatedText,
            reasoning: accumulatedReasoning,
            toolCalls: completedToolCalls,
            usage: accumulatedUsage
        )

        return completionEvents + [.completed(response)]
    }
}

private struct PartialToolCall {
    var id: String?
    var name: String?
    var arguments = ""
    var didEmitStarted = false

    var completedToolCall: AIRequestedToolCall? {
        guard let id, let name else {
            return nil
        }

        return AIRequestedToolCall(id: id, name: name, argumentsJSON: arguments)
    }
}

private struct OpenAICompatibleStreamChunk: Decodable {
    let id: String?
    let model: String?
    let choices: [OpenAICompatibleStreamChoice]
    let usage: OpenAICompatibleUsagePayload?
}

private struct OpenAICompatibleStreamChoice: Decodable {
    let delta: OpenAICompatibleStreamDelta?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

private struct OpenAICompatibleStreamDelta: Decodable {
    let content: String?
    let reasoning: String?
    let reasoningContent: String?
    let toolCalls: [OpenAICompatibleToolCallDelta]?

    enum CodingKeys: String, CodingKey {
        case content
        case reasoning
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }

    var reasoningDelta: String? {
        if let reasoning, !reasoning.isEmpty {
            return reasoning
        }

        if let reasoningContent, !reasoningContent.isEmpty {
            return reasoningContent
        }

        return nil
    }
}

private struct OpenAICompatibleToolCallDelta: Decodable {
    let index: Int
    let id: String?
    let function: OpenAICompatibleToolCallDeltaFunction?
}

private struct OpenAICompatibleToolCallDeltaFunction: Decodable {
    let name: String?
    let arguments: String?
}

private struct OpenAICompatibleUsagePayload: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    var normalizedUsage: AIUsage {
        AIUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }
}
