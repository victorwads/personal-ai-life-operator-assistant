import Foundation
import WhisperCPP

protocol SpeechFinalTextResolving: Sendable {
    func warmUp(whisperConfig: WhisperPostProcessingConfig?) async

    func resolveFinalText(
        appleSpeechText: String,
        capturedAudioSamples: [Float],
        whisperConfig: WhisperPostProcessingConfig?,
        cancellationToken: WhisperProcessingCancellationToken
    ) async -> String
}

final class WhisperProcessingCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

actor WhisperSpeechPostProcessor: SpeechFinalTextResolving {
    static let shared = WhisperSpeechPostProcessor()

    private var cachedContexts: [String: WhisperModelContext] = [:]

    init() {
        WhisperRuntimeLogRouter.installIfNeeded()
    }

    func warmUp(whisperConfig: WhisperPostProcessingConfig?) async {
        guard let resolvedModelPath = prepareIfPossible(whisperConfig: whisperConfig) else {
            return
        }

        do {
            _ = try context(
                for: resolvedModelPath,
                useGPU: !(whisperConfig?.usesCPUOnly ?? false)
            )
        } catch {
            print("[SpeechListener] Whisper warm-up failed: \(error)")
        }
    }

    func resolveFinalText(
        appleSpeechText: String,
        capturedAudioSamples: [Float],
        whisperConfig: WhisperPostProcessingConfig?,
        cancellationToken: WhisperProcessingCancellationToken
    ) async -> String {
        guard let resolvedModelPath = prepareIfPossible(whisperConfig: whisperConfig) else {
            return appleSpeechText
        }

        guard !capturedAudioSamples.isEmpty else {
            print("[SpeechListener] No captured audio available for Whisper post-processing. Falling back to Apple Speech final text.")
            return appleSpeechText
        }

        guard !cancellationToken.isCancelled else {
            return appleSpeechText
        }

        do {
            let context = try context(
                for: resolvedModelPath,
                useGPU: !(whisperConfig?.usesCPUOnly ?? false)
            )
            print("[SpeechListener] Whisper post-processing starting: model=\(resolvedModelPath), language=\(whisperConfig?.language ?? "auto"), samples=\(capturedAudioSamples.count), duration=\(formatSeconds(sampleCount: capturedAudioSamples.count))s, audio=\(audioSummary(capturedAudioSamples))")
            let whisperText = try context.transcribe(
                samples: capturedAudioSamples,
                language: whisperConfig?.language ?? "auto",
                task: whisperConfig?.task ?? .transcribe,
                cancellationToken: cancellationToken,
                threadCount: whisperConfig?.usesCPUOnly == true ? whisperConfig?.cpuThreadCount : nil
            )

            let trimmedText = whisperText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                print("[SpeechListener] Whisper post-processing returned empty text. Falling back to Apple Speech final text.")
                return appleSpeechText
            }

            return trimmedText
        } catch {
            print("[SpeechListener] Whisper post-processing failed: \(error). Falling back to Apple Speech final text.")
            return appleSpeechText
        }
    }

    private func prepareIfPossible(whisperConfig: WhisperPostProcessingConfig?) -> String? {
        guard let whisperConfig, whisperConfig.isEnabled else {
            return nil
        }

        let trimmedModelPath = whisperConfig.modelPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedModelPath.isEmpty else {
            print("[SpeechListener] Whisper post-processing enabled without modelPath. Falling back to Apple Speech final text.")
            return nil
        }

        guard FileManager.default.fileExists(atPath: trimmedModelPath) else {
            print("[SpeechListener] Whisper model not found at path: \(trimmedModelPath). Falling back to Apple Speech final text.")
            return nil
        }

        print("[SpeechListener] Whisper model configured: \(trimmedModelPath)")
        guard let preparedModelPath = ensureCoreMLCompanionIfNeeded(
            modelPath: trimmedModelPath,
            configuredCoreMLModelPath: whisperConfig.coreMLModelPath,
            usesCPUOnly: whisperConfig.usesCPUOnly
        ) else {
            return nil
        }

        return preparedModelPath
    }

    private func ensureCoreMLCompanionIfNeeded(
        modelPath: String,
        configuredCoreMLModelPath: String?,
        usesCPUOnly: Bool
    ) -> String? {
        if usesCPUOnly {
            print("[SpeechListener] Whisper CPU-only mode enabled. Skipping Core ML companion setup.")
            return modelPath
        }

        let trimmedCoreMLModelPath = configuredCoreMLModelPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedCoreMLModelPath.isEmpty else {
            print("[SpeechListener] Whisper Core ML companion not configured. Using ggml model with available GPU backend.")
            return modelPath
        }

        let standardizedConfiguredPath = URL(fileURLWithPath: trimmedCoreMLModelPath).standardizedFileURL.path
        print("[SpeechListener] Whisper Core ML companion configured: \(standardizedConfiguredPath)")
        guard FileManager.default.fileExists(atPath: standardizedConfiguredPath) else {
            print("[SpeechListener] Whisper Core ML companion not found at path: \(standardizedConfiguredPath). Continuing with the ggml model path only.")
            return modelPath
        }

        let expectedCompanionPath = expectedCoreMLCompanionPath(for: modelPath)
        let standardizedExpectedPath = URL(fileURLWithPath: expectedCompanionPath).standardizedFileURL.path
        print("[SpeechListener] Whisper Core ML companion expected by whisper.cpp: \(standardizedExpectedPath)")
        if standardizedConfiguredPath == standardizedExpectedPath {
            print("[SpeechListener] Whisper Core ML companion already matches expected path.")
            return modelPath
        }

        do {
            if FileManager.default.fileExists(atPath: standardizedExpectedPath) {
                if let symlinkDestination = try? FileManager.default.destinationOfSymbolicLink(atPath: standardizedExpectedPath) {
                    let absoluteDestinationPath = URL(fileURLWithPath: symlinkDestination, relativeTo: URL(fileURLWithPath: standardizedExpectedPath).deletingLastPathComponent())
                        .standardizedFileURL
                        .path

                    if absoluteDestinationPath == standardizedConfiguredPath {
                        print("[SpeechListener] Whisper Core ML companion symlink already points to configured path.")
                        return modelPath
                    }

                    try FileManager.default.removeItem(atPath: standardizedExpectedPath)
                } else {
                    print("[SpeechListener] Whisper Core ML expected companion path already exists and is not a symlink. Leaving it in place.")
                    return modelPath
                }
            }

            try FileManager.default.createSymbolicLink(
                atPath: standardizedExpectedPath,
                withDestinationPath: standardizedConfiguredPath
            )
            print("[SpeechListener] Linked Whisper Core ML companion into the expected model directory: \(standardizedExpectedPath)")
        } catch {
            print("[SpeechListener] Failed to link Whisper Core ML companion: \(error). Continuing with the ggml model path only.")
        }

        return modelPath
    }

    private func expectedCoreMLCompanionPath(for modelPath: String) -> String {
        let modelURL = URL(fileURLWithPath: modelPath)
        let modelFilename = modelURL.lastPathComponent
        let companionFilename: String

        if modelFilename.hasSuffix(".bin") {
            companionFilename = String(modelFilename.dropLast(4)) + "-encoder.mlmodelc"
        } else {
            companionFilename = modelFilename + "-encoder.mlmodelc"
        }

        return modelURL.deletingLastPathComponent()
            .appendingPathComponent(companionFilename)
            .path
    }

    private func context(for modelPath: String, useGPU: Bool) throws -> WhisperModelContext {
        let cacheKey = "\(modelPath)|useGPU:\(useGPU)"

        if let cachedContext = cachedContexts[cacheKey] {
            print("[SpeechListener] Reusing cached Whisper model context for \(modelPath) with use_gpu=\(useGPU).")
            return cachedContext
        }

        print("[SpeechListener] Creating Whisper model context for \(modelPath) with use_gpu=\(useGPU).")
        let context = try WhisperModelContext(modelPath: modelPath, useGPU: useGPU)
        cachedContexts[cacheKey] = context
        return context
    }

    private func audioSummary(_ samples: [Float]) -> String {
        guard !samples.isEmpty else {
            return "empty"
        }

        var peak: Float = 0
        var absoluteSum: Double = 0
        var leadingZeroCount = 0
        var foundNonZero = false

        for sample in samples {
            let absoluteValue = abs(sample)
            peak = max(peak, absoluteValue)
            absoluteSum += Double(absoluteValue)

            if !foundNonZero && absoluteValue < 0.000001 {
                leadingZeroCount += 1
            } else {
                foundNonZero = true
            }
        }

        let averageAbsoluteAmplitude = absoluteSum / Double(samples.count)
        return "peak=\(format(peak)), avgAbs=\(format(averageAbsoluteAmplitude)), leadingNearZeroSamples=\(leadingZeroCount)"
    }

    private func formatSeconds(sampleCount: Int) -> String {
        format(Double(sampleCount) / Double(WHISPER_SAMPLE_RATE))
    }

    private func format(_ value: Float) -> String {
        format(Double(value))
    }

    private func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private final class WhisperModelContext: @unchecked Sendable {
    private let modelPath: String
    private let context: OpaquePointer

    init(modelPath: String, useGPU: Bool) throws {
        self.modelPath = modelPath

        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = useGPU

        print("[SpeechListener] Whisper context params: use_gpu=\(contextParams.use_gpu), model=\(modelPath)")
        guard let context = modelPath.withCString({ whisper_init_from_file_with_params($0, contextParams) }) else {
            throw WhisperSpeechPostProcessorError.initializationFailed(modelPath)
        }

        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func transcribe(
        samples: [Float],
        language: String,
        task: WhisperTranscriptionTask,
        cancellationToken: WhisperProcessingCancellationToken,
        threadCount: Int? = nil
    ) throws -> String {
        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveLanguage = normalizedLanguage.isEmpty ? "auto" : normalizedLanguage

        let primaryRequest = WhisperTranscriptionRequest(
            language: effectiveLanguage,
            strategy: .primary,
            label: "primary"
        )
        let primaryText = try transcribe(
            samples: samples,
            request: primaryRequest,
            task: task,
            cancellationToken: cancellationToken,
            threadCount: threadCount
        )
        if !primaryText.isEmpty {
            return primaryText
        }

        print("[SpeechListener] Whisper returned empty text on first pass. Retrying with a more permissive decode configuration.")

        let retryRequest = WhisperTranscriptionRequest(
            language: effectiveLanguage,
            strategy: .permissive,
            label: "retry"
        )
        let retryText = try transcribe(
            samples: samples,
            request: retryRequest,
            task: task,
            cancellationToken: cancellationToken,
            threadCount: threadCount
        )
        if !retryText.isEmpty {
            return retryText
        }

        if effectiveLanguage == "auto" {
            print("[SpeechListener] Whisper auto language path stayed empty. Retrying once more with forced Portuguese and beam search.")
            let forcedPortugueseRequest = WhisperTranscriptionRequest(
                language: "pt",
                strategy: .forcedLanguage,
                label: "forced-pt"
            )
            return try transcribe(
                samples: samples,
                request: forcedPortugueseRequest,
                task: task,
                cancellationToken: cancellationToken,
                threadCount: threadCount
            )
        }

        return retryText
    }

    private func transcribe(
        samples: [Float],
        request: WhisperTranscriptionRequest,
        task: WhisperTranscriptionTask,
        cancellationToken: WhisperProcessingCancellationToken,
        threadCount: Int?
    ) throws -> String {
        guard !cancellationToken.isCancelled else {
            throw WhisperSpeechPostProcessorError.cancelled
        }

        var params = whisper_full_default_params(request.strategy.samplingStrategy)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.no_timestamps = true
        params.no_context = request.strategy.usesNoContext
        params.single_segment = request.strategy.usesSingleSegment
        params.translate = (task == .translate)
        params.suppress_blank = request.strategy.suppressesBlank
        params.suppress_nst = request.strategy.suppressesNonSpeechTokens
        params.temperature = request.strategy.temperature
        params.temperature_inc = request.strategy.temperatureIncrement
        params.n_threads = threadCount.map { max(1, Int32($0)) } ?? max(1, Int32(ProcessInfo.processInfo.processorCount - 1))
        params.no_speech_thold = request.strategy.noSpeechThreshold
        params.logprob_thold = request.strategy.logprobThreshold
        params.entropy_thold = request.strategy.entropyThreshold

        if request.strategy.usesBeamSearch {
            params.beam_search.beam_size = request.strategy.beamSize
        }

        params.abort_callback = { userData in
            guard let userData else {
                return false
            }

            let token = Unmanaged<WhisperProcessingCancellationToken>
                .fromOpaque(userData)
                .takeUnretainedValue()
            return token.isCancelled
        }
        params.abort_callback_user_data = Unmanaged.passUnretained(cancellationToken).toOpaque()

        if request.language.isEmpty || request.language == "auto" {
            params.language = nil
            params.detect_language = true
            print("[SpeechListener] Whisper decode pass '\(request.label)': language=auto, samples=\(samples.count), strategy=\(request.strategy.name), noContext=\(params.no_context), singleSegment=\(params.single_segment), suppressBlank=\(params.suppress_blank), suppressNST=\(params.suppress_nst), temperature=\(params.temperature), temperatureInc=\(params.temperature_inc), noSpeechThold=\(params.no_speech_thold), logprobThold=\(params.logprob_thold), entropyThold=\(params.entropy_thold)")
            return try runWhisper(samples: samples, params: params, cancellationToken: cancellationToken)
        }

        return try request.language.withCString { languageCString in
            var localParams = params
            localParams.language = languageCString
            localParams.detect_language = false
            print("[SpeechListener] Whisper decode pass '\(request.label)': language=\(request.language), samples=\(samples.count), strategy=\(request.strategy.name), noContext=\(localParams.no_context), singleSegment=\(localParams.single_segment), suppressBlank=\(localParams.suppress_blank), suppressNST=\(localParams.suppress_nst), temperature=\(localParams.temperature), temperatureInc=\(localParams.temperature_inc), noSpeechThold=\(localParams.no_speech_thold), logprobThold=\(localParams.logprob_thold), entropyThold=\(localParams.entropy_thold)")
            return try runWhisper(samples: samples, params: localParams, cancellationToken: cancellationToken)
        }
    }

    private func runWhisper(
        samples: [Float],
        params: whisper_full_params,
        cancellationToken: WhisperProcessingCancellationToken
    ) throws -> String {
        let status = try samples.withUnsafeBufferPointer { bufferPointer -> Int32 in
            guard let baseAddress = bufferPointer.baseAddress else {
                throw WhisperSpeechPostProcessorError.emptyAudio
            }

            return whisper_full(context, params, baseAddress, Int32(bufferPointer.count))
        }

        if cancellationToken.isCancelled {
            throw WhisperSpeechPostProcessorError.cancelled
        }

        guard status == 0 else {
            throw WhisperSpeechPostProcessorError.transcriptionFailed(modelPath: modelPath, status: status)
        }

        let segmentCount = Int(whisper_full_n_segments(context))
        print("[SpeechListener] Whisper returned \(segmentCount) segment(s).")
        guard segmentCount > 0 else {
            if let wavPath = WhisperDebugAudioWriter.writeTemporaryWAV(samples: samples) {
                print("[SpeechListener] Whisper produced zero segments. Exported debug WAV to \(wavPath)")
            }
            return ""
        }

        let segmentTexts = (0..<segmentCount)
            .compactMap { index -> String? in
                guard let segment = whisper_full_get_segment_text(context, Int32(index)) else {
                    print("[SpeechListener] Whisper segment \(index): <nil>")
                    return nil
                }

                let text = String(cString: segment)
                print("[SpeechListener] Whisper segment \(index): '\(text)'")
                return text
            }

        let text = segmentTexts
            .joined()
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }
}

private struct WhisperTranscriptionRequest {
    let language: String
    let strategy: WhisperDecodeStrategy
    let label: String
}

private struct WhisperDecodeStrategy {
    let name: String
    let samplingStrategy: whisper_sampling_strategy
    let usesNoContext: Bool
    let usesSingleSegment: Bool
    let suppressesBlank: Bool
    let suppressesNonSpeechTokens: Bool
    let temperature: Float
    let temperatureIncrement: Float
    let noSpeechThreshold: Float
    let logprobThreshold: Float
    let entropyThreshold: Float
    let usesBeamSearch: Bool
    let beamSize: Int32

    static let primary = WhisperDecodeStrategy(
        name: "primary",
        samplingStrategy: WHISPER_SAMPLING_GREEDY,
        usesNoContext: true,
        usesSingleSegment: false,
        suppressesBlank: true,
        suppressesNonSpeechTokens: true,
        temperature: 0.0,
        temperatureIncrement: 0.0,
        noSpeechThreshold: 0.6,
        logprobThreshold: -1.0,
        entropyThreshold: 2.4,
        usesBeamSearch: false,
        beamSize: 1
    )

    static let permissive = WhisperDecodeStrategy(
        name: "permissive",
        samplingStrategy: WHISPER_SAMPLING_BEAM_SEARCH,
        usesNoContext: false,
        usesSingleSegment: false,
        suppressesBlank: false,
        suppressesNonSpeechTokens: false,
        temperature: 0.4,
        temperatureIncrement: 0.2,
        noSpeechThreshold: 0.99,
        logprobThreshold: -99.0,
        entropyThreshold: 10.0,
        usesBeamSearch: true,
        beamSize: 5
    )

    static let forcedLanguage = WhisperDecodeStrategy(
        name: "forced-language",
        samplingStrategy: WHISPER_SAMPLING_BEAM_SEARCH,
        usesNoContext: false,
        usesSingleSegment: false,
        suppressesBlank: false,
        suppressesNonSpeechTokens: false,
        temperature: 0.4,
        temperatureIncrement: 0.2,
        noSpeechThreshold: 0.99,
        logprobThreshold: -99.0,
        entropyThreshold: 10.0,
        usesBeamSearch: true,
        beamSize: 5
    )
}

private enum WhisperRuntimeLogRouter {
    private static let installLock = NSLock()
    private static var isInstalled = false

    static func installIfNeeded() {
        installLock.lock()
        defer { installLock.unlock() }

        guard !isInstalled else {
            return
        }

        whisper_log_set(whisperRuntimeLogCallback, nil)

        isInstalled = true
    }
}

private func whisperRuntimeLogCallback(
    _ level: ggml_log_level,
    _ text: UnsafePointer<CChar>?,
    _ userData: UnsafeMutableRawPointer?
) {
    guard let text else {
        return
    }

    let message = String(cString: text)
    if shouldSuppressWhisperRuntimeLog(message) {
        return
    }

    guard let data = message.data(using: .utf8) else {
        return
    }

    FileHandle.standardError.write(data)
}

private func shouldSuppressWhisperRuntimeLog(_ message: String) -> Bool {
    false
}

private enum WhisperSpeechPostProcessorError: LocalizedError {
    case cancelled
    case emptyAudio
    case initializationFailed(String)
    case transcriptionFailed(modelPath: String, status: Int32)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Whisper post-processing was cancelled."
        case .emptyAudio:
            return "Whisper post-processing received empty audio."
        case .initializationFailed(let modelPath):
            return "Failed to initialize Whisper model at \(modelPath)."
        case .transcriptionFailed(let modelPath, let status):
            return "Whisper transcription failed for \(modelPath) with status \(status)."
        }
    }
}
