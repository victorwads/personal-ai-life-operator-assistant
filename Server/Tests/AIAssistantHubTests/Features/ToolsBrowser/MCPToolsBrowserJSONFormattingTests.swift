import XCTest
@testable import AIAssistantHub

final class MCPToolsBrowserJSONFormattingTests: XCTestCase {
    func testPrettyPrintedResultIncludesStructuredValidationErrors() {
        let result = MCPToolExecutionResult.failure(
            toolName: "test_tool",
            error: .validationFailed([
                MCPToolValidationError(
                    message: "Missing required field \"issueId\".",
                    suggestedAction: "Provide the required field \"issueId\" before retrying the tool call.",
                    fieldPath: "issueId",
                    validatorName: "MCPRequiredFieldsValidator",
                    toolName: "test_tool"
                ),
                MCPToolValidationError(
                    message: "Missing required field \"text\".",
                    suggestedAction: "Provide the required field \"text\" before retrying the tool call.",
                    fieldPath: "text",
                    validatorName: "MCPRequiredFieldsValidator",
                    toolName: "test_tool"
                )
            ]),
            durationMilliseconds: 12.5
        )

        let rendered = MCPToolsBrowserJSONFormatting.prettyPrinted(result: result)

        XCTAssertTrue(rendered.contains("\"error\""))
        XCTAssertTrue(rendered.contains("\"validationFailed\""))
        XCTAssertTrue(rendered.contains("\"issueId\""))
        XCTAssertTrue(rendered.contains("\"text\""))
        XCTAssertTrue(rendered.contains("\"message\""))
        XCTAssertTrue(rendered.contains("\"suggestedAction\""))
    }

    func testPrettyPrintedSuccessPayloadReturnsPlainTextForStringPayload() {
        let rendered = MCPToolsBrowserJSONFormatting.prettyPrintedSuccessPayload(
            .string("Hello from the tool")
        )

        XCTAssertEqual(rendered, "Hello from the tool")
    }

    func testPrettyPrintedSuccessPayloadFormatsJSONStringPayload() {
        let rendered = MCPToolsBrowserJSONFormatting.prettyPrintedSuccessPayload(
            .string("{\"name\":\"Victor\",\"count\":2}")
        )

        XCTAssertEqual(
            rendered,
            """
            {
              "count" : 2,
              "name" : "Victor"
            }
            """
        )
    }

    func testPrettyPrintedSuccessPayloadFormatsStructuredJSONPayload() {
        let rendered = MCPToolsBrowserJSONFormatting.prettyPrintedSuccessPayload(
            .object([
                "name": .string("Victor"),
                "count": .int(2)
            ])
        )

        XCTAssertEqual(
            rendered,
            """
            {
              "count" : 2,
              "name" : "Victor"
            }
            """
        )
    }
}
