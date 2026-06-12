import SwiftUI
import AppKit

enum DSAudioTranscriptionLivePreviewSettingsStore {
    private static let prefix = "DSAudioTranscriptionLivePreview."

    private static func loadDouble(forKey key: String, default defaultValue: Double) -> Double {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) != nil ? defaults.double(forKey: key) : defaultValue
    }

    private static func loadBool(forKey key: String, default defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) != nil ? defaults.bool(forKey: key) : defaultValue
    }

    static func loadConfig() -> VoiceAudioTranscriptionConfig {
        let defaults = UserDefaults.standard

        var config = VoiceAudioTranscriptionConfig.default
        config.silenceBreakInterval = loadDouble(forKey: prefix + "silenceBreakInterval", default: config.silenceBreakInterval)
        config.minimumSegmentDuration = loadDouble(forKey: prefix + "minimumSegmentDuration", default: config.minimumSegmentDuration)
        config.maximumSegmentDuration = loadDouble(forKey: prefix + "maximumSegmentDuration", default: config.maximumSegmentDuration)
        config.realtimeDebounceInterval = loadDouble(forKey: prefix + "realtimeDebounceInterval", default: config.realtimeDebounceInterval)
        config.enablesWhisperPostProcessing = loadBool(forKey: prefix + "enablesWhisperPostProcessing", default: config.enablesWhisperPostProcessing)
        config.commitsAppleTextWhenWhisperFails = loadBool(forKey: prefix + "commitsAppleTextWhenWhisperFails", default: config.commitsAppleTextWhenWhisperFails)
        config.appleSpeechLanguage = defaults.string(forKey: prefix + "appleSpeechLanguage")
            ?? defaults.string(forKey: prefix + "appleSpeechLanguageOption")
            ?? defaults.string(forKey: prefix + "selectedLanguageOption")
            ?? config.appleSpeechLanguage
        config.whisperLanguage = defaults.string(forKey: prefix + "whisperLanguage") ?? config.whisperLanguage
        config.whisperTask = WhisperTranscriptionTask(rawValue: defaults.string(forKey: prefix + "whisperTask") ?? config.whisperTask.rawValue) ?? config.whisperTask
        config.enablesAppleSpeech = loadBool(forKey: prefix + "enablesAppleSpeech", default: config.enablesAppleSpeech)
        config.whisperModelPath = trimmedOptional(defaults.string(forKey: prefix + "whisperModelPath"))
        config.whisperCoreMLModelPath = trimmedOptional(defaults.string(forKey: prefix + "whisperCoreMLModelPath"))
        config.whisperTranscriptionUsesCPUOnly = loadBool(forKey: prefix + "whisperTranscriptionUsesCPUOnly", default: config.whisperTranscriptionUsesCPUOnly)
        config.whisperTranscriptionCPUThreadCount = Int(loadDouble(forKey: prefix + "whisperTranscriptionCPUThreadCount", default: Double(config.whisperTranscriptionCPUThreadCount)))
        config.vadMode = VoiceVADMode(rawValue: defaults.string(forKey: prefix + "vadMode") ?? config.vadMode.rawValue) ?? config.vadMode
        config.vadModelPath = trimmedOptional(defaults.string(forKey: prefix + "vadModelPath"))
        config.vadThreshold = loadDouble(forKey: prefix + "vadThreshold", default: config.vadThreshold)
        config.vadMinSpeechDuration = loadDouble(forKey: prefix + "vadMinSpeechDuration", default: config.vadMinSpeechDuration)
        config.vadMinSilenceDuration = loadDouble(forKey: prefix + "vadMinSilenceDuration", default: config.vadMinSilenceDuration)
        config.vadNoTextFallbackInterval = loadDouble(forKey: prefix + "vadNoTextFallbackInterval", default: config.vadNoTextFallbackInterval)
        config.segmentAudioOverlapDuration = loadDouble(forKey: prefix + "segmentAudioOverlapDuration", default: config.segmentAudioOverlapDuration)
        config.paragraphBreakSilenceDuration = loadDouble(forKey: prefix + "paragraphBreakSilenceDuration", default: config.paragraphBreakSilenceDuration)
        config.enablesParagraphBreaks = loadBool(forKey: prefix + "enablesParagraphBreaks", default: config.enablesParagraphBreaks)

        return config
    }

    static func save(config: VoiceAudioTranscriptionConfig) {
        let defaults = UserDefaults.standard
        defaults.set(config.silenceBreakInterval, forKey: prefix + "silenceBreakInterval")
        defaults.set(config.minimumSegmentDuration, forKey: prefix + "minimumSegmentDuration")
        defaults.set(config.maximumSegmentDuration, forKey: prefix + "maximumSegmentDuration")
        defaults.set(config.realtimeDebounceInterval, forKey: prefix + "realtimeDebounceInterval")
        defaults.set(config.enablesWhisperPostProcessing, forKey: prefix + "enablesWhisperPostProcessing")
        defaults.set(config.commitsAppleTextWhenWhisperFails, forKey: prefix + "commitsAppleTextWhenWhisperFails")
        defaults.set(config.appleSpeechLanguage, forKey: prefix + "appleSpeechLanguage")
        defaults.set(config.whisperLanguage, forKey: prefix + "whisperLanguage")
        defaults.set(config.whisperTask.rawValue, forKey: prefix + "whisperTask")
        defaults.set(config.enablesAppleSpeech, forKey: prefix + "enablesAppleSpeech")
        defaults.set(config.whisperModelPath ?? "", forKey: prefix + "whisperModelPath")
        defaults.set(config.whisperCoreMLModelPath ?? "", forKey: prefix + "whisperCoreMLModelPath")
        defaults.set(config.whisperTranscriptionUsesCPUOnly, forKey: prefix + "whisperTranscriptionUsesCPUOnly")
        defaults.set(config.whisperTranscriptionCPUThreadCount, forKey: prefix + "whisperTranscriptionCPUThreadCount")
        defaults.set(config.vadMode.rawValue, forKey: prefix + "vadMode")
        defaults.set(config.vadModelPath ?? "", forKey: prefix + "vadModelPath")
        defaults.set(config.vadThreshold, forKey: prefix + "vadThreshold")
        defaults.set(config.vadMinSpeechDuration, forKey: prefix + "vadMinSpeechDuration")
        defaults.set(config.vadMinSilenceDuration, forKey: prefix + "vadMinSilenceDuration")
        defaults.set(config.vadNoTextFallbackInterval, forKey: prefix + "vadNoTextFallbackInterval")
        defaults.set(config.segmentAudioOverlapDuration, forKey: prefix + "segmentAudioOverlapDuration")
        defaults.set(config.paragraphBreakSilenceDuration, forKey: prefix + "paragraphBreakSilenceDuration")
        defaults.set(config.enablesParagraphBreaks, forKey: prefix + "enablesParagraphBreaks")
        defaults.synchronize()
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct DSAudioTranscriptionInputLiveVoicePreview: View {
    @State private var configID = UUID()
    @State private var text: String = ""
    @State private var config: VoiceAudioTranscriptionConfig
    @State private var appliedConfig: VoiceAudioTranscriptionConfig

    init() {
        let initialConfig = DSAudioTranscriptionLivePreviewSettingsStore.loadConfig()
        self._config = State(initialValue: initialConfig)
        self._appliedConfig = State(initialValue: initialConfig)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            DSAudioTranscriptionInputLiveVoicePreviewContent(
                text: $text,
                config: appliedConfig
            )
            .id(configID)

            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(.headline)

                // The preview owns persistence and controller recreation.
                // The form only edits `VoiceAudioTranscriptionConfig`.
                VoiceAudioTranscriptionConfigForm(
                    config: $config,
                    showsFilePickers: true,
                    onChange: { newConfig in
                        DSAudioTranscriptionLivePreviewSettingsStore.save(config: newConfig)
                    }
                )

                Button("Apply Settings") {
                    DSAudioTranscriptionLivePreviewSettingsStore.save(config: config)
                    appliedConfig = config
                    configID = UUID()
                }
                .buttonStyle(.borderedProminent)

                Text("Recreates the transcription controller with the configured values.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Audio Transcription")
                .font(.title2)
                .bold()

            Text("Use this screen to validate microphone capture, Apple realtime recognition, silence segmentation, queueing, post-processing, paragraph breaks and committed text append.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DSAudioTranscriptionInputLiveVoicePreviewContent: View {
    @Binding var text: String
    let config: VoiceAudioTranscriptionConfig

    @StateObject private var controller: VoiceAudioTranscriptionController

    init(text: Binding<String>, config: VoiceAudioTranscriptionConfig) {
        self._text = text
        self.config = config
        self._controller = StateObject(
            wrappedValue: VoiceAudioTranscriptionController(config: config)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSAudioTranscriptionInput(
                title: "Live Audio Transcription",
                placeholder: "Type or speak...",
                mode: .textarea,
                text: $text,
                controller: controller,
                config: .default
            )
            .frame(maxWidth: .infinity)

            debugState
        }
    }

    private var debugState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug state")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Lifecycle")
                    Text(String(describing: controller.lifecycle))
                }

                GridRow {
                    Text("Listening")
                    Text(controller.isListening ? "true" : "false")
                }

                GridRow {
                    Text("Silent")
                    Text(controller.isSilent ? "true" : "false")
                }

                GridRow {
                    Text("Apple Speech Language")
                    Text(config.appleSpeechLanguage)
                }

                GridRow {
                    Text("Whisper Language")
                    Text(config.whisperLanguage)
                }

                GridRow {
                    Text("Whisper Task")
                    Text(config.whisperTask.rawValue)
                }

                GridRow {
                    Text("Whisper Enabled")
                    Text(config.enablesWhisperPostProcessing ? "true" : "false")
                }

                GridRow {
                    Text("Whisper Model Path present")
                    Text(config.whisperModelPath != nil ? "true (\(config.whisperModelPath!.split(separator: "/").last ?? ""))" : "false")
                }

                GridRow {
                    Text("Whisper CoreML Path present")
                    Text(config.whisperCoreMLModelPath != nil ? "true (\(config.whisperCoreMLModelPath!.split(separator: "/").last ?? ""))" : "false")
                }

                GridRow {
                    Text("Whisper CPU only")
                    Text(config.whisperTranscriptionUsesCPUOnly ? "true" : "false")
                }

                if config.whisperTranscriptionUsesCPUOnly {
                    GridRow {
                        Text("Whisper CPU threads")
                        Text("\(Int(config.whisperTranscriptionCPUThreadCount))")
                    }
                }

                GridRow {
                    Text("VAD Mode")
                    Text(String(describing: config.vadMode))
                }

                if config.vadMode == .localModel {
                    GridRow {
                        Text("VAD runtime")
                        Text("whisper.cpp")
                    }

                    GridRow {
                        Text("VAD model loaded")
                        Text(controller.vadModelLoaded ? "true" : "false")
                    }

                    GridRow {
                        Text("Latest VAD probability")
                        if let prob = controller.vadProbability {
                            Text(prob, format: .number.precision(.fractionLength(3)))
                        } else {
                            Text("nil")
                        }
                    }
                }

                GridRow {
                    Text("Last VAD event")
                    Text(controller.vadStatusText ?? "none")
                }

                if config.vadMode == .localModel {
                    GridRow {
                        Text("No-text fallback")
                        Text("\(config.vadNoTextFallbackInterval, format: .number.precision(.fractionLength(1)))s")
                    }
                }

                GridRow {
                    Text("Realtime segment present")
                    Text(controller.inlineSegments.contains { $0.kind == .appleRealtime } ? "true" : "false")
                }

                GridRow {
                    Text("Whisper segment samples")
                    if let processingSegment = controller.inlineSegments.first(where: { $0.kind == .whisperProcessing }) {
                        Text("\(processingSegment.audioSamplesCount ?? 0)")
                    } else {
                        Text("none")
                    }
                }

                GridRow {
                    Text("Segment audio overlap")
                    Text("\(config.segmentAudioOverlapDuration, format: .number.precision(.fractionLength(2)))s")
                }

                GridRow {
                    Text("Last segment audio samples")
                    Text("\(controller.lastSegmentAudioSamplesCount)")
                }

                GridRow {
                    Text("Last segment overlap samples")
                    Text("\(controller.lastSegmentOverlapSamplesCount)")
                }

                GridRow {
                    Text("Paragraph breaks enabled")
                    Text(config.enablesParagraphBreaks ? "true" : "false")
                }

                if config.enablesParagraphBreaks {
                    GridRow {
                        Text("Paragraph break silence")
                        Text("\(config.paragraphBreakSilenceDuration, format: .number.precision(.fractionLength(1)))s")
                    }

                    GridRow {
                        Text("Text mutation revision")
                        Text("\(controller.textMutationRevision)")
                    }
                }

                GridRow {
                    Text("Inline segment count")
                    Text("\(controller.inlineSegments.count)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
