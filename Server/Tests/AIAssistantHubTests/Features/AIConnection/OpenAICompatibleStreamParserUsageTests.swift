import XCTest
@testable import AIAssistantHub

final class OpenAICompatibleStreamParserUsageTests: XCTestCase {
    func testParserEmitsReasoningAndCachedTokenUsage() throws {
        var parser = OpenAICompatibleStreamParser(
            provider: .openRouter,
            requestedModel: "test-model"
        )

        let line = """
        data: {"id":"chatcmpl-1","model":"test-model","choices":[],"usage":{"prompt_tokens":111,"completion_tokens":22,"total_tokens":133,"completion_tokens_details":{"reasoning_tokens":7},"prompt_tokens_details":{"cached_tokens":9}}}
        """

        let events = try parser.parse(line: line)
        let usage = try XCTUnwrap(events.compactMap { event -> AIUsage? in
            if case let .usage(usage) = event { return usage }
            return nil
        }.first)

        XCTAssertEqual(usage.promptTokens, 111)
        XCTAssertEqual(usage.completionTokens, 22)
        XCTAssertEqual(usage.reasoningTokens, 7)
        XCTAssertEqual(usage.totalTokens, 133)
        XCTAssertEqual(usage.cachedInputTokens, 9)
    }
}
