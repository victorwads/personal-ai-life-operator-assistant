import Foundation

enum WhisperPostProcessingFactory {
    static func makeFinalTextResolver(
        whisperPostProcessingConfig: WhisperPostProcessingConfig?
    ) -> (any SpeechFinalTextResolving)? {
        guard whisperPostProcessingConfig?.isEnabled == true else {
            return nil
        }

        return WhisperSpeechPostProcessor.shared
    }
}
