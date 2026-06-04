import Foundation
import Speech
import AVFoundation

final class ListenHandler: @unchecked Sendable {
    private let lock = NSLock()

    // Callbacks
    private var partialCallback: (@MainActor (String) -> Void)?
    private var finalCallback: (@MainActor (String) -> Void)?

    // State
    private var currentBestText: String = ""
    private var isFinished = false
    private var isEndingForFinalResult = false
    private var continuation: CheckedContinuation<String, Never>?

    // Timing & Debounce
    private let debounceFinalMs: Int
    private var debounceTask: Task<Void, Never>?

    // Audio & Recognition Objects
    private let recognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(
        config: ListenConfig,
        recognizer: SFSpeechRecognizer,
        audioEngine: AVAudioEngine
    ) {
        self.debounceFinalMs = config.debounceFinalMs
        self.recognizer = recognizer
        self.audioEngine = audioEngine
    }

    func onPartial(_ callback: @escaping @MainActor (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.partialCallback = callback
    }

    func onFinal(_ callback: @escaping @MainActor (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.finalCallback = callback
    }

    func await() async -> String {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isFinished {
                let text = currentBestText
                lock.unlock()
                continuation.resume(returning: text)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        let shouldResume = !isFinished
        isFinished = true
        isEndingForFinalResult = false
        let cont = continuation
        continuation = nil
        debounceTask?.cancel()
        debounceTask = nil
        lock.unlock()

        stopAudioAndRecognition()

        if shouldResume {
            cont?.resume(returning: "")
        }
    }

    // Starts the recording and recognition processes. Throws if initial setup fails.
    func start() throws {
        lock.lock()
        defer { lock.unlock() }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Enable automatic punctuation inferred from speech/pauses/intonation
        request.addsPunctuation = true

        self.recognitionRequest = request

        // Install tap to feed audio buffers to the speech recognition request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.lock.lock()
            let activeRequest = self.recognitionRequest
            self.lock.unlock()
            activeRequest?.append(buffer)
        }

        // Start the SFSpeechRecognitionTask
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        self.recognitionTask = task

        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            // Clean up if audio engine fails to start
            inputNode.removeTap(onBus: 0)
            request.endAudio()
            task.cancel()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            throw error
        }
    }

    private func stopAudioAndRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                lock.lock()
                guard !isFinished else {
                    lock.unlock()
                    return
                }
                currentBestText = text
                let partial = partialCallback
                let shouldDebounce = !isEndingForFinalResult
                lock.unlock()

                if let partial = partial {
                    Task { @MainActor in
                        partial(text)
                    }
                }

                if shouldDebounce {
                    resetDebounceTimer()
                }
            }
        }

        let isFinalResult = result?.isFinal == true
        if isFinalResult {
            lock.lock()
            let shouldFinishWithFinalResult = isEndingForFinalResult && !isFinished
            lock.unlock()

            if shouldFinishWithFinalResult {
                finishRecognition(with: snapshotCurrentText())
                return
            }
        }

        if let error = error {
            lock.lock()
            let currentFinished = isFinished
            let endingForFinalResult = isEndingForFinalResult
            lock.unlock()

            if !currentFinished {
                print("[SpeechListener] Recognition error encountered: \(error)")
                let nsError = error as NSError
                if endingForFinalResult {
                    print("[SpeechListener] Ignoring recognition error while waiting for native final result.")
                } else if isTransientError(nsError) {
                    restartRecognitionTask()
                } else {
                    handleFatalError(error)
                }
            }
        } else if isFinalResult {
            lock.lock()
            let currentFinished = isFinished
            let endingForFinalResult = isEndingForFinalResult
            lock.unlock()

            if !currentFinished && !endingForFinalResult {
                // If Apple Speech session ends normally (usually 1-minute timeout), restart to continue listening
                restartRecognitionTask()
            }
        }
    }

    private func resetDebounceTimer() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        debounceTask?.cancel()

        let timeoutMs = debounceFinalMs
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                guard !Task.isCancelled else { return }
                self?.debounceFired()
            } catch {
                // Ignore task cancellation sleep errors
            }
        }
        lock.unlock()
    }

    private func debounceFired() {
        lock.lock()
        guard !isFinished, !isEndingForFinalResult else {
            lock.unlock()
            return
        }

        let text = currentBestText
        if !text.isEmpty {
            isEndingForFinalResult = true
            debounceTask?.cancel()
            debounceTask = nil
            lock.unlock()

            requestFinalResultAfterSilence()
        } else {
            lock.unlock()
        }
    }

    private func requestFinalResultAfterSilence() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    private func isTransientError(_ error: NSError) -> Bool {
        // e.g. silent periods (203), minor connection disruptions, or system-cancelled tasks (4 / 209)
        if error.domain == "kAFAssistantErrorDomain" || error.domain == SFSpeechErrorDomain {
            return error.code == 203 || error.code == 209 || error.code == 4
        }
        return false
    }

    private func restartRecognitionTask() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.recognitionRequest = request

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        self.recognitionTask = task
        lock.unlock()

        print("[SpeechListener] Restarted speech recognition task due to transient error/timeout.")
    }

    private func handleFatalError(_ error: Error) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        let text = currentBestText
        isFinished = true
        let cont = continuation
        continuation = nil
        lock.unlock()

        stopAudioAndRecognition()

        cont?.resume(returning: text)
    }

    private func finishRecognition(with text: String) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        isFinished = true
        isEndingForFinalResult = false
        let cont = continuation
        continuation = nil
        debounceTask?.cancel()
        debounceTask = nil
        let finalCb = finalCallback
        lock.unlock()

        stopAudioAndRecognition()

        if let finalCb = finalCb {
            Task { @MainActor in
                finalCb(text)
            }
        }

        cont?.resume(returning: text)
    }

    private func snapshotCurrentText() -> String {
        lock.lock()
        let text = currentBestText
        lock.unlock()
        return text
    }
}
