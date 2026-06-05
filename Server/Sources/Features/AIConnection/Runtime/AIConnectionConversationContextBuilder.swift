import Foundation

struct AIConnectionConversationContextBuilder {
    func bootstrapConversationMessages(
        systemPrompt: String,
        userPrompt: String,
        bootstrapMessage: AIConversationMessage? = nil
    ) -> [AIConversationMessage] {
        var messages = [AIConversationMessage(role: .system, content: systemPrompt)]
        if let bootstrapMessage {
            messages.append(bootstrapMessage)
        }
        messages.append(AIConversationMessage(role: .user, content: userPrompt))
        return messages
    }

    func assistantConversationMessage(
        text: String,
        toolCalls: [AIRequestedToolCall]
    ) -> AIConversationMessage {
        AIConversationMessage(
            role: .assistant,
            content: text.isEmpty ? nil : text,
            toolCalls: toolCalls
        )
    }

    func runtimeCorrectionMessage(for invalidAssistantText: String) -> AIConversationMessage {
        AIConversationMessage(
            role: .user,
            content: """
            Runtime correction:

            You responded with plain assistant text, but this runtime does not allow operational plain-text output.

            Your previous assistant text was:

            \"\"\"
            \(invalidAssistantText)
            \"\"\"

            This output was NOT delivered to the client.

            You must now choose the correct tool call.

            Rules:

            * If you need to tell the client something, call speak_to_client(...).
            * If you need a client answer, call ask_to_client(...).
            * If this belongs to an operational thread, call create_issue(...) or update_issue(...).
            * If there is nothing else to do, call wait_for_event(...).
            * Do not answer in plain text again.
            """
        )
    }

    func toolResultMessage(result: AIToolExecutionResult) -> String {
        var response: [String: AIJSONValue] = [
            "toolName": .string(result.toolName),
            "success": .bool(result.success)
        ]

        if let payload = result.payload {
            response["payload"] = payload
        } else {
            response["payload"] = .null
        }

        if let errorMessage = result.errorMessage {
            response["errorMessage"] = .string(errorMessage)
        }

        if let suggestedAction = result.suggestedAction {
            response["suggestedAction"] = .string(suggestedAction)
        }

        if let durationMilliseconds = result.durationMilliseconds {
            response["durationMilliseconds"] = .double(durationMilliseconds)
        }

        return (try? AIJSONValue.object(response).jsonString(prettyPrinted: false)) ?? "{\"success\":false}"
    }

    func invalidOperationalAssistantText(in response: AIProviderResponse) -> String? {
        guard response.toolCalls.isEmpty else { return nil }
        let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
