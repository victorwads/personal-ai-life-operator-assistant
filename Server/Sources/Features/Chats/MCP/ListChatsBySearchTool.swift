import Foundation

struct ListChatsBySearchTool: MCPToolDefinition {
    private static let defaultLimit = 10
    private static let fallbackLimit = 10

    private let repository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode

    init(
        repository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode
    ) {
        self.repository = repository
        self.permissionModeProvider = permissionModeProvider
    }

    let name = "whatsapp_list_chats_by_search"
    let icon = "magnifyingglass"
    let description = "Searches chats by title or last message preview using a simple similarity score."
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object(["type": .string("string")]),
            "limit": .object(["type": .string("number")])
        ]),
        "required": .array([.string("query")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("Leonardo")),
        .init(name: "limit", value: .integer(Self.defaultLimit))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let query = try MCPSupport.string("query", from: call)
        let limit = MCPSupport.optionalLimit(from: call, default: Self.defaultLimit)
        let mode = await permissionModeProvider()
        let allowedChats = try await repository.listChats()
            .filter { ChatPermissionResolver.isChatAllowed($0, mode: mode) }

        let matches = rankedMatches(in: allowedChats, query: query)
        if !matches.isEmpty {
            let limitedMatches = Array(matches.prefix(limit)).map(\.chat)
            return .string(renderMatches(limitedMatches, query: query))
        }

        return .string(renderFallback(
            query: query,
            latestChats: Array(allowedChats.prefix(Self.fallbackLimit))
        ))
    }

    private func rankedMatches(
        in chats: [Chat],
        query: String
    ) -> [RankedChat] {
        chats
            .enumerated()
            .compactMap { index, chat in
                let score = max(
                    TextSimilarity.score(query: query, text: chat.title),
                    TextSimilarity.score(query: query, text: chat.lastMessagePreview)
                )
                guard score > 0 else { return nil }
                return RankedChat(index: index, chat: chat, score: score)
            }
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return left.index < right.index
            }
    }

    private func renderMatches(_ chats: [Chat], query: String) -> String {
        let listing = chats.enumerated().map { index, chat in
            "\(index + 1). \(chat.title) | \(chat.id ?? "")"
        }.joined(separator: "\n")

        return """
        Status: \(chats.count) chats encontrados para "\(query)"

        \(listing)
        """
    }

    private func renderFallback(query: String, latestChats: [Chat]) -> String {
        if latestChats.isEmpty {
            return """
            Status: nenhum chat encontrado para "\(query)"

            Últimas 10 conversas:
            Nenhuma conversa disponível.
            """
        }

        let listing = latestChats.enumerated().map { index, chat in
            "\(index + 1). \(chat.title) | \(chat.id ?? "")"
        }.joined(separator: "\n")

        return """
        Status: nenhum chat encontrado para "\(query)"

        Últimas 10 conversas:
        \(listing)
        """
    }
}

private struct RankedChat {
    let index: Int
    let chat: Chat
    let score: Double
}
