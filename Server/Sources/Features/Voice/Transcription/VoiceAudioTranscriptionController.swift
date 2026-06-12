import Foundation
import Combine

@MainActor
final class VoiceAudioTranscriptionController: DSAudioTranscriptionController {
    @Published private(set) var lifecycle: DSAudioTranscriptionLifecycle = .idle

    @Published private(set) var isListening: Bool = false
    @Published private(set) var isSilent: Bool = true
    @Published private(set) var isPostProcessing: Bool = false

    @Published private(set) var statusText: String?
    @Published private(set) var errorText: String?

    @Published private(set) var inlineSegments: [DSAudioTranscriptionSegment] = []

    @Published private(set) var committedTextAppendRevision: Int = 0
    @Published private(set) var textMutationRevision: Int = 0
    @Published private(set) var vadStatusText: String?
    @Published private(set) var vadProbability: Float?
    @Published private(set) var vadModelLoaded: Bool = false
    @Published private(set) var lastSegmentAudioSamplesCount: Int = 0
    @Published private(set) var lastSegmentOverlapSamplesCount: Int = 0

    private let config: VoiceAudioTranscriptionConfig
    private let queue = VoiceAudioTranscriptionQueue()
    private let pipeline: VoiceAudioTranscriptionPipeline

    private var pendingTextMutations: [DSAudioTextMutation] = []
    private var paragraphBreakTask: Task<Void, Never>?
    private var hasCommittedTextSinceStart: Bool = false
    private var hasInsertedParagraphBreakForCurrentSilence: Bool = false
    
    private var transcriber: AppleSpeechRealtimeTranscriber?
    private var speechTask: Task<Void, Never>?

    init(
        config: VoiceAudioTranscriptionConfig = .default,
        whisperPostProcessor: WhisperPostProcessing? = nil
    ) {
        self.config = config

        self.pipeline = VoiceAudioTranscriptionPipeline(
            config: config,
            queue: queue,
            whisperPostProcessor: whisperPostProcessor ?? WhisperPostProcessor(config: config)
        )

        self.vadStatusText = pipeline.vadStatus
        self.vadModelLoaded = pipeline.vadModelLoaded

        bindPipeline()
        refreshState()
    }

    func startListening() {
        guard !isListening else {
            return
        }

        errorText = nil

        let startResult = pipeline.start()

        switch startResult {
        case .started:
            isListening = true
            isSilent = true
            lifecycle = .silent
            statusText = "Listening"
            if config.enablesAppleSpeech {
                startAppleSpeech()
            }
        case .failed(let message):
            isListening = false
            isSilent = true
            lifecycle = .error
            errorText = message
            refreshState()
        }
    }

    func stopListening() {
        guard isListening else {
            return
        }

        isListening = false
        isSilent = true

        speechTask?.cancel()
        speechTask = nil
        
        paragraphBreakTask?.cancel()
        paragraphBreakTask = nil
        hasInsertedParagraphBreakForCurrentSilence = false

        let t = transcriber
        transcriber = nil
        Task {
            await t?.stop()
        }

        pipeline.stop()
        refreshState()
    }

    func cancelAll() {
        speechTask?.cancel()
        speechTask = nil

        let t = transcriber
        transcriber = nil
        Task {
            await t?.stop()
        }

        isListening = false
        isSilent = true
        isPostProcessing = false
        lifecycle = .idle
        statusText = nil
        errorText = nil

        pendingTextMutations.removeAll()
        committedTextAppendRevision += 1
        textMutationRevision += 1

        paragraphBreakTask?.cancel()
        paragraphBreakTask = nil
        hasCommittedTextSinceStart = false
        hasInsertedParagraphBreakForCurrentSilence = false

        pipeline.cancelAll()
        refreshState()
    }

    func consumeTextMutation() -> DSAudioTextMutation? {
        guard !pendingTextMutations.isEmpty else {
            return nil
        }

        return pendingTextMutations.removeFirst()
    }

    var queuedSegmentCount: Int {
        inlineSegments.filter { $0.kind == .queued }.count
    }

    var processingSegmentCount: Int {
        inlineSegments.filter { $0.kind == .whisperProcessing }.count
    }

