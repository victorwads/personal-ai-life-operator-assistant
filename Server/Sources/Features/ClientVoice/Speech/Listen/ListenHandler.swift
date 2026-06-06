import AVFoundation
import Foundation
import Speech

final class ListenHandler: @unchecked Sendable {
    private let lock = NSLock()

    private var partialCallback: (@MainActor (String) -> Void)?
    private var finalCallback: (@MainActor (String) -> Void)?

    private var currentBestText: String = ""
    private var isFinished = false
    private var isEndingForFinalResult = false
    private var continuation: CheckedContinuation<String, Never>?

    private let debounceFinalMs: Int
    private let whisperPostProcessingConfig: WhisperPostProcessingConfig?
    private let finalTextResolver: (any SpeechFinalTextResolving)?
    private let whisperCancellationToken = WhisperProcessingCancellationToken()

    private var debounceTask: Task<Void, Never>?
    private var postProcessingTask: Task<Void, Never>?

    private let recognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var capturedAudioBuffer: CapturedSpeechAudioBuffer?

    init(
        config: ListenConfig,
        recognizer: SFSpeechRecognizer,
        audioEngine: AVAudioEngine,
        finalTextResolver: (any SpeechFinalTextResolving)? = nil
    ) {
        self.debounceFinalMs = config.debounceFinalMs
        self.whisperPostProcessingConfig = config.postProcessing
        self.finalTextResolver = finalTextResolver
        self.recognizer = recognizer
        self.audioEngine = audioEngine
    }

    var usesWhisperPostProcessing: Bool {
        whisperPostProcessingConfig?.isEnabled == true && finalTextResolver != nil
    }

    func onPartial(_ callback: @escaping @MainActor (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        partialCallback = callback
    }

    func onFinal(_ callback: @escaping @MainActor (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        finalCallback = callback
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
        currentBestText = ""

        let cont = continuation
        continuation = nil

        debounceTask?.cancel()
        debounceTask = nil

        let processingTask = postProcessingTask
        postProcessingTask = nil

        let capturedAudioBuffer = self.capturedAudioBuffer
        self.capturedAudioBuffer = nil
        lock.unlock()

        whisperCancellationToken.cancel()
        processingTask?.cancel()
        stopAudioAndRecognition()
        capturedAudioBuffer?.reset()

        if shouldResume {
            cont?.resume(returning: "")
        }
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        capturedAudioBuffer = try CapturedSpeechAudioBuffer(inputFormat: recordingFormat)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else {
                return
            }

            self.lock.lock()
            let activeRequest = self.recognitionRequest
            let capturedAudioBuffer = self.capturedAudioBuffer
            self.lock.unlock()

            activeRequest?.append(buffer)
            capturedAudioBuffer?.append(buffer)
        }

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        recognitionTask = task

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            request.endAudio()
            task.cancel()
            recognitionRequest = nil
            recognitionTask = nil
            capturedAudioBuffer = nil
            throw error
        }

        let whisperPostProcessingConfig = self.whisperPostProcessingConfig
        let finalTextResolver = self.finalTextResolver
        if whisperPostProcessingConfig?.isEnabled == true, let finalTextResolver {
            Task(priority: .utility) {
                await finalTextResolver.warmUp(whisperConfig: whisperPostProcessingConfig)
            }
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
        if let result {
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

                if let partial {
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

        if let error {
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
                    handleFatalError()
                }
            }
        } else if isFinalResult {
            lock.lock()
            let currentFinished = isFinished
            let endingForFinalResult = isEndingForFinalResult
            lock.unlock()

            if !currentFinished && !endingForFinalResult {
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
                guard !Task.isCancelled else {
                    return
                }

                self?.debounceFired()
            } catch {
                // Ignore sleep cancellation.
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
        recognitionRequest = request

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        recognitionTask = task
        lock.unlock()

        print("[SpeechListener] Restarted speech recognition task due to transient error/timeout.")
    }

    private func handleFatalError() {
        finishResolvedRecognition(with: snapshotCurrentText())
    }

    private func finishRecognition(with appleSpeechText: String) {
        stopAudioAndRecognition()

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        isEndingForFinalResult = false
        debounceTask?.cancel()
        debounceTask = nil

        let capturedAudio = capturedAudioBuffer?.takeAllSamples()
        let capturedSamples = capturedAudio?.samples ?? []
        if let diagnostics = capturedAudio?.diagnostics {
            print("[SpeechListener] Whisper captured audio diagnostics: \(diagnostics.summary)")
        }
        capturedAudioBuffer = nil

        let cancellationToken = whisperCancellationToken
        let shouldUsePostProcessing = usesWhisperPostProcessing
        lock.unlock()

        guard shouldUsePostProcessing else {
            finishResolvedRecognition(with: appleSpeechText)
            return
        }

        postProcessingTask = Task { [weak self] in
            guard let self else {
                return
            }

            if Task.isCancelled || cancellationToken.isCancelled {
                return
            }

            let finalText = await self.resolveFinalText(
                appleSpeechText: appleSpeechText,
                capturedSamples: capturedSamples
            )

            guard !Task.isCancelled, !cancellationToken.isCancelled else {
                return
            }

            self.finishResolvedRecognition(with: finalText)
        }
    }

    func resolveFinalText(
        appleSpeechText: String,
        capturedSamples: [Float]
    ) async -> String {
        guard let whisperPostProcessingConfig, whisperPostProcessingConfig.isEnabled,
              let finalTextResolver else {
            return appleSpeechText
        }

        return await finalTextResolver.resolveFinalText(
            appleSpeechText: appleSpeechText,
            capturedAudioSamples: capturedSamples,
            whisperConfig: whisperPostProcessingConfig,
            cancellationToken: whisperCancellationToken
        )
    }

    private func finishResolvedRecognition(with text: String) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        isFinished = true
        currentBestText = text

        let cont = continuation
        continuation = nil

        debounceTask?.cancel()
        debounceTask = nil

        postProcessingTask = nil

        let finalCb = finalCallback
        lock.unlock()

        if let finalCb {
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
