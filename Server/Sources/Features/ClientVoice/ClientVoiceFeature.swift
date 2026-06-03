import Foundation

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }

    let repository: FirestoreClientInteractionRequestRepository

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ClientVoiceFeature requires a persisted profile scope.")
        }

        repository = FirestoreClientInteractionRequestRepository(scope: scope)
        super.init(context: context)

        context.mcp.toolRegistry.register([
            SpeakToClientTool(repository: repository, sharedLocks: context.sharedLocks),
            AskToClientTool(repository: repository, sharedLocks: context.sharedLocks)
        ])
    }

    func listByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest] {
        try await repository.listRequests(issueId: issueId)
    }
}
