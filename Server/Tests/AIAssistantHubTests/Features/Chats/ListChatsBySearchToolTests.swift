import XCTest
@testable import AIAssistantHub

final class ListChatsBySearchToolTests: FirestoreIntegrationTestCase {
    func testExecuteReturnsTextualMatchesFromTitleAndLastMessagePreview() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-chats-by-search.json")

        let tool = ListChatsBySearchTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "whatsapp_list_chats_by_search", arguments: [
            "query": .string("leonardo"),
            "limit": .int(10)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(
            result,
            .string(
                """
                Status: 2 chats encontrados para "leonardo"

                1. Leonardo | chat-1
                2. Padaria da esquina | chat-2
                """
            )
        )
    }

    func testExecuteFallsBackToLatestTenChatsWhenNoMatchesAreFound() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-chats-by-search.json")

        let tool = ListChatsBySearchTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "whatsapp_list_chats_by_search", arguments: [
            "query": .string("zxywvu")
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(
            result,
            .string(
                """
                Status: nenhum chat encontrado para "zxywvu"

                Últimas 10 conversas:
                1. Leonardo | chat-1
                2. Padaria da esquina | chat-2
                3. Outros | chat-3
                4. Chat 4 | chat-4
                5. Chat 5 | chat-5
                6. Chat 6 | chat-6
                7. Chat 7 | chat-7
                8. Chat 8 | chat-8
                9. Chat 9 | chat-9
                10. Chat 10 | chat-10
                """
            )
        )
    }
}
