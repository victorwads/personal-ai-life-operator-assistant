import Foundation
import AVFoundation

@MainActor
final class AVSpeechSpeakHandler: SpeechSpeakHandler {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegateProxy = AVSpeechSynthesizerDelegateProxy()
    private let utterance: AVSpeechUtterance

    private var finished = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    init(utterance: AVSpeechUtterance) {
        self.utterance = utterance
        super.init()

        delegateProxy.onFinish = { [weak self] in
            Task { @MainActor in
                self?.finish()
            }
        }

        synthesizer.delegate = delegateProxy
    }

    func start() {
        synthesizer.speak(utterance)
    }

    override func await() async {
        guard !finished else { return }

        await withCheckedContinuation { continuation in
            if finished {
                continuation.resume()
                return
            }

            continuations.append(continuation)
        }
    }

    override func cancel() {
        guard !finished else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        finish()
    }

    private func finish() {
        guard !finished else { return }

        finished = true
        let pendingContinuations = continuations
        continuations.removeAll()

        for continuation in pendingContinuations {
            continuation.resume()
        }
    }
}

private final class AVSpeechSynthesizerDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        onFinish?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        onFinish?()
    }
}
