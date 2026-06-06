import XCTest
@testable import AIAssistantHub

final class AIConnectionConversationContextBuilderTests: XCTestCase {
    func testToolResultMessageIncludesPlainTextSections() {
        let result = AIToolExecutionResult(
            toolName: "update_issue",
            success: false,
            payload: .object(["status": .string("blocked")]),
            errorMessage: "Tool call rejected: validation failed.",
            suggestedAction: """
            Provide the required field "issueId" before retrying the tool call.
            Provide the required field "text" before retrying the tool call.
            """,
            validationErrors: [
                .init(
                    fieldPath: "issueId",
                    message: "Missing required field \"issueId\".",
                    suggestedAction: "Provide the required field \"issueId\" before retrying the tool call."
                ),
                .init(
                    fieldPath: "text",
                    message: "Missing required field \"text\".",
                    suggestedAction: "Provide the required field \"text\" before retrying the tool call."
                )
            ],
            durationMilliseconds: 12
        )

        let message = AIConnectionConversationContextBuilder().toolResultMessage(result: result)

        XCTAssertTrue(message.contains("Tool: update_issue"))
        XCTAssertTrue(message.contains("Status: failed"))
        XCTAssertTrue(message.contains("Payload:"))
        XCTAssertTrue(message.contains("```json"))
        XCTAssertTrue(message.contains("\"status\" : \"blocked\""))
        XCTAssertTrue(message.contains("Error: Tool call rejected: validation failed."))
        XCTAssertTrue(message.contains("Suggested Action:"))
        XCTAssertTrue(message.contains("Validation Errors:"))
        XCTAssertTrue(message.contains("Field: issueId"))
        XCTAssertTrue(message.contains("Field: text"))
    }
}
