import Foundation

protocol WhisperPostProcessing {
    func refineTranscription(_ appleText: String, audioSamples: [Float]) async throws -> String
}

struct WhisperPostProcessor: WhisperPostProcessing {
    let config: VoiceAudioTranscriptionConfig

    init(config: VoiceAudioTranscriptionConfig) {
        self.config = config
    }

    func refineTranscription(_ appleText: String, audioSamples: [Float]) async throws -> String {
        let whisperConfig = WhisperPostProcessingConfig(
            isEnabled: config.enablesWhisperPostProcessing,
            modelPath: config.whisperModelPath,
            coreMLModelPath: config.whisperCoreMLModelPath,
            usesCPUOnly: config.whisperTranscriptionUsesCPUOnly,
            cpuThreadCount: config.whisperTranscriptionCPUThreadCount,
            language: config.whisperLanguage,
            task: config.whisperTask
        )
        
        let token = WhisperProcessingCancellationToken()
        return await WhisperSpeechPostProcessor.shared.resolveFinalText(
            appleSpeechText: appleText,
            capturedAudioSamples: audioSamples,
            whisperConfig: whisperConfig,
            cancellationToken: token
        )
    }
}
