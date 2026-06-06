import Foundation

struct WaitingAgentPendingWorkProvider: PendingWorkProvider {
    private let repository: ClientInteractionRequestRepository
    private let issueTitleProvider: @MainActor (String) async throws -> String?

    init(
        repository: ClientInteractionRequestRepository,
        issueTitleProvider: @escaping @MainActor (String) async throws -> String?
    ) {
        self.repository = repository
        self.issueTitleProvider = issueTitleProvider
    }

    func pendingWorkSection() async throws -> PendingWorkSection? {
        let requests = try await repository.listRequests()
            .filter { $0.status == .waitingAgent }

        guard !requests.isEmpty else {
            return nil
        }

        var lines: [String] = []
        for request in requests {
            let issueIdText = request.issueId ?? "none"
            let issueTitle: String
            if let issueId = request.issueId {
                issueTitle = try await issueTitleProvider(issueId) ?? "Unknown issue"
            } else {
                issueTitle = "No issue linked"
            }
            let responseText = request.responseText ?? "(no response text)"
            lines.append(
                "issueId: \(issueIdText) | issueTitle: \(issueTitle) | prompt: \(request.promptText) | response: \(responseText)"
            )
        }

        for request in requests {
            guard let requestID = request.id else { continue }
            _ = try await repository.markCompleted(id: requestID)
        }

        return PendingWorkSection(
            title: "Client interaction requests waiting for agent",
            lines: lines
        )
    }
}
