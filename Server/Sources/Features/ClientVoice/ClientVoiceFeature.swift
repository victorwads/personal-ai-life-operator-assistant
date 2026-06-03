import Foundation

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }

    let repository: FirestoreClientInteractionRequestRepository
    let presenceService: ClientVoicePresenceService

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ClientVoiceFeature requires a persisted profile scope.")
        }

        repository = FirestoreClientInteractionRequestRepository(scope: scope)
        presenceService = ClientVoicePresenceService(
            repository: RealtimeDatabaseClientVoicePresenceRepository(scope: scope)
        )
        super.init(context: context)

        context.status.statusRegistry.register(
            ClientVoicePresenceStatusProvider(presenceService: presenceService)
        )

        context.mcp.toolRegistry.register([
            SpeakToClientTool(
                repository: repository,
                sharedLocks: context.sharedLocks,
                isClientPresentProvider: { [presenceService] in presenceService.isPresent }
            ),
            AskToClientTool(
                repository: repository,
                sharedLocks: context.sharedLocks,
                isClientPresentProvider: { [presenceService] in presenceService.isPresent }
            )
        ])
    }

    override func onStartServices() async {
        await presenceService.start()
    }

    override func onStopServices() async {
        await presenceService.stop()
    }

    func listByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest] {
        try await repository.listRequests(issueId: issueId)
    }
}
