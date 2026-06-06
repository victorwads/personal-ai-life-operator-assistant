import Foundation
import Speech
import AVFoundation

enum SpeechListener {
    static func makeFinalTextResolver(
        whisperPostProcessingConfig: WhisperPostProcessingConfig?
    ) -> (any SpeechFinalTextResolving)? {
        WhisperPostProcessingFactory.makeFinalTextResolver(
            whisperPostProcessingConfig: whisperPostProcessingConfig
        )
    }

    static func listen(
        provider: ListenProvider,
        config: ListenConfig = .init()
    ) async throws -> ListenHandler {
        switch provider {
        case .whisper:
            throw SpeechListenerError.notImplemented("Whisper provider is not implemented yet.")
        case .swiftAPI:
            // Check speech authorization status.
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .notDetermined {
                let authorized = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { authStatus in
                        continuation.resume(returning: authStatus == .authorized)
                    }
                }
                guard authorized else {
                    throw SpeechListenerError.unauthorized
                }
            } else if status != .authorized {
                throw SpeechListenerError.unauthorized
            }

            // Create appropriate locale configuration.
            let locale: Locale
            if config.language == "auto" {
                locale = Locale.current
            } else {
                locale = Locale(identifier: config.language)
            }

            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                throw SpeechListenerError.recognizerUnavailable
            }

            guard recognizer.isAvailable else {
                throw SpeechListenerError.recognizerUnavailable
            }

            let audioEngine = AVAudioEngine()
            let handler = ListenHandler(
                config: config,
                recognizer: recognizer,
                audioEngine: audioEngine,
                finalTextResolver: makeFinalTextResolver(
                    whisperPostProcessingConfig: config.postProcessing
                )
            )

            // Start recording and recognition immediately.
            try handler.start()
            return handler
        }
    }
}
