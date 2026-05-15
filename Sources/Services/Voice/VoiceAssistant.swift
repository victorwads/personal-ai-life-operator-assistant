import AVFoundation
import Speech

private func appendAudioBuffer(_ buffer: AVAudioPCMBuffer, to request: SFSpeechAudioBufferRecognitionRequest) {
    request.append(buffer)
}

private func startSpeechRecognitionAudioEngine(request: SFSpeechAudioBufferRecognitionRequest) throws -> AVAudioEngine {
    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
        appendAudioBuffer(buffer, to: request)
    }

    engine.prepare()
    try engine.start()

    return engine
}

private func startMicrophoneCaptureAudioEngine() throws -> AVAudioEngine {
    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { _, _ in
        // Intentionally discard audio; this is only to force the OS permission flow.
    }

    engine.prepare()
    try engine.start()

    return engine
}

private struct SpeechRecognitionCallbackEvent: Sendable {
    let transcript: String?
    let isFinal: Bool
    let errorDescription: String?
}

private final class SpeechSynthesizerDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: ((AVSpeechUtterance) -> Void)?
    var onComplete: ((AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onStart?(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onComplete?(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onComplete?(utterance)
    }
}

private func startSpeechRecognitionTask(
    recognizer: SFSpeechRecognizer,
    request: SFSpeechAudioBufferRecognitionRequest,
    handler: @escaping @MainActor (SpeechRecognitionCallbackEvent) -> Void
) -> SFSpeechRecognitionTask {
    recognizer.recognitionTask(with: request) { result, error in
        let event = SpeechRecognitionCallbackEvent(
            transcript: result?.bestTranscription.formattedString,
            isFinal: result?.isFinal ?? false,
            errorDescription: error?.localizedDescription
        )
        Task { @MainActor in
            handler(event)
        }
    }
}

func requestSpeechRecognitionAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }
}

func requestMicrophoneAccess() async -> Bool {
    await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            continuation.resume(returning: granted)
        }
    }
}

