import Foundation

struct GetIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository
    private let sentMessagesProvider: (String) async throws -> [SentMessage]
    private let clientInteractionRequestsProvider: (String) async throws -> [ClientInteractionRequest]
    private let chatProvider: (String) async throws -> Chat?

    init(
        repository: FirestoreIssueRepository,
        timelineRepository: FirestoreIssueTimelineRepository,
        sentMessagesProvider: @escaping (String) async throws -> [SentMessage],
        clientInteractionRequestsProvider: @escaping (String) async throws -> [ClientInteractionRequest],
        chatProvider: @escaping (String) async throws -> Chat?
    ) {
        self.repository = repository
        self.timelineRepository = timelineRepository
        self.sentMessagesProvider = sentMessagesProvider
        self.clientInteractionRequestsProvider = clientInteractionRequestsProvider
        self.chatProvider = chatProvider
    }

    let name = "get_issue"
    let icon = "folder"
    let description = "Fetches an issue by id."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")])
        ]),
        "required": .array([.string("id")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "id", value: .string("issue-1"))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let id = try MCPSupport.string("id", from: call)
        guard let issue = try await repository.getById(id) else {
            throw IssueMCPToolError.issueNotFound(id)
        }

        async let timelineItems = timelineRepository.listItems(for: issue.id ?? id)
        async let sentMessages = sentMessagesProvider(id)
        async let clientInteractionRequests = clientInteractionRequestsProvider(id)
        async let relatedChats = loadRelatedChats(for: issue)
        let relatedData = try await IssueMCPToolSupport.DetailedIssueData(
            timelineItems: timelineItems,
            relatedChats: relatedChats,
            sentMessages: sentMessages,
            clientInteractionRequests: clientInteractionRequests
        )

        return IssueMCPToolSupport.detailedIssueText(
            issue: issue,
            relatedData: relatedData
        )
    }

    private func loadRelatedChats(for issue: Issue) async throws -> [IssueMCPToolSupport.RelatedChatSummary] {
        let relatedChatIds = issue.relatedChatIds ?? []
        var chats: [IssueMCPToolSupport.RelatedChatSummary] = []

        for chatId in relatedChatIds {
            let chat = try await chatProvider(chatId)
            chats.append(.init(id: chatId, title: chat?.title))
        }

        return chats
    }
}
