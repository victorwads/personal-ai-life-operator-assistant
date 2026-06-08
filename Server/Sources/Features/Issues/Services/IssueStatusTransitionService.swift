import Foundation

@MainActor
final class IssueStatusTransitionService {
    private let repository: IssueRepository
    private let timelineRepository: IssueTimelineSaving
    private let dateProvider: () -> Date

    init(
        repository: IssueRepository,
        timelineRepository: IssueTimelineSaving,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.timelineRepository = timelineRepository
        self.dateProvider = dateProvider
    }

    func resolveIssue(issueId: String, reason: String) async throws {
        let trimmedReason = try requireReason(reason)
        let issue = try await loadIssue(issueId)
        try requireTransition(
            action: "Resolve",
            issue: issue,
            allowedStatuses: [.pending, .suspended]
        )

        try await repository.resolveIssue(issueId: issueId, reason: trimmedReason)
        try await appendTimelineItem(
            issueId: issueId,
            kind: "issueResolved",
            description: trimmedReason,
            reason: trimmedReason,
            previousStatus: issue.status
        )
    }

    func cancelIssue(issueId: String, reason: String) async throws {
        let trimmedReason = try requireReason(reason)
        let issue = try await loadIssue(issueId)
        try requireTransition(
            action: "Cancel",
            issue: issue,
            allowedStatuses: [.pending, .suspended]
        )

        try await repository.cancelIssue(issueId: issueId, reason: trimmedReason)
        try await appendTimelineItem(
            issueId: issueId,
            kind: "issueCancelled",
            description: trimmedReason,
            reason: trimmedReason,
            previousStatus: issue.status
        )
    }

    func suspendIssue(issueId: String, suspendUntil: Date, reason: String?) async throws {
        let issue = try await loadIssue(issueId)
        try requireTransition(
            action: "Suspend",
            issue: issue,
            allowedStatuses: [.pending]
        )
        try requireFutureDate(suspendUntil)

        let trimmedReason = trimmedOptionalReason(reason)
        try await repository.suspendIssue(
            issueId: issueId,
            suspendUntil: suspendUntil,
            reason: trimmedReason
        )
        try await appendTimelineItem(
            issueId: issueId,
            kind: "issueSuspended",
            description: trimmedReason ?? "Suspended until \(suspendUntil.formatted(date: .abbreviated, time: .shortened))",
            reason: trimmedReason,
            suspendUntil: suspendUntil,
            previousStatus: issue.status
        )
    }

    func reactivateIssue(issueId: String, reason: String) async throws {
        let trimmedReason = try requireReason(reason)
        let issue = try await loadIssue(issueId)
        try requireTransition(
            action: "Reactivate",
            issue: issue,
            allowedStatuses: [.resolved, .cancelled, .suspended]
        )

        try await repository.reactivateIssue(issueId: issueId, reason: trimmedReason)
        try await appendTimelineItem(
            issueId: issueId,
            kind: "issueReactivated",
            description: trimmedReason,
            reason: trimmedReason,
            previousStatus: issue.status
        )
    }

    private func loadIssue(_ issueId: String) async throws -> Issue {
        guard let issue = try await repository.getById(issueId) else {
            throw IssueStatusTransitionError.issueNotFound(issueId)
        }

        return issue
    }

    private func requireReason(_ reason: String) throws -> String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IssueStatusTransitionError.reasonRequired
        }
        return trimmed
    }

    private func trimmedOptionalReason(_ reason: String?) -> String? {
        guard let reason else {
            return nil
        }

        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func requireFutureDate(_ date: Date) throws {
        guard date > dateProvider() else {
            throw IssueStatusTransitionError.suspendUntilMustBeFuture
        }
    }

    private func requireTransition(
        action: String,
        issue: Issue,
        allowedStatuses: [IssueStatus]
    ) throws {
        guard allowedStatuses.contains(issue.status) else {
            throw IssueStatusTransitionError.invalidTransition(
                action: action,
                currentStatus: issue.status
            )
        }
    }

    private func appendTimelineItem(
        issueId: String,
        kind: String,
        description: String,
        reason: String?,
        suspendUntil: Date? = nil,
        previousStatus: IssueStatus? = nil
    ) async throws {
        _ = try await timelineRepository.save(
            IssueTimelineItem(
                id: nil,
                issueId: issueId,
                kind: kind,
                description: description,
                reason: reason,
                changedAt: dateProvider(),
                previousStatus: previousStatus,
                suspendUntil: suspendUntil
            )
        )
    }
}

enum IssueStatusTransitionError: Error, LocalizedError {
    case issueNotFound(String)
    case reasonRequired
    case suspendUntilMustBeFuture
    case invalidTransition(action: String, currentStatus: IssueStatus)

    var errorDescription: String? {
        switch self {
        case .issueNotFound(let id):
            return "Issue not found: \(id)"
        case .reasonRequired:
            return "Reason is required."
        case .suspendUntilMustBeFuture:
            return "Suspend until must be in the future."
        case .invalidTransition(let action, let currentStatus):
            return "\(action) is not available for \(currentStatus.displayTitle) issues."
        }
    }
}

private extension IssueStatus {
    var displayTitle: String {
        switch self {
        case .pending:
            return "active"
        case .suspended:
            return "suspended"
        case .resolved:
            return "resolved"
        case .cancelled:
            return "cancelled"
        }
    }
}
