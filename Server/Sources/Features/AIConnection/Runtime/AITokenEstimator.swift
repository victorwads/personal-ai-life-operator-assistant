import Foundation

struct AITokenEstimator {
    func estimateInputTokens(for request: AIProviderRequest) -> Int {
        var total = 0

        for message in request.messages {
            total += estimateMessageTokens(message)
        }

        total += estimateToolsTokens(request.tools)
        return max(1, total)
    }

    func estimateOutputTokens(text: String) -> Int {
        estimateTokenCount(text: text)
    }

    private func estimateMessageTokens(_ message: AIConversationMessage) -> Int {
        var total = 4
        total += estimateTokenCount(text: message.role.rawValue)
        total += estimateTokenCount(text: message.name ?? "")
        total += estimateTokenCount(text: message.toolCallID ?? "")

        if let content = message.content {
            total += estimateTokenCount(text: content)
        }

        for part in message.contentParts ?? [] {
            switch part {
            case let .text(text):
                total += estimateTokenCount(text: text)
            case let .imageURL(url):
                total += estimateImageURLTokens(url)
            }
        }

        for toolCall in message.toolCalls {
            total += estimateTokenCount(text: toolCall.id)
            total += estimateTokenCount(text: toolCall.name)
            total += estimateTokenCount(text: toolCall.argumentsJSON)
        }

        return max(1, total)
    }

    private func estimateToolsTokens(_ tools: [AIToolDefinition]) -> Int {
        guard !tools.isEmpty else { return 0 }

        var total = 0
        for tool in tools {
            total += 8
            total += estimateTokenCount(text: tool.name)
            total += estimateTokenCount(text: tool.description)
            total += estimateTokenCount(text: (try? tool.inputSchema.jsonString(prettyPrinted: false)) ?? "")
        }
        return total
    }

    private func estimateTokenCount(text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(trimmed.count) / 4.0)))
    }

    private func estimateImageURLTokens(_ url: String) -> Int {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if trimmed.hasPrefix("data:") {
            let headerLength = trimmed.prefix { $0 != "," }.count
            return 1_000 + estimateTokenCount(text: String(trimmed.prefix(headerLength + 1)))
        }

        let cappedLength = min(trimmed.count, 512)
        return estimateTokenCount(text: String(trimmed.prefix(cappedLength)))
    }
}
