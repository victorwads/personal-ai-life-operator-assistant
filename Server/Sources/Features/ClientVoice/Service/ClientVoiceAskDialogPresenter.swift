import SwiftUI

@MainActor
final class ClientVoiceAskDialogPresenter {
    private let repository: ClientInteractionRequestRepository
    private let featureWindows: FeatureWindowsContext
    private let settings: ClientVoiceSettingsWrapper

    init(
        repository: ClientInteractionRequestRepository,
        featureWindows: FeatureWindowsContext,
        settings: ClientVoiceSettingsWrapper
    ) {
        self.repository = repository
        self.featureWindows = featureWindows
        self.settings = settings
    }

    func present(
        request: ClientInteractionRequest,
        speakHandler: SpeechSpeakHandler,
        dismissActionTitle: String,
        onSubmitSuccess: @escaping @MainActor () async -> Void,
        onCloseWithoutResponse: @escaping @MainActor () async -> Void
    ) {
        guard let requestID = request.id else { return }

        let windowID = "client_voice_ask_\(requestID)"
        let closeWindow = { [featureWindows] in
            featureWindows.hide(windowID)
        }
        let viewModel = ClientVoiceAskDialogViewModel(
            repository: repository,
            request: request,
            speakHandler: speakHandler,
            listenProvider: .swiftAPI,
            listenConfig: settings.speechRecognitionListenConfig,
            settings: settings,
            dismissActionTitleProvider: { dismissActionTitle },
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
