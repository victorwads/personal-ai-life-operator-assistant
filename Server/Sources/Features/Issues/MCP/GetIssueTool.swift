import Foundation

struct GetIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository

    init(repository: FirestoreIssueRepository, timelineRepository: FirestoreIssueTimelineRepository) {
        self.repository = repository
        self.timelineRepository = timelineRepository
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
        let timelineItems = try await timelineRepository.listItems(for: issue.id ?? id)

        return .object([
            "issue": IssueMCPToolSupport.issueObject(issue),
            "timelineItems": IssueMCPToolSupport.timelineItemsObject(timelineItems)
        ])
    }
}
