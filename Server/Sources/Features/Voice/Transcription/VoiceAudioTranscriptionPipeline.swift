import Foundation
import AVFoundation

enum VoiceAudioTranscriptionStartResult {
    case started
    case failed(String)
}

@MainActor
final class VoiceAudioTranscriptionPipeline {
    private let config: VoiceAudioTranscriptionConfig
    private let queue: VoiceAudioTranscriptionQueue
    private let whisperPostProcessor: WhisperPostProcessing

    private var timedTextDetector: VoiceTimedTextActivityDetector?
    private var vadDetector: VoiceActivityDetecting?
    private let localNoTextFallbackDetector = VoiceNoTextFallbackDetector()
    
    private let audioNormalizer = SpeechAudioNormalizer()
    private var currentSegmentAudioBuffer: [Float] = []
    
    private let normalizedSampleRate = 16_000
    private(set) var pendingSegmentPrefixSamples: [Float] = []
    private(set) var lastSegmentAudioSamplesCount: Int = 0
    private(set) var lastSegmentOverlapSamplesCount: Int = 0
    
    private(set) var vadStatus: String = "Not started"
    private(set) var vadModelLoaded: Bool = false

    private var hasStarted = false
    private var didAttemptVADSetup = false
    private var processingTask: Task<Void, Never>?
    private var lastClosedAppleText: String?

    var onStateChanged: (() -> Void)?
    var onSilenceClosed: (() -> Void)?
    var onCommittedText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onVADStatusChanged: ((String) -> Void)?
    var onVADProbabilityChanged: ((Float?) -> Void)?
    var onSilenceStateChanged: ((Bool) -> Void)?

    init(
        config: VoiceAudioTranscriptionConfig,
        queue: VoiceAudioTranscriptionQueue,
        whisperPostProcessor: WhisperPostProcessing
    ) {
        self.config = config
        self.queue = queue
        self.whisperPostProcessor = whisperPostProcessor
    }

    private func setupVADIfNeeded() {
        if didAttemptVADSetup && vadModelLoaded { return }
        didAttemptVADSetup = true

        switch config.vadMode {
        case .timedTextActivity:
            self.timedTextDetector = VoiceTimedTextActivityDetector(config: config)
            self.vadStatus = "Timed text activity"
            self.vadModelLoaded = false
        case .localModel:
            do {
                let localVAD = try VoiceLocalModelVAD(config: config)
                self.vadDetector = localVAD
                self.vadStatus = "Local VAD model loaded"
                self.vadModelLoaded = true
                bindLocalVADCallbacks(localVAD)
            } catch {
                self.vadStatus = error.localizedDescription
                self.vadModelLoaded = false
                onError?(error.localizedDescription)
            }
        }

        onVADStatusChanged?(vadStatus)
        onStateChanged?()
    }

