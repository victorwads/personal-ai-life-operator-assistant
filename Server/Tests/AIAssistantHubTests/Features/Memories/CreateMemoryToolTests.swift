import XCTest
@testable import AIAssistantHub

final class CreateMemoryToolTests: FirestoreIntegrationTestCase {
    func testExecuteUpdatesExistingKeyInsteadOfCreatingDuplicate() async throws {
        let repository = FirestoreMemoryRepository(scope: scope)
        let tool = CreateMemoryTool(repository: repository)

        _ = try await tool.execute(
            MCPToolCall(name: "create_memory", arguments: [
                "key": .string("client_language"),
                "value": .string("Portuguese")
            ]),
            context: MCPServerContext()
        )

        _ = try await tool.execute(
            MCPToolCall(name: "create_memory", arguments: [
                "key": .string("client_language"),
                "value": .string("English")
            ]),
            context: MCPServerContext()
        )

        let persistedMemories = try await repository.query(
            matching: ["key": "client_language"]
        )

        XCTAssertEqual(persistedMemories.count, 1)
        XCTAssertEqual(persistedMemories.first?.value, "English")
    }
}
