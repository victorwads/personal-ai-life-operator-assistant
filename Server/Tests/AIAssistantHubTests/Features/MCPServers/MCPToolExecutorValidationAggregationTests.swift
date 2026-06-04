import XCTest
@testable import AIAssistantHub

final class MCPToolExecutorValidationAggregationTests: XCTestCase {
    func testExecuteReturnsAllMissingRequiredFieldErrors() async {
        let executor = MCPToolExecutor(
            registry: MCPToolRegistry(definitions: [ValidationAggregationTestTool()]),
            validators: [
                MCPRequiredFieldsValidator(),
                MCPUnknownFieldsValidator(),
                MCPArgumentTypeValidator(),
                MCPEnumValidator()
            ]
        )

        let result = await executor.execute(
            MCPToolCall(name: "validation_aggregation_test_tool", arguments: [:])
        )

        XCTAssertFalse(result.success)

        guard case let .validationFailed(errors)? = result.error else {
            return XCTFail("Expected validationFailed error, got \(String(describing: result.error)).")
        }

        XCTAssertEqual(errors.count, 3)
        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["issueId", "text", "reason"]))
        XCTAssertTrue(errors.contains { $0.fieldPath == "issueId" && $0.message.contains("Missing required field") })
        XCTAssertTrue(errors.contains { $0.fieldPath == "text" && $0.message.contains("Missing required field") })
        XCTAssertTrue(errors.contains { $0.fieldPath == "reason" && $0.message.contains("Missing required field") })

        let message = result.error?.localizedDescription ?? ""
        XCTAssertTrue(message.contains("issueId"))
        XCTAssertTrue(message.contains("text"))
        XCTAssertTrue(message.contains("reason"))
    }

    func testCreateIssueEmptyRequiredStringsReturnAllValidationErrors() async {
        let executor = MCPToolExecutor(
            registry: MCPToolRegistry(definitions: [
                CreateIssueValidationTestTool()
            ]),
            validators: [
                MCPRequiredFieldsValidator(),
                MCPUnknownFieldsValidator(),
                MCPArgumentTypeValidator(),
                MCPEnumValidator()
            ]
        )

        let result = await executor.execute(
            MCPToolCall(
                name: "create_issue",
                arguments: [
                    "title": .string(""),
                    "description": .string(""),
                    "initialRequest": .string(""),
                    "resolutionCondition": .string(""),
                    "priority": .int(3)
                ]
            )
        )

        XCTAssertFalse(result.success)

        guard case let .validationFailed(errors)? = result.error else {
            return XCTFail("Expected validationFailed error, got \(String(describing: result.error)).")
        }

        XCTAssertEqual(errors.count, 4)
        XCTAssertEqual(
            Set(errors.map(\.fieldPath)),
            Set(["title", "description", "initialRequest", "resolutionCondition"])
        )
        XCTAssertTrue(errors.allSatisfy { $0.message.contains("must not be empty") })
    }
}

private struct CreateIssueValidationTestTool: MCPToolDefinition {
    let name = "create_issue"
    let icon = "folder.badge.plus"
    let description = "Creates a new operational issue."
    let group = "issues"
    let traits: [MCPToolTrait] = [.writesState]
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object(["type": .string("string")]),
            "description": .object(["type": .string("string")]),
            "initialRequest": .object(["type": .string("string")]),
            "resolutionCondition": .object(["type": .string("string")]),
            "priority": .object(["type": .string("number")])
        ]),
        "required": .array([
            .string("title"),
            .string("description"),
            .string("initialRequest"),
            .string("resolutionCondition")
        ])
    ])
}

private struct ValidationAggregationTestTool: MCPToolDefinition {
    let name = "validation_aggregation_test_tool"
    let icon = "exclamationmark.triangle"
    let description = "Test tool for validating aggregated MCP validation failures."
    let group = "Tests"
    let traits: [MCPToolTrait] = []
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object([
                "type": .string("string")
            ]),
            "text": .object([
                "type": .string("string")
            ]),
            "reason": .object([
                "type": .string("string")
            ])
        ]),
        "required": .array([
            .string("issueId"),
            .string("text"),
            .string("reason")
        ])
    ])
}
