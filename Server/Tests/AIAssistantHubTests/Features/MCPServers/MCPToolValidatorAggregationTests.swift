import XCTest
@testable import AIAssistantHub

final class MCPToolValidatorAggregationTests: XCTestCase {
    func testRequiredFieldsValidatorReturnsOneErrorPerMissingRequiredField() async {
        let errors = await validationErrors(
            from: MCPRequiredFieldsValidator(),
            arguments: [
                "requiredText": .string("present")
            ]
        )

        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["requiredNumber", "requiredReason"]))
        XCTAssertTrue(errors.allSatisfy { $0.validatorName == "MCPRequiredFieldsValidator" })
    }

    func testRequiredFieldsValidatorReturnsOneErrorPerEmptyRequiredString() async {
        let errors = await validationErrors(
            from: MCPRequiredFieldsValidator(),
            arguments: [
                "requiredText": .string(""),
                "requiredReason": .string("   \n"),
                "requiredNumber": .int(3)
            ]
        )

        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["requiredText", "requiredReason"]))
        XCTAssertTrue(errors.allSatisfy { $0.message.contains("must not be empty") })
    }

    func testArgumentTypeValidatorReturnsOneErrorPerInvalidFieldType() async {
        let errors = await validationErrors(
            from: MCPArgumentTypeValidator(),
            arguments: [
                "requiredText": .int(1),
                "requiredReason": .bool(false),
                "requiredNumber": .string("high")
            ]
        )

        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["requiredText", "requiredReason", "requiredNumber"]))
        XCTAssertTrue(errors.allSatisfy { $0.validatorName == "MCPArgumentTypeValidator" })
    }

    func testEnumValidatorReturnsOneErrorPerInvalidEnumField() async {
        let errors = await validationErrors(
            from: MCPEnumValidator(),
            arguments: [
                "status": .string("paused"),
                "kind": .string("external"),
                "requiredText": .string("present")
            ]
        )

        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["status", "kind"]))
        XCTAssertTrue(errors.allSatisfy { $0.validatorName == "MCPEnumValidator" })
    }

    func testUnknownFieldsValidatorReturnsOneErrorPerUnknownField() async {
        let errors = await validationErrors(
            from: MCPUnknownFieldsValidator(),
            arguments: [
                "requiredText": .string("present"),
                "extraOne": .string("unknown"),
                "extraTwo": .int(2)
            ]
        )

        XCTAssertEqual(Set(errors.map(\.fieldPath)), Set(["extraOne", "extraTwo"]))
        XCTAssertTrue(errors.allSatisfy { $0.validatorName == "MCPUnknownFieldsValidator" })
    }

    func testIssueIdValidatorReturnsEmptyIssueIdErrorBeforeRepositoryLookup() async {
        let issueValidator = IssueIdValidatorTestDouble()
        let validator = MCPIssueIdValidator(issueValidator: { issueValidator })

        let errors = await validationErrors(
            from: validator,
            arguments: [
                "issueId": .string("   ")
            ]
        )

        XCTAssertEqual(errors.map(\.fieldPath), ["issueId"])
        let validatedIssueIds = await issueValidator.validatedIssueIds
        XCTAssertEqual(validatedIssueIds, [])
        XCTAssertTrue(errors.first?.message.contains("non-empty string") == true)
    }

    func testIssueIdValidatorReturnsInvalidIssueIdError() async {
        let issueValidator = IssueIdValidatorTestDouble(error: IssueIdValidatorTestError.invalid)
        let validator = MCPIssueIdValidator(issueValidator: { issueValidator })

        let errors = await validationErrors(
            from: validator,
            arguments: [
                "issueId": .string("ISSUE-404")
            ]
        )

        XCTAssertEqual(errors.map(\.fieldPath), ["issueId"])
        let validatedIssueIds = await issueValidator.validatedIssueIds
        XCTAssertEqual(validatedIssueIds, ["ISSUE-404"])
        XCTAssertTrue(errors.first?.message.contains("Invalid or inactive issueId") == true)
    }

    private func validationErrors(
        from validator: any MCPToolCallValidator,
        arguments: [String: MCPJSONValue],
        definition: any MCPToolDefinition = ValidatorAggregationTestTool()
    ) async -> [MCPToolValidationError] {
        let result = await validator.validate(
            call: MCPToolCall(name: definition.name, arguments: arguments),
            definition: definition,
            context: MCPToolValidationContext(serverContext: MCPServerContext())
        )

        guard case .failure(let errors) = result else {
            return []
        }

        return errors
    }
}

private struct ValidatorAggregationTestTool: MCPToolDefinition {
    let name = "validator_aggregation_test_tool"
    let icon = "checkmark.shield"
    let description = "Test tool for MCP validator aggregation."
    let group = "Tests"
    let traits: [MCPToolTrait] = []
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "requiredText": .object(["type": .string("string")]),
            "requiredReason": .object(["type": .string("string")]),
            "requiredNumber": .object(["type": .string("number")]),
            "status": .object([
                "type": .string("string"),
                "enum": .array([.string("open"), .string("closed")])
            ]),
            "kind": .object([
                "type": .string("string"),
                "enum": .array([.string("bug"), .string("task")])
            ]),
            "issueId": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("requiredText"),
            .string("requiredReason"),
            .string("requiredNumber")
        ])
    ])
}

private actor IssueIdValidatorTestDouble: IssueReferenceValidating {
    private let error: Error?
    private(set) var validatedIssueIds: [String] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func validateIssueId(_ issueId: String) async throws -> Issue {
        validatedIssueIds.append(issueId)

        if let error {
            throw error
        }

        return Issue(
            id: issueId,
            title: "Issue",
            description: "Description",
            initialRequest: "Initial request",
            resolutionCondition: "Done",
            priority: .medium,
            status: .pending,
            finished: false,
            suspendUntil: nil
        )
    }
}

private enum IssueIdValidatorTestError: Error {
    case invalid
}
