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
                    similarityScore(query: query, text: chat.title),
                    similarityScore(query: query, text: chat.lastMessagePreview)
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

    private func similarityScore(query: String, text: String?) -> Double {
        guard let text else { return 0 }

        let normalizedQuery = normalizedSearchText(query)
        let normalizedText = normalizedSearchText(text)
        guard !normalizedQuery.isEmpty, !normalizedText.isEmpty else {
            return 0
        }

        if normalizedText.contains(normalizedQuery) {
            return 1
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty else {
            return 0
        }

        let textTokens = Set(normalizedText.split(separator: " ").map(String.init))
        let matchedTokens = queryTokens.filter { queryToken in
            textTokens.contains(where: { textToken in
                textToken == queryToken || textToken.contains(queryToken) || queryToken.contains(textToken)
            })
        }.count

        return Double(matchedTokens) / Double(queryTokens.count)
    }

    private func normalizedSearchText(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        let normalizedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(normalizedScalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RankedChat {
    let index: Int
    let chat: Chat
    let score: Double
}
