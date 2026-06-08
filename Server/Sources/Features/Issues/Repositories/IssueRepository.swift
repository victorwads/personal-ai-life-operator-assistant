import Foundation

protocol IssueRepository {
    func getActiveIssues() async throws -> [Issue]
    func listAllIssues() async throws -> [Issue]
    func getById(_ id: String) async throws -> Issue?
    func validateIssueId(_ issueId: String) async throws -> Issue
    func addRelatedChat(issueId: String, chatId: String) async throws
    func resolveIssue(issueId: String, reason: String) async throws
    func cancelIssue(issueId: String, reason: String) async throws
    func suspendIssue(issueId: String, suspendUntil: Date, reason: String?) async throws
    func reactivateIssue(issueId: String, reason: String) async throws
}

enum IssueRepositoryError: Error, LocalizedError {
    case issueNotFound(String)
    case issueFinished(String)
    case invalidReason(String)

    var errorDescription: String? {
        switch self {
        case .issueNotFound(let id):
            return "Issue not found: \(id)"
        case .issueFinished(let id):
            return "Issue is already finished: \(id)"
        case .invalidReason(let message):
            return message
        }
    }
}

final class FirestoreIssueRepository: FirestoreRepository<Issue> {
    init(
        scope: FirebaseProfileScope,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        super.init(
            entityName: "Issue",
            path: .profileScoped(scope: scope, collection: "Issues"),
            dateProvider: dateProvider
        )
    }

    func getActiveIssues() async throws -> [Issue] {
        try await query(
            matching: ["finished": false],
            sortedBy: [FirestoreRepositorySort(field: "_updatedAt", descending: true)]
        )
    }

    func listAllIssues() async throws -> [Issue] {
        try await query(
            sortedBy: [FirestoreRepositorySort(field: "_updatedAt", descending: true)]
        )
    }

    func validateIssueId(_ issueId: String) async throws -> Issue {
        guard let issue = try await getById(issueId) else {
            throw IssueRepositoryError.issueNotFound(issueId)
        }

// Causing too much problems, melhor ter um "prazo" de quanto tempo usar um issue finalizado do que bloquear
//        guard !issue.finished else {
//            throw IssueRepositoryError.issueFinished(issueId)
//        }

        return issue
    }

    func addRelatedChat(issueId: String, chatId: String) async throws {
        guard let issue = try await getById(issueId) else {
            throw IssueRepositoryError.issueNotFound(issueId)
        }

        let trimmedChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChatId.isEmpty else {
            return
        }

        var relatedChatIds = issue.relatedChatIds ?? []
        guard relatedChatIds.contains(trimmedChatId) == false else {
            return
        }

        relatedChatIds.append(trimmedChatId)
        try await update(
            id: issueId,
            data: ["relatedChatIds": relatedChatIds]
        )
    }

    func resolveIssue(issueId: String, reason: String) async throws {
        try await updateIssue(
            issueId: issueId,
            reason: reason,
            status: .resolved,
            finished: true,
            suspendUntil: nil
        )
    }

    func cancelIssue(issueId: String, reason: String) async throws {
        try await updateIssue(
            issueId: issueId,
            reason: reason,
            status: .cancelled,
            finished: true,
            suspendUntil: nil
        )
    }

    func suspendIssue(issueId: String, suspendUntil: Date, reason: String?) async throws {
        try await updateIssue(
            issueId: issueId,
            reason: reason,
            status: .suspended,
            finished: false,
            suspendUntil: suspendUntil
        )
    }

    func reactivateIssue(issueId: String, reason: String) async throws {
        try await updateIssue(
            issueId: issueId,
            reason: reason,
            status: .pending,
            finished: false,
            suspendUntil: nil
        )
    }

    private func updateIssue(
        issueId: String,
        reason: String?,
        status: IssueStatus,
        finished: Bool,
        suspendUntil: Date?
    ) async throws {
        guard let _ = try await getById(issueId) else {
            throw IssueRepositoryError.issueNotFound(issueId)
        }

        if let reason {
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty, status != .suspended {
                throw IssueRepositoryError.invalidReason("Reason is required.")
            }
        } else if status != .suspended {
            throw IssueRepositoryError.invalidReason("Reason is required.")
        }

        var payload: [String: Any] = [
            "status": status.rawValue,
            "finished": finished
        ]

        if suspendUntil == nil {
            payload["suspendUntil"] = NSNull()
        } else {
            payload["suspendUntil"] = suspendUntil
        }

        try await update(id: issueId, data: payload)
    }
}

extension FirestoreIssueRepository: IssueRepository {}