@MainActor
final class VoiceAssistant {
    private let synthesizer = AVSpeechSynthesizer()
    private let synthesizerDelegate = SpeechSynthesizerDelegateProxy()
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speaking = false
    private var pendingSpeechUtteranceCount = 0
    private var speechUtteranceContinuations: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]
    private var speechCompletionWaiters: [CheckedContinuation<Void, Never>] = []

    var onSpeakingStateChanged: ((Bool) -> Void)?

    init() {
        synthesizerDelegate.onStart = { [weak self] _ in
            Task { @MainActor in
                self?.setSpeaking(true)
            }
        }
        synthesizerDelegate.onComplete = { [weak self] utterance in
            Task { @MainActor in
                self?.handleSpeechUtteranceCompleted(utterance)
            }
        }
        synthesizer.delegate = synthesizerDelegate
    }

    func speak(_ text: String, language: String = "pt-BR", voiceIdentifier: String? = nil, rate: Float = AVSpeechUtteranceDefaultSpeechRate) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        utterance.rate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        pendingSpeechUtteranceCount += 1
        setSpeaking(true)

        await withCheckedContinuation { continuation in
            speechUtteranceContinuations[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    func stopSpeaking(immediately: Bool = true) async {
        synthesizer.stopSpeaking(at: immediately ? .immediate : .word)
        pendingSpeechUtteranceCount = 0
        setSpeaking(false)
        resumeSpeechUtteranceContinuations()
        resumeSpeechCompletionWaiters()
    }

    private func handleSpeechUtteranceCompleted(_ utterance: AVSpeechUtterance) {
        if pendingSpeechUtteranceCount > 0 {
            pendingSpeechUtteranceCount -= 1
        }

        speechUtteranceContinuations.removeValue(forKey: ObjectIdentifier(utterance))?.resume()

        if pendingSpeechUtteranceCount == 0 {
            setSpeaking(false)
            resumeSpeechCompletionWaiters()
        }
    }

    private func setSpeaking(_ value: Bool) {
        guard speaking != value else { return }
        speaking = value
        onSpeakingStateChanged?(value)
    }

    private func waitForSpeechSynthesisToFinish() async {
        guard speaking || synthesizer.isSpeaking || pendingSpeechUtteranceCount > 0 else { return }

        await withCheckedContinuation { continuation in
            speechCompletionWaiters.append(continuation)
        }
    }

    private func resumeSpeechUtteranceContinuations() {
        let continuations = Array(speechUtteranceContinuations.values)
        speechUtteranceContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func resumeSpeechCompletionWaiters() {
        let waiters = speechCompletionWaiters
        speechCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func listen(recognitionLocaleIdentifier: String = "pt-BR", timeoutSeconds: Int? = nil) async throws -> String {
        await waitForSpeechSynthesisToFinish()

        let normalizedTimeoutSeconds = timeoutSeconds.flatMap { value -> Int? in
            guard value > 0 else { return nil }
            return max(3, min(value, 120))
        }

        let speechAuthorized = try await ensureSpeechAuthorization()
        guard speechAuthorized else {
            throw VoiceAssistantError.speechNotAuthorized
        }

        let micAuthorized = await ensureMicrophoneAuthorization()
        guard micAuthorized else {
            throw VoiceAssistantError.microphoneNotAuthorized
        }

        @MainActor
        final class ListenState {
            var hasResolved = false
        }

        let state = ListenState()

        return try await withCheckedThrowingContinuation { continuation in
            do {
                let locale = Locale(identifier: recognitionLocaleIdentifier)
                guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                    throw VoiceAssistantError.speechRecognizerUnavailable
                }

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true

                let engine = try startSpeechRecognitionAudioEngine(request: request)
                self.audioEngine = engine

                let timeoutTask: Task<Void, Never>?
                if let normalizedTimeoutSeconds {
                    timeoutTask = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(normalizedTimeoutSeconds))
                        guard !Task.isCancelled else { return }
                        self?.stopListening()
                        await MainActor.run {
                            guard !state.hasResolved else { return }
                            state.hasResolved = true
                            continuation.resume(throwing: VoiceAssistantError.timedOut)
                        }
                    }
                } else {
                    timeoutTask = nil
                }

                let handleRecognitionResult: @MainActor (SpeechRecognitionCallbackEvent) -> Void = { [weak self] event in
                    if let errorDescription = event.errorDescription {
                        timeoutTask?.cancel()
                        self?.stopListening()
                        guard !state.hasResolved else { return }
                        state.hasResolved = true
                        continuation.resume(throwing: VoiceAssistantError.recognitionFailed(errorDescription))
                        return
                    }

                    if event.isFinal {
                        timeoutTask?.cancel()
                        self?.stopListening()
                        guard !state.hasResolved else { return }
                        state.hasResolved = true
                        let transcript = (event.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: transcript)
                    }
                }
                self.recognitionTask = startSpeechRecognitionTask(
                    recognizer: recognizer,
                    request: request,
                    handler: handleRecognitionResult
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func startListening(
        recognitionLocaleIdentifier: String = "pt-BR",
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (VoiceAssistantError) -> Void
    ) async throws {
        let speechAuthorized = try await ensureSpeechAuthorization()
        guard speechAuthorized else {
            throw VoiceAssistantError.speechNotAuthorized
        }

        let micAuthorized = await ensureMicrophoneAuthorization()
        guard micAuthorized else {
            throw VoiceAssistantError.microphoneNotAuthorized
        }

        let locale = Locale(identifier: recognitionLocaleIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw VoiceAssistantError.speechRecognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let engine = try startSpeechRecognitionAudioEngine(request: request)
        self.audioEngine = engine

        let handleRecognitionResult: @MainActor (SpeechRecognitionCallbackEvent) -> Void = { [weak self] event in
            if let errorDescription = event.errorDescription {
                self?.stopListening()
                onError(.recognitionFailed(errorDescription))
                return
            }

            guard let transcript = event.transcript else { return }
            onPartial(transcript)

            if event.isFinal {
                self?.stopListening()
                onFinal(transcript.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        self.recognitionTask = startSpeechRecognitionTask(
            recognizer: recognizer,
            request: request,
            handler: handleRecognitionResult
        )
    }

    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil

        if let audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
    }

    private func ensureSpeechAuthorization() async throws -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await requestSpeechRecognitionAuthorizationStatus() == .authorized
        @unknown default:
            return false
        }
    }

    private func ensureMicrophoneAuthorization() async -> Bool {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        switch current {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await requestMicrophoneAccess()
        @unknown default:
            return false
        }
    }

    func forceMicrophoneCapture(durationSeconds: Double = 1.0) async throws {
        let micAuthorized = await ensureMicrophoneAuthorization()
        guard micAuthorized else {
            throw VoiceAssistantError.microphoneNotAuthorized
        }

        let durationSeconds = max(0.2, min(durationSeconds, 5.0))

        audioEngine = try startMicrophoneCaptureAudioEngine()

        try? await Task.sleep(for: .seconds(durationSeconds))
        stopListening()
    }
}

enum VoiceAssistantError: LocalizedError {
    case speechNotAuthorized
    case microphoneNotAuthorized
    case speechRecognizerUnavailable
    case timedOut
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .speechNotAuthorized:
            return "Speech recognition permission is not authorized."
        case .microphoneNotAuthorized:
            return "Microphone permission is not authorized."
        case .speechRecognizerUnavailable:
            return "Speech recognizer is unavailable for the requested language."
        case .timedOut:
            return "Timed out waiting for speech."
        case .recognitionFailed(let description):
            return description
        }
    }
}
