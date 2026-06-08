import AVFoundation
import Foundation

actor WhatsAppAudioTranscriptionService {
    private let profileId: String
    private let settingsProvider: @MainActor () -> ClientVoiceSettingsWrapper
    private let transcriber: any WhatsAppAudioTranscribing
    private let cacheRepository: (any WhatsAppAudioTranscriptionCacheRepository)?

    init(
        profileId: String,
        settingsProvider: @escaping @MainActor () -> ClientVoiceSettingsWrapper,
        transcriber: any WhatsAppAudioTranscribing = WhisperWhatsAppAudioTranscriber.shared,
        cacheRepository: (any WhatsAppAudioTranscriptionCacheRepository)? = nil
    ) {
        self.profileId = profileId
        self.settingsProvider = settingsProvider
        self.transcriber = transcriber
        self.cacheRepository = cacheRepository
    }

    func transcribeAudio(at audioURL: URL) async throws -> String {
        let audioId = audioURL.deletingPathExtension().lastPathComponent

        if let cacheRepository {
            do {
                if let cachedText = try await cacheRepository.getCachedText(
                    profileId: profileId,
                    audioId: audioId
                ) {
                    let trimmedCachedText = cachedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedCachedText.isEmpty {
                        return trimmedCachedText
                    }
                }
            } catch {
                // Cache is best-effort. Continue with Whisper if it is unavailable.
            }
        }

        let settings = await settingsProvider()
        let modelPath = await settings.whisperPostProcessingModelPath
        let coreMLModelPath = await settings.whisperPostProcessingCoreMLModelPath

        let config = WhisperPostProcessingConfig(
            isEnabled: true,
            modelPath: modelPath,
            coreMLModelPath: coreMLModelPath,
            language: "auto"
        )

        let text = try await transcriber.transcribeAudioFile(
            audioURL: audioURL,
            config: config
        )
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return ""
        }

        if let cacheRepository {
            do {
                try await cacheRepository.saveCachedText(
                    profileId: profileId,
                    audioId: audioId,
                    text: trimmedText
                )
            } catch {
                // Cache is best-effort. Keep transcription result even if persistence fails.
            }
        }

        return trimmedText
    }
}
