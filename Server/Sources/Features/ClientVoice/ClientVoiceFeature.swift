import Foundation

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }
    private static let presenceServiceId = "voice.client.presence"

    let repository: FirestoreClientInteractionRequestRepository
    let presenceService: VoiceClientPresenceService

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ClientVoiceFeature requires a persisted profile scope.")
        }

        self.repository = FirestoreClientInteractionRequestRepository(scope: scope)
        self.presenceService = VoiceClientPresenceService(
            id: Self.presenceServiceId,
            title: "Client Presence"
        )
        super.init(context: context)

        context.services.serviceRegistry.register(presenceService)
        context.status.statusRegistry.register(
            VoiceClientPresenceRuntimeStatusProvider(presenceService: presenceService)
        )

        context.mcp.toolRegistry.register([
            SpeakToClientTool(),
            AskToClientTool()
        ])
    }

    func listByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest] {
        try await repository.listRequests(issueId: issueId)
    }
}
