import Foundation
import SwiftUI

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }
    private static let workerServiceId = "client.voice.worker"
    private static let manualClientPromptText = "Eu vi que voce me chamou, o que voce precisa?"

    let repository: FirestoreClientInteractionRequestRepository
    let settings: ClientVoiceSettingsWrapper
    let presenceService: ClientVoicePresenceService
    let workerService: ClientVoiceWorkerService

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ClientVoiceFeature requires a persisted profile scope.")
        }

        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let settings = ClientVoiceSettingsWrapper(settings: context.settings.store)
        let presenceService = ClientVoicePresenceService(
            repository: RealtimeDatabaseClientVoicePresenceRepository(scope: scope)
        )
        let workerService = ClientVoiceWorkerService(
            id: Self.workerServiceId,
            title: "Voice Worker",
            repository: repository,
            sharedLocks: context.sharedLocks,
            presenceService: presenceService,
            presentAskDialog: { request, speakHandler in
                Self.openAskDialog(
                    request: request,
                    repository: repository,
                    featureWindows: context.featureWindows,
                    speakHandler: speakHandler,
                    listenConfig: settings.speechRecognitionListenConfig,
                    onSubmitSuccess: {
                        if let requestID = request.id {
                            await context.sharedLocks.unlock(id: "ask_to_client:\(requestID)")
                        }
                    },
                    onCloseWithoutResponse: {
                        if let requestID = request.id {
                            await context.sharedLocks.unlock(id: "ask_to_client:\(requestID)")
                        }
                    }
                )
            }
        )
        self.repository = repository
        self.settings = settings
        self.presenceService = presenceService
        self.workerService = workerService
        super.init(context: context)

        context.settings.sectionRegistry.register(
            ClientVoiceSettingsSectionProvider(wrapper: settings)
        )
        context.services.serviceRegistry.register(workerService)

        context.status.statusRegistry.register(
            ClientVoicePresenceStatusProvider(presenceService: presenceService)
        )
        context.status.statusRegistry.register(
            ClientVoiceWorkerStatusProvider(workerService: workerService)
        )

        context.mcp.toolRegistry.register([
            AnnounceToClientTool(
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
        if settings.workerAutoStart {
            await workerService.start()
        }
    }

    override func onStopServices() async {
        await presenceService.stop()
        await workerService.stop()
    }

    func listByIssueId(_ issueId: String) async throws -> [ClientInteractionRequest] {
        try await repository.listRequests(issueId: issueId)
    }

    func openAnswerDialog(for request: ClientInteractionRequest) {
        Self.openAskDialog(
            request: request,
            repository: repository,
            featureWindows: context.featureWindows,
            speakHandler: CompletedSpeechSpeakHandler(),
            listenConfig: settings.speechRecognitionListenConfig,
            onSubmitSuccess: {
                if let requestID = request.id {
                    await self.context.sharedLocks.unlock(id: "ask_to_client:\(requestID)")
                }
            },
            onCloseWithoutResponse: {
                if let requestID = request.id {
                    await self.context.sharedLocks.unlock(id: "ask_to_client:\(requestID)")
                }
            }
        )
    }

    func openNewManualRequestDialog() async throws {
        let request = try await repository.createRequest(
            issueId: nil,
            kind: .ask,
            status: .waitingUser,
            promptText: Self.manualClientPromptText
        )
        Self.openAskDialog(
            request: request,
            repository: repository,
            featureWindows: context.featureWindows,
            speakHandler: CompletedSpeechSpeakHandler(),
            listenConfig: settings.speechRecognitionListenConfig,
            onSubmitSuccess: {
                await self.context.sharedLocks.unlock(id: SharedLockIDs.globalEvent)
            },
            onCloseWithoutResponse: {}
        )
    }

    private static func openAskDialog(
        request: ClientInteractionRequest,
        repository: ClientInteractionRequestRepository,
        featureWindows: FeatureWindowsContext,
        speakHandler: SpeechSpeakHandler,
        listenConfig: ListenConfig,
        onSubmitSuccess: @escaping @MainActor () async -> Void,
        onCloseWithoutResponse: @escaping @MainActor () async -> Void
    ) {
        guard let requestID = request.id else { return }

        let windowID = "client_voice_ask_\(requestID)"
        let closeWindow = {
            featureWindows.hide(windowID)
        }
        let viewModel = ClientVoiceAskDialogViewModel(
            repository: repository,
            request: request,
            speakHandler: speakHandler,
            listenProvider: .swiftAPI,
            listenConfig: listenConfig,
            onSubmitSuccess: onSubmitSuccess,
            onCloseWithoutResponse: onCloseWithoutResponse,
            closeWindow: closeWindow
        )

        featureWindows.show(
            FeatureWindowRequest(
                id: windowID,
                title: "Client Question",
                rootView: AnyView(ClientVoiceAskDialog(viewModel: viewModel)),
                size: CGSize(width: 520, height: 320),
                onClose: {
                    viewModel.handleSystemClose()
                }
            )
        )
    }
}
