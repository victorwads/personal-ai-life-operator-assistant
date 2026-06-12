import Foundation

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }
    private static let workerServiceId = "client.voice.worker"
    private static let manualClientPromptText = "Eu vi que voce me chamou, o que voce precisa?"

    let repository: FirestoreClientInteractionRequestRepository
    let settings: ClientVoiceSettingsWrapper
    let presenceService: ClientVoicePresenceService
    let askDialogPresenter: ClientVoiceAskDialogPresenter
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
        let askDialogPresenter = ClientVoiceAskDialogPresenter(
            repository: repository,
            featureWindows: context.featureWindows,
            settings: settings
        )
        let workerService = ClientVoiceWorkerService(
            id: Self.workerServiceId,
            title: "Voice Worker",
            repository: repository,
            sharedLocks: context.sharedLocks,
            presenceService: presenceService,
            presentAskDialog: { request, speakHandler in
                askDialogPresenter.present(
                    request: request,
                    speakHandler: speakHandler,
                    dismissActionTitle: "Answer Later",
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
            },
            speakPerformer: { [settings] text in
                try await SpeechSpeaker.speak(text: text, config: settings.speechSpeakConfig)
            }
        )
        self.repository = repository
        self.settings = settings
        self.presenceService = presenceService
        self.askDialogPresenter = askDialogPresenter
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
        guard let requestID = request.id else { return }

        Task {
            do {
                let updatedRequest = try await repository.markWaitingUser(id: requestID)
                askDialogPresenter.present(
                    request: updatedRequest,
                    speakHandler: CompletedSpeechSpeakHandler(),
                    dismissActionTitle: "Answer Later",
                    onSubmitSuccess: {
                        await self.unlockAskLock(requestID: requestID)
                    },
                    onCloseWithoutResponse: {
                        await self.unlockAskLock(requestID: requestID)
                    }
                )
            } catch {
                print("Failed to reopen ask dialog for request \(requestID): \(error.localizedDescription)")
            }
        }
    }

    func openNewManualRequestDialog() async throws {
        let request = try await repository.createRequest(
            issueId: nil,
            kind: .ask,
            status: .waitingUser,
            promptText: Self.manualClientPromptText
        )
        askDialogPresenter.present(
            request: request,
            speakHandler: CompletedSpeechSpeakHandler(),
            dismissActionTitle: "Cancel Request",
            onSubmitSuccess: {
                await self.unlockGlobalEventLock()
            },
            onCloseWithoutResponse: {
                guard let requestID = request.id else { return }
                do {
                    _ = try await self.repository.markCancelled(id: requestID)
                    await self.unlockGlobalEventLock()
                } catch {
                    print("Failed to cancel manual client request \(requestID): \(error.localizedDescription)")
                }
            }
        )
    }

    private func unlockAskLock(requestID: String) async {
        await context.sharedLocks.unlock(id: "ask_to_client:\(requestID)")
    }

    private func unlockGlobalEventLock() async {
        await context.sharedLocks.unlock(id: SharedLockIDs.globalEvent)
    }
}
