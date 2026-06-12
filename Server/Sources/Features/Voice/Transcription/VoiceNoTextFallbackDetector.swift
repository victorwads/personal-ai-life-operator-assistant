import Foundation

@MainActor
final class VoiceNoTextFallbackDetector {
    private var task: Task<Void, Never>?

    func markTextChanged(
        interval: TimeInterval,
        onTimeout: @escaping @MainActor () -> Void
    ) {
        task?.cancel()

        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                onTimeout()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
