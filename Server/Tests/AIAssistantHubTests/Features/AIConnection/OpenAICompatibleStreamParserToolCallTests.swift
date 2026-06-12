import XCTest
@testable import AIAssistantHub

final class OpenAICompatibleStreamParserToolCallTests: FixtureBackedTestCase {
    func testParserProducesToolCallForEmptyArgumentsScenario() throws {
        let completedCall = try completedToolCall(
            fixturePath: "AIConnection/OpenAICompatibleStreamParserToolCalls/EmptyToolArguments/stream.sse"
        )

        XCTAssertEqual(
            completedCall,
            AIRequestedToolCall(id: "call_1", name: "whatsapp_list_unhandled_chats", argumentsJSON: "")
        )
    }

    func testParserProducesToolCallForConcatenatedArgumentScenario() throws {
        let completedCall = try completedToolCall(
            fixturePath: "AIConnection/OpenAICompatibleStreamParserToolCalls/ConcatenatedToolArguments/stream.sse"
        )

        XCTAssertEqual(
            completedCall,
            AIRequestedToolCall(id: "call_2", name: "whatsapp_list_unhandled_chats", argumentsJSON: #"{"limit":10}"#)
        )
    }

    private func completedToolCall(fixturePath: String) throws -> AIRequestedToolCall? {
        let streamText = try fixtureText(fixturePath)

        var parser = OpenAICompatibleStreamParser(
            provider: .openRouter,
            requestedModel: "test-model"
        )

        var allEvents: [AIStreamEvent] = []
        for line in streamText.components(separatedBy: .newlines) where !line.isEmpty {
            allEvents.append(contentsOf: try parser.parse(line: line))
        }

        return allEvents.compactMap { event -> AIRequestedToolCall? in
            if case let .toolCallCompleted(toolCall) = event {
                return toolCall
            }
            return nil
        }.first
    }
}