    private func bindPipeline() {
        pipeline.onStateChanged = { [weak self] in
            self?.refreshState()
        }

        pipeline.onSilenceClosed = { [weak self] in
            self?.transcriber?.reset()
        }

        pipeline.onCommittedText = { [weak self] text in
            self?.enqueueCommittedText(text)
        }

        pipeline.onError = { [weak self] message in
            self?.errorText = message
            self?.refreshState()
        }

        pipeline.onVADStatusChanged = { [weak self] status in
            self?.vadStatusText = status
        }

        pipeline.onVADProbabilityChanged = { [weak self] probability in
            self?.vadProbability = probability
        }

        pipeline.onSilenceStateChanged = { [weak self] isSilent in
            guard let self else { return }
            self.isSilent = isSilent
            if isSilent {
                self.markSilenceStarted()
            } else {
                self.markSpeechActivity()
            }
            self.refreshState()
        }
    }

    private func enqueueCommittedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        pendingTextMutations.append(
            .appendCommittedText(
                DSAudioCommittedTextAppend(
                    text: trimmed,
                    shouldStartNewParagraph: false
                )
            )
        )

        hasCommittedTextSinceStart = true
        committedTextAppendRevision += 1
        textMutationRevision += 1
    }

    private func refreshState() {
        inlineSegments = queue.makeInlineSegments()

        isPostProcessing = inlineSegments.contains { $0.kind == .whisperProcessing }
        self.vadModelLoaded = pipeline.vadModelLoaded
        self.vadStatusText = pipeline.vadStatus
        self.lastSegmentAudioSamplesCount = pipeline.lastSegmentAudioSamplesCount
        self.lastSegmentOverlapSamplesCount = pipeline.lastSegmentOverlapSamplesCount

        if let errorText, !errorText.isEmpty {
            lifecycle = .error
        } else if isListening && inlineSegments.contains(where: { $0.kind == .appleRealtime }) {
            lifecycle = .recognizing
        } else if isPostProcessing {
            lifecycle = .postProcessing
        } else if queuedSegmentCount > 0 {
            lifecycle = .queued
        } else if isListening && isSilent {
            lifecycle = .silent
        } else if isListening {
            lifecycle = .listening
        } else {
            lifecycle = .idle
        }

        statusText = makeStatusText()
    }

    private func makeStatusText() -> String? {
        if let errorText, !errorText.isEmpty {
            return nil
        }

        var parts: [String] = []

        if isListening {
            if isSilent {
                parts.append("Silence")
            } else {
                parts.append("Listening")
            }
        }

        if isPostProcessing {
            parts.append("Post-processing")
        }

        if queuedSegmentCount > 0 {
            parts.append("Queue: \(queuedSegmentCount)")
        }

        if inlineSegments.contains(where: { $0.kind == .appleRealtime }) {
            parts.append("Recognizing")
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: " • ")
    }

    private func markSpeechActivity() {
        paragraphBreakTask?.cancel()
        paragraphBreakTask = nil
        hasInsertedParagraphBreakForCurrentSilence = false
    }

    private func markSilenceStarted() {
        guard config.enablesParagraphBreaks else { return }
        guard hasCommittedTextSinceStart else { return }
        guard !hasInsertedParagraphBreakForCurrentSilence else { return }

        paragraphBreakTask?.cancel()

        paragraphBreakTask = Task { [weak self] in
            guard let self else { return }

            let delay = UInt64(self.config.paragraphBreakSilenceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.insertParagraphBreakIfNeeded()
            }
        }
    }

    private func insertParagraphBreakIfNeeded() {
        guard config.enablesParagraphBreaks else { return }
        guard hasCommittedTextSinceStart else { return }
        guard !hasInsertedParagraphBreakForCurrentSilence else { return }

        pendingTextMutations.append(.insertParagraphBreak)
        textMutationRevision += 1

        hasInsertedParagraphBreakForCurrentSilence = true

        refreshState()
    }

    private func startAppleSpeech() {
        let localTranscriber = AppleSpeechRealtimeTranscriber(language: config.appleSpeechLanguage)
        self.transcriber = localTranscriber
        
        localTranscriber.onAudioBuffer = { [weak self] buffer, time in
            Task { @MainActor in
                self?.pipeline.processAudioBuffer(buffer, at: time)
            }
        }
        
        speechTask = Task {
            do {
                try await localTranscriber.start()
                for await event in localTranscriber.events {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        switch event.kind {
                        case .partial(let text):
                            self.errorText = nil
                            self.markSpeechActivity()
                            self.isSilent = false
                            self.pipeline.handleRealtimeText(text)
                        case .final(let text):
                            print("[AppleSpeech] final received: \(text)")
                            self.pipeline.handleRealtimeText(text)
                            self.pipeline.closeRealtimeDueToSilence()
                        case .error(let message):
                            self.errorText = message
                            self.refreshState()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.refreshState()
                }
            }
        }
    }
}
