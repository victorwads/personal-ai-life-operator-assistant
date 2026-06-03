import Foundation

struct ResolveIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository

    init(repository: FirestoreIssueRepository, timelineRepository: FirestoreIssueTimelineRepository) {
        self.repository = repository
        self.timelineRepository = timelineRepository
    }

    let name = "resolve_issue"
    let icon = "checkmark.seal"
    let description = "Marks an issue as resolved by id."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "resolutionDescription": .object(["type": .string("string")])
        ]),
        "required": .array([.string("id")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "id", value: .string("issue-1")),
        .init(name: "resolutionDescription", value: .string("Task completed and confirmed with the client."))
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

        issue.status = .resolved
        issue.finished = true
        let saved = try await repository.save(issue)
        let timelineItem: IssueTimelineItem?
        if let resolutionDescription = MCPSupport.optionalString("resolutionDescription", from: call) {
            timelineItem = try await timelineRepository.save(
                IssueTimelineItem(
                    id: nil,
                    issueId: saved.id ?? id,
                    kind: "resolved",
                    description: resolutionDescription
                )
            )
        } else {
            timelineItem = nil
        }

        var payload: [String: MCPJSONValue] = [
            "issue": IssueMCPToolSupport.issueObject(saved),
            "resolutionDescription": MCPSupport.optionalString("resolutionDescription", from: call).map(MCPJSONValue.string) ?? .null
        ]
        if let timelineItem {
            payload["timelineItem"] = IssueMCPToolSupport.timelineItemObject(timelineItem)
        }

        return .object(payload)
    }
}
