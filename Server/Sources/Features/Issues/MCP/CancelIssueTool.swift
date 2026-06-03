import Foundation

struct CancelIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository

    init(repository: FirestoreIssueRepository, timelineRepository: FirestoreIssueTimelineRepository) {
        self.repository = repository
        self.timelineRepository = timelineRepository
    }

    let name = "cancel_issue"
    let icon = "xmark.circle"
    let description = "Marks an issue as canceled by id."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")])
        ]),
        "required": .array([.string("id")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "id", value: .string("issue-1")),
        .init(name: "reason", value: .string("The request is no longer needed."))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let id = try MCPSupport.string("id", from: call)
        guard var issue = try await repository.getById(id) else {
            throw IssueMCPToolError.issueNotFound(id)
        }

        issue.status = .cancelled
        issue.finished = true
        let saved = try await repository.save(issue)
        let timelineItem: IssueTimelineItem?
        if let reason = MCPSupport.optionalString("reason", from: call) {
            timelineItem = try await timelineRepository.save(
                IssueTimelineItem(
                    id: nil,
                    issueId: saved.id ?? id,
                    kind: "cancelled",
                    description: reason
                )
            )
        } else {
            timelineItem = nil
        }

        var payload: [String: MCPJSONValue] = [
            "issue": IssueMCPToolSupport.issueObject(saved),
            "reason": MCPSupport.optionalString("reason", from: call).map(MCPJSONValue.string) ?? .null
        ]
        if let timelineItem {
            payload["timelineItem"] = IssueMCPToolSupport.timelineItemObject(timelineItem)
        }

        return .object(payload)
    }
}
