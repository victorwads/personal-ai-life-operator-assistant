import Foundation

@MainActor
final class IssuesFeature: FeatureRuntime {
    override class var id: String { "issues" }
    let repository: FirestoreIssueRepository
    let timelineRepository: FirestoreIssueTimelineRepository

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("IssuesFeature requires a persisted profile scope.")
        }

        let repository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)
        self.repository = repository
        self.timelineRepository = timelineRepository
        super.init(context: context)
        context.mcp.toolRegistry.register([
            CreateIssueTool(repository: repository),
            UpdateIssueTool(repository: repository, timelineRepository: timelineRepository),
            GetIssueTool(repository: repository, timelineRepository: timelineRepository),
            ListActiveIssuesTool(repository: repository),
            SuspendIssueTool(repository: repository, timelineRepository: timelineRepository),
            ResolveIssueTool(repository: repository, timelineRepository: timelineRepository),
            CancelIssueTool(repository: repository, timelineRepository: timelineRepository)
        ])
    }

    func validateIssueId(_ issueId: String) async throws -> Issue {
        try await repository.validateIssueId(issueId)
    }
}
