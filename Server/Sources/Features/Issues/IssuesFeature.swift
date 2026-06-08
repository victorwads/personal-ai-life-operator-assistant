import Foundation
import SwiftUI

enum IssueListFilter: String, CaseIterable, Identifiable, Sendable {
    case active
    case suspended
    case resolved
    case cancelled
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .suspended:
            return "Suspended"
        case .resolved:
            return "Resolved"
        case .cancelled:
            return "Cancelled"
        case .all:
            return "All"
        }
    }
}

protocol IssueRelatedDataProviding {
    func listSensitiveDataUsageByIssueId(_ issueId: String) async throws -> [SensitiveDataUsage]
    func listSentMessagesByIssueId(_ issueId: String) async throws -> [SentMessage]
    func listClientInteractionRequestsByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest]
}

@MainActor
final class IssuesFeature: FeatureRuntime, IssueReferenceValidating, IssueRelatedDataProviding {
    override class var id: String { "issues" }
    let repository: FirestoreIssueRepository
    let timelineRepository: FirestoreIssueTimelineRepository
    let statusTransitionService: IssueStatusTransitionService

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("IssuesFeature requires a persisted profile scope.")
        }

        let dateProvider: () -> Date = { Date() }
        let repository = FirestoreIssueRepository(scope: scope, dateProvider: dateProvider)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope, dateProvider: dateProvider)
        let statusTransitionService = IssueStatusTransitionService(
            repository: repository,
            timelineRepository: timelineRepository,
            dateProvider: dateProvider
        )
        self.repository = repository
        self.timelineRepository = timelineRepository
        self.statusTransitionService = statusTransitionService
        super.init(context: context)
        context.mcp.toolRegistry.register([
            CreateIssueTool(repository: repository),
            UpdateIssueTool(repository: repository, timelineRepository: timelineRepository),
            GetIssueTool(
                repository: repository,
                timelineRepository: timelineRepository,
                sentMessagesProvider: { issueId in
                    try await context.feature(SentMessagesFeature.self).listByIssueId(issueId)
                },
                clientInteractionRequestsProvider: { issueId in
                    try await context.feature(ClientVoiceFeature.self).listByIssueId(issueId)
                },
                chatProvider: { chatId in
                    try await context.feature(ChatsFeature.self).repository.getChat(id: chatId)
                }
            ),
            ListActiveIssuesTool(repository: repository),
            SuspendIssueTool(repository: repository, timelineRepository: timelineRepository),
            ResolveIssueTool(repository: repository, timelineRepository: timelineRepository),
            CancelIssueTool(repository: repository, timelineRepository: timelineRepository)
        ])
    }

    func validateIssueId(_ issueId: String) async throws -> Issue {
        try await repository.validateIssueId(issueId)
    }

    func listIssues(filter: IssueListFilter) async throws -> [Issue] {
        switch filter {
        case .active:
            return try await repository.getActiveIssues()
                .filter { !$0.finished && $0.status != .suspended }
        case .suspended:
            return try await repository.listAllIssues()
                .filter { $0.status == .suspended }
        case .resolved:
            return try await repository.listAllIssues()
                .filter { $0.status == .resolved }
        case .cancelled:
            return try await repository.listAllIssues()
                .filter { $0.status == .cancelled }
        case .all:
            return try await repository.listAllIssues()
        }
    }

    func issue(id: String) async throws -> Issue? {
        try await repository.getById(id)
    }

    func makeIssueDetailWindowRequest(issueId: String) async throws -> FeatureWindowRequest {
        let issue = try await issue(id: issueId)
        let windowTitle = issue.map { "Issue: \($0.title)" } ?? "Issue: \(issueId)"

        return FeatureWindowRequest(
            id: "issue_\(issueId)",
            title: windowTitle,
            rootView: AnyView(
                IssueDetailWindowView(
                    issueId: issueId,
                    issuesFeature: self
                )
            )
        )
    }

    func listTimelineItems(issueId: String) async throws -> [IssueTimelineItem] {
        try await timelineRepository.listItems(for: issueId)
    }

    func listSensitiveDataUsageByIssueId(_ issueId: String) async throws -> [SensitiveDataUsage] {
        try await context.feature(SensitiveDataFeature.self).listUsageByIssueId(issueId)
    }

    func listSentMessagesByIssueId(_ issueId: String) async throws -> [SentMessage] {
        try await context.feature(SentMessagesFeature.self).listByIssueId(issueId)
    }

    func listClientInteractionRequestsByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest] {
        try await context.feature(ClientVoiceFeature.self).listByIssueId(issueId)
    }
}
