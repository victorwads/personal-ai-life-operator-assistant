import Foundation

/// A timing-based fallback activity detector that monitors the frequency of partial Apple Speech text updates.
/// Note: This is not a model-based VAD, but a debug/fallback mode.
@MainActor
final class VoiceTimedTextActivityDetector {
    private let config: VoiceAudioTranscriptionConfig
    private var silenceTask: Task<Void, Never>?

    init(config: VoiceAudioTranscriptionConfig) {
        self.config = config
    }

    func markTextActivity(onSilence: @escaping @MainActor () -> Void) {
        silenceTask?.cancel()

        silenceTask = Task { [config] in
            let nanoseconds = UInt64(config.silenceBreakInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                onSilence()
            }
        }
    }

    func cancel() {
        silenceTask?.cancel()
        silenceTask = nil
    }
}
