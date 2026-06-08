import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionUsageTrackerTests: XCTestCase {
    func testEstimatedInputTokensAreAppliedBeforeStreaming() {
        let tracker = AIConnectionUsageTracker()
        var state = AIConnectionRuntimeState.initial(systemPrompt: "System prompt")
        state.startedAt = Date()
        state.usage.runStartedAt = state.startedAt
        let request = AIProviderRequest(
            model: "model-1",
            messages: [
                AIConversationMessage(role: .system, content: "System prompt"),
                AIConversationMessage(
                    role: .user,
                    contentParts: [
                        .text("Tell me something useful."),
                        .imageURL("data:image/png;base64,aGVsbG8=")
                    ],
                    name: "client",
                    toolCallID: "tool-call-1",
                    toolCalls: [
                        AIRequestedToolCall(
                            id: "tool-call-1",
                            name: "search",
                            argumentsJSON: "{\"query\":\"swift\"}"
                        )
                    ]
                )
            ],
            tools: [
                AIToolDefinition(
                    name: "search",
                    description: "Search for useful information.",
                    icon: nil,
                    inputSchema: .object([
                        "query": .string("string")
                    ]),
                    traits: []
                )
            ]
        )

        tracker.applyEstimatedInputTokens(for: request, at: Date(), state: &state)

        XCTAssertNotNil(state.usage.inputTokens)
        XCTAssertTrue((state.usage.inputTokens ?? 0) > 0)
        XCTAssertTrue(state.usage.isInputTokensEstimated)
        XCTAssertNotNil(state.usage.lastUpdatedAt)
    }
}
