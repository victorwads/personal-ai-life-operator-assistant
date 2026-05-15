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
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?

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
        synthesizer.speak(utterance)
    }

    func stopSpeaking(immediately: Bool = true) async {
        synthesizer.stopSpeaking(at: immediately ? .immediate : .word)
    }

    func askUser(prompt: String, language: String = "pt-BR", voiceIdentifier: String? = nil, recognitionLocaleIdentifier: String = "pt-BR", timeoutSeconds: Int? = nil) async throws -> String {
        await speak(prompt, language: language, voiceIdentifier: voiceIdentifier)
        return try await listen(recognitionLocaleIdentifier: recognitionLocaleIdentifier, timeoutSeconds: timeoutSeconds)
    }

    func listen(recognitionLocaleIdentifier: String = "pt-BR", timeoutSeconds: Int? = nil) async throws -> String {
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

    func listenWithAutoSubmit(
        recognitionLocaleIdentifier: String = "pt-BR",
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
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
            var lastPartial = ""
            var debounceTask: Task<Void, Never>?
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

                @MainActor
                func scheduleDebounce() {
                    state.debounceTask?.cancel()
                    state.debounceTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(1.0))
                        guard !Task.isCancelled else { return }
                        self?.stopListening()
                        guard !state.hasResolved else { return }
                        state.hasResolved = true
                        let value = state.lastPartial.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: value)
                    }
                }

                let handleRecognitionResult: @MainActor (SpeechRecognitionCallbackEvent) -> Void = { [weak self] event in
                    if let errorDescription = event.errorDescription {
                        state.debounceTask?.cancel()
                        self?.stopListening()
                        guard !state.hasResolved else { return }
                        state.hasResolved = true
                        continuation.resume(throwing: VoiceAssistantError.recognitionFailed(errorDescription))
                        return
                    }

                    guard let partial = event.transcript else { return }
                    state.lastPartial = partial
                    onPartial(partial)
                    scheduleDebounce()

                    if event.isFinal {
                        state.debounceTask?.cancel()
                        self?.stopListening()
                        guard !state.hasResolved else { return }
                        state.hasResolved = true
                        continuation.resume(returning: partial.trimmingCharacters(in: .whitespacesAndNewlines))
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
