import Foundation

struct AIConnectionConversationContextBuilder {
    private static let defaultUserBootstrapMessage = """
    Start the operational loop using the available instructions and bootstrap context.
    """

    func bootstrapConversationMessages(
        systemPrompt: String,
        bootstrapMessages: [AIConversationMessage] = []
    ) -> [AIConversationMessage] {
        var messages = [AIConversationMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: bootstrapMessages)

        if !messages.contains(where: { $0.role == .user }) {
            messages.append(
                AIConversationMessage(
                    role: .user,
                    content: Self.defaultUserBootstrapMessage
                )
            )
        }

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

            * If you need to tell the client something, call announce_to_client(...).
            * If you need a client answer, call ask_to_client(...).
            * If this belongs to an operational thread, call create_issue(...) or update_issue(...).
            * If there is nothing else to do, call wait_for_event(...).
            * Do not answer in plain text again.
            """
        )
    }

    func missingTerminalActionCorrectionMessage() -> AIConversationMessage {
        AIConversationMessage(
            role: .user,
            content: "You ended your completion without calling a required terminal action. You must not finish this turn without deciding what happens next. Continue from the current context and do not repeat work unnecessarily."
        )
    }

    func toolResultMessage(result: AIToolExecutionResult) -> String {
        var lines: [String] = [
            "Tool: \(result.toolName)",
            "Status: \(result.success ? "success" : "failed")"
        ]

        if let payload = result.payload {
            let payloadLanguage = payloadFenceLanguage(for: payload)
            let payloadText = formattedPayloadText(for: payload)
            lines.append(
                """
                Payload:
                ```\(payloadLanguage)
                \(payloadText)
                ```
                """
            )
        }

        if let errorMessage = result.errorMessage {
            lines.append("Error: \(errorMessage)")
        }

        if let suggestedAction = result.suggestedAction {
            lines.append(
                """
                Suggested Action:
                \(suggestedAction)
                """
            )
        }

        if !result.validationErrors.isEmpty {
            let validationLines = result.validationErrors.map { error in
                """
                - Field: \(error.fieldPath)
                  Message: \(error.message)
                  Suggested Action: \(error.suggestedAction)
                """
            }
            lines.append(
                """
                Validation Errors:
                \(validationLines.joined(separator: "\n"))
                """
            )
        }

        return lines.joined(separator: "\n\n")
    }

    func invalidOperationalAssistantText(in response: AIProviderResponse) -> String? {
        guard response.toolCalls.isEmpty else { return nil }
        let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func payloadFenceLanguage(for payload: AIJSONValue) -> String {
        switch payload {
        case .object, .array:
            return "json"
        default:
            return "text"
        }
    }

    private func formattedPayloadText(for payload: AIJSONValue) -> String {
        switch payload {
        case let .string(value):
            return value
        default:
            return (try? payload.jsonString(prettyPrinted: true)) ?? String(describing: payload)
        }
    }
}
