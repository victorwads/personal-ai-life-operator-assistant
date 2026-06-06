import Foundation
import XCTest
@testable import AIAssistantHub

final class OpenAICompatibleRequestModelsTests: XCTestCase {
    func testPlainTextMessageEncodesContentAsString() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(role: .user, content: "hello")
                ]
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let messages = try XCTUnwrap(jsonObject["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first)

        XCTAssertEqual(userMessage["role"] as? String, "user")
        XCTAssertEqual(userMessage["content"] as? String, "hello")
    }

    func testMultimodalUserMessageEncodesAsOpenAIContentParts() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(
                        role: .user,
                        contentParts: [
                            .text("Extract the image."),
                            .imageURL("data:image/png;base64,aGVsbG8=")
                        ]
                    )
                ]
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let messages = try XCTUnwrap(jsonObject["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first)
        let contentParts = try XCTUnwrap(userMessage["content"] as? [[String: Any]])

        XCTAssertEqual(contentParts.count, 2)
        XCTAssertEqual(contentParts[0]["type"] as? String, "text")
        XCTAssertEqual(contentParts[0]["text"] as? String, "Extract the image.")
        XCTAssertEqual(contentParts[1]["type"] as? String, "image_url")
        let imageURL = try XCTUnwrap(contentParts[1]["image_url"] as? [String: Any])
        XCTAssertEqual(imageURL["url"] as? String, "data:image/png;base64,aGVsbG8=")
    }

    func testAssistantToolCallMessageOmitsWhitespaceOnlyContent() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(
                        role: .assistant,
                        content: "\n\n",
                        toolCalls: [
                            AIRequestedToolCall(
                                id: "call-1",
                                name: "list_unhandled_chats",
                                argumentsJSON: ""
                            )
                        ]
                    )
                ]
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let messages = try XCTUnwrap(jsonObject["messages"] as? [[String: Any]])
        let assistantMessage = try XCTUnwrap(messages.first)

        XCTAssertNil(assistantMessage["content"])

        let toolCalls = try XCTUnwrap(assistantMessage["tool_calls"] as? [[String: Any]])
        let function = try XCTUnwrap(toolCalls.first?["function"] as? [String: Any])
        XCTAssertEqual(function["arguments"] as? String, "{}")
    }

    func testContinuationPayloadPreservesAssistantThenToolOrdering() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(role: .system, content: "system"),
                    AIConversationMessage(role: .user, content: "user"),
                    AIConversationMessage(
                        role: .assistant,
                        content: "",
                        toolCalls: [
                            AIRequestedToolCall(
                                id: "call-1",
                                name: "list_unhandled_chats",
                                argumentsJSON: "   "
                            )
                        ]
                    ),
                    AIConversationMessage(
                        role: .tool,
                        content: "{\"success\":true}",
                        name: "list_unhandled_chats",
                        toolCallID: "call-1"
                    )
                ]
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let messages = try XCTUnwrap(jsonObject["messages"] as? [[String: Any]])

        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user", "assistant", "tool"])

        let assistantMessage = try XCTUnwrap(messages[2] as [String: Any])
        XCTAssertNil(assistantMessage["content"])

        let toolCalls = try XCTUnwrap(assistantMessage["tool_calls"] as? [[String: Any]])
        let function = try XCTUnwrap(toolCalls.first?["function"] as? [String: Any])
        XCTAssertEqual(function["name"] as? String, "list_unhandled_chats")
        XCTAssertEqual(function["arguments"] as? String, "{}")

        let toolMessage = try XCTUnwrap(messages[3] as [String: Any])
        XCTAssertEqual(toolMessage["role"] as? String, "tool")
        XCTAssertEqual(toolMessage["tool_call_id"] as? String, "call-1")
        XCTAssertEqual(toolMessage["content"] as? String, "{\"success\":true}")
    }

    func testReasoningOffSerializesAsStringOff() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(role: .user, content: "hello")
                ],
                reasoningEffort: .off
            )
        )

        let jsonObject = try encodedJSONObject(for: request)

        XCTAssertEqual(jsonObject["reasoning"] as? String, "off")
        XCTAssertNil(jsonObject["extra_body"])
    }

    func testReasoningNoneSerializesInsideEffortObject() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(role: .user, content: "hello")
                ],
                reasoningEffort: .none
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let reasoning = try XCTUnwrap(jsonObject["reasoning"] as? [String: Any])

        XCTAssertEqual(reasoning["effort"] as? String, "none")
        XCTAssertNil(jsonObject["extra_body"])
    }

    func testQwenOffSerializesExtraBodyWithoutReasoningField() throws {
        let request = OpenAICompatibleChatCompletionsRequest(
            request: AIProviderRequest(
                model: "model-1",
                messages: [
                    AIConversationMessage(role: .user, content: "hello")
                ],
                reasoningEffort: .qwenOff
            )
        )

        let jsonObject = try encodedJSONObject(for: request)
        let extraBody = try XCTUnwrap(jsonObject["extra_body"] as? [String: Any])
        let chatTemplateKwargs = try XCTUnwrap(extraBody["chat_template_kwargs"] as? [String: Any])

        XCTAssertEqual(chatTemplateKwargs["enable_thinking"] as? Bool, false)
        XCTAssertNil(jsonObject["reasoning"])
    }

    private func encodedJSONObject(for request: OpenAICompatibleChatCompletionsRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
