import XCTest
@testable import AIAssistantHub

final class ListActiveIssuesToolTests: FirestoreIntegrationTestCase {
    func testExecuteReturnsPlainTextIssueBlocksWithTruncatedDescriptions() async throws {
        try await fixtureBuilder.importFixture(named: "issue-mcp-related-data.json")

        let repository = FirestoreIssueRepository(scope: scope)
        let tool = ListActiveIssuesTool(repository: repository)

        let result = try await tool.execute(
            MCPToolCall(name: "list_active_issues", arguments: [:]),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string(
                """
                <issue id="issue-xml-2">
                <title>Prepare renewal summary</title>
                <description>Summarize the renewal terms before the Friday meeting.</description>
                </issue>

                <issue id="issue-xml-1">
                <title>Escalate billing mismatch</title>
                <description>Client says the invoice total does not match the signed proposal and wants a corrected amount before paying. Addition...</description>
                </issue>
                """
            )
        )
    }
}