    private func bindLocalVADCallbacks(_ localVAD: VoiceLocalModelVAD) {
        localVAD.onSpeechStarted = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateVADStatus("Speech detected")
                self.onSilenceStateChanged?(false)
            }
        }
        
        localVAD.onSpeechEnded = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateVADStatus("Silence detected")
                self.onSilenceStateChanged?(true)
                self.closeRealtimeDueToSilence()
                self.onStateChanged?()
            }
        }
    }
    
    private func updateVADStatus(_ status: String) {
        self.vadStatus = status
        onVADStatusChanged?(status)
        onStateChanged?()
    }

    func start() -> VoiceAudioTranscriptionStartResult {
        guard !hasStarted else { return .started }
        hasStarted = true

        setupVADIfNeeded()

        if config.vadMode == .localModel && !vadModelLoaded {
            return .failed(vadStatus)
        }

        vadDetector?.start()

        if config.vadMode == .localModel {
            updateVADStatus("VAD ready")
            onSilenceStateChanged?(true)
        }
        
        return .started
    }

    func handleRealtimeText(_ text: String) {
        if let lastClosedText = lastClosedAppleText, text == lastClosedText {
            lastClosedAppleText = nil
            return
        }
        lastClosedAppleText = nil

        let didChange = queue.updateRealtimeText(text)
        
        onSilenceStateChanged?(false)

        if config.vadMode == .timedTextActivity {
            timedTextDetector?.markTextActivity { [weak self] in
                self?.onSilenceStateChanged?(true)
                self?.closeRealtimeDueToSilence()
            }
        } else {
            if didChange {
                localNoTextFallbackDetector.markTextChanged(interval: config.vadNoTextFallbackInterval) { [weak self] in
                    self?.forceCloseRealtimeDueToNoTextFallback()
                }
            }
        }

        onStateChanged?()
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        do {
            let normalizedSamples = try audioNormalizer.normalize(buffer)

            if currentSegmentAudioBuffer.isEmpty, !pendingSegmentPrefixSamples.isEmpty {
                currentSegmentAudioBuffer.append(contentsOf: pendingSegmentPrefixSamples)
                pendingSegmentPrefixSamples.removeAll(keepingCapacity: true)
            }

            currentSegmentAudioBuffer.append(contentsOf: normalizedSamples)

            vadDetector?.processAudioSamples(normalizedSamples)
            onVADProbabilityChanged?(vadDetector?.latestProbability)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func closeRealtimeDueToSilence() {
        let samples = currentSegmentAudioBuffer

        let overlapCount = Int(Double(normalizedSampleRate) * config.segmentAudioOverlapDuration)
        let overlapSamples = overlapCount > 0 ? Array(samples.suffix(overlapCount)) : []

        lastSegmentAudioSamplesCount = samples.count
        lastSegmentOverlapSamplesCount = overlapSamples.count

        currentSegmentAudioBuffer.removeAll(keepingCapacity: true)
        pendingSegmentPrefixSamples = overlapSamples

        guard let segment = queue.closeRealtimeSegment(audioSamples: samples) else {
            if config.vadMode == .localModel {
                updateVADStatus("Silence detected, no realtime segment to close")
            }
            return
        }

        lastClosedAppleText = segment.appleText

        onSilenceClosed?()

        let duration = Date().timeIntervalSince(segment.startedAt)

        if duration < config.minimumSegmentDuration {
            onStateChanged?()
            return
        }

        onStateChanged?()
        startNextProcessingIfNeeded()
    }

    func startNextProcessingIfNeeded() {
        guard processingTask == nil else {
            return
        }

        guard let segment = queue.takeNextForProcessing() else {
            onStateChanged?()
            return
        }

        onStateChanged?()

        processingTask = Task { [weak self] in
            guard let self else {
                return
            }

            let processingStartTime = Date()

            do {
                let refinedText: String

                if await MainActor.run(body: { self.config.enablesWhisperPostProcessing }) {
                    refinedText = try await self.whisperPostProcessor.refineTranscription(segment.appleText, audioSamples: segment.audioSamples)
                } else {
                    refinedText = segment.appleText
                }

                if let minDuration = await MainActor.run(body: { self.config.debugMinimumPostProcessingDisplayDuration }) {
                    let elapsed = Date().timeIntervalSince(processingStartTime)
                    if elapsed < minDuration {
                        try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
                    }
                }

                await MainActor.run {
                    _ = self.queue.finishProcessing(
                        segmentID: segment.id,
                        refinedText: refinedText
                    )

                    self.onCommittedText?(refinedText)
                    self.processingTask = nil
                    self.onStateChanged?()
                    self.startNextProcessingIfNeeded()
                }
            } catch {
                await MainActor.run {
                    _ = self.queue.failProcessing(
                        segmentID: segment.id,
                        message: error.localizedDescription
                    )

                    if self.config.commitsAppleTextWhenWhisperFails {
                        self.onCommittedText?(segment.appleText)
                    } else {
                        self.onError?(error.localizedDescription)
                    }

                    self.processingTask = nil
                    self.onStateChanged?()
                    self.startNextProcessingIfNeeded()
                }
            }
        }
    }

    private func forceCloseRealtimeDueToNoTextFallback() {
        updateVADStatus("No text fallback triggered")
        onSilenceStateChanged?(true)
        closeRealtimeDueToSilence()
    }

    func stop() {
        hasStarted = false
        timedTextDetector?.cancel()
        localNoTextFallbackDetector.cancel()
        vadDetector?.stop()
        closeRealtimeDueToSilence()
    }

    func cancelAll() {
        hasStarted = false
        timedTextDetector?.cancel()
        localNoTextFallbackDetector.cancel()
        vadDetector?.stop()
        vadDetector?.reset()
        processingTask?.cancel()
        processingTask = nil
        queue.clearAll()
        currentSegmentAudioBuffer.removeAll(keepingCapacity: false)
        pendingSegmentPrefixSamples.removeAll(keepingCapacity: false)
        lastSegmentAudioSamplesCount = 0
        lastSegmentOverlapSamplesCount = 0
        lastClosedAppleText = nil
        updateVADStatus(config.vadMode == .localModel ? "Local VAD model loaded" : "Timed text activity")
        onSilenceStateChanged?(true)
        onStateChanged?()
    }
}
