import SwiftUI
import AppKit

enum DSAudioTranscriptionLivePreviewSettingsStore {
    private static let prefix = "DSAudioTranscriptionLivePreview."

    struct Settings {
        var silenceBreakInterval: Double
        var minimumSegmentDuration: Double
        var maximumSegmentDuration: Double
        
        var appleSpeechLanguageOption: String
        var appleSpeechCustomLanguage: String
        
        var whisperLanguage: String
        var whisperTask: String
        
        var enablesAppleSpeech: Bool
        var enablesLocalVAD: Bool
        
        var vadMode: String
        var vadModelPath: String
        var vadThreshold: Double
        var vadMinSpeechDuration: Double
        var vadMinSilenceDuration: Double
        var vadNoTextFallbackInterval: Double
        var whisperModelPath: String
        var whisperCoreMLModelPath: String
        var whisperTranscriptionUsesCPUOnly: Bool
        var whisperTranscriptionCPUThreadCount: Double
        var enablesWhisperPostProcessing: Bool
        var commitsAppleTextWhenWhisperFails: Bool
        var segmentAudioOverlapDuration: Double
        var paragraphBreakSilenceDuration: Double
        var enablesParagraphBreaks: Bool
    }

    private static func loadDouble(forKey key: String, default defaultValue: Double) -> Double {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) != nil ? defaults.double(forKey: key) : defaultValue
    }

    private static func loadBool(forKey key: String, default defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) != nil ? defaults.bool(forKey: key) : defaultValue
    }

    static func save(settings: Settings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.silenceBreakInterval, forKey: prefix + "silenceBreakInterval")
        defaults.set(settings.minimumSegmentDuration, forKey: prefix + "minimumSegmentDuration")
        defaults.set(settings.maximumSegmentDuration, forKey: prefix + "maximumSegmentDuration")
        defaults.set(settings.appleSpeechLanguageOption, forKey: prefix + "appleSpeechLanguageOption")
        defaults.set(settings.appleSpeechCustomLanguage, forKey: prefix + "appleSpeechCustomLanguage")
        defaults.set(settings.whisperLanguage, forKey: prefix + "whisperLanguage")
        defaults.set(settings.whisperTask, forKey: prefix + "whisperTask")
        defaults.set(settings.enablesAppleSpeech, forKey: prefix + "enablesAppleSpeech")
        defaults.set(settings.enablesLocalVAD, forKey: prefix + "enablesLocalVAD")
        defaults.set(settings.vadMode, forKey: prefix + "vadMode")
        defaults.set(settings.vadModelPath, forKey: prefix + "vadModelPath")
        defaults.set(settings.vadThreshold, forKey: prefix + "vadThreshold")
        defaults.set(settings.vadMinSpeechDuration, forKey: prefix + "vadMinSpeechDuration")
        defaults.set(settings.vadMinSilenceDuration, forKey: prefix + "vadMinSilenceDuration")
        defaults.set(settings.vadNoTextFallbackInterval, forKey: prefix + "vadNoTextFallbackInterval")
        defaults.set(settings.segmentAudioOverlapDuration, forKey: prefix + "segmentAudioOverlapDuration")
        defaults.set(settings.paragraphBreakSilenceDuration, forKey: prefix + "paragraphBreakSilenceDuration")
        defaults.set(settings.enablesParagraphBreaks, forKey: prefix + "enablesParagraphBreaks")
        defaults.set(settings.whisperModelPath, forKey: prefix + "whisperModelPath")
        defaults.set(settings.whisperCoreMLModelPath, forKey: prefix + "whisperCoreMLModelPath")
        defaults.set(settings.whisperTranscriptionUsesCPUOnly, forKey: prefix + "whisperTranscriptionUsesCPUOnly")
        defaults.set(settings.whisperTranscriptionCPUThreadCount, forKey: prefix + "whisperTranscriptionCPUThreadCount")
        defaults.set(settings.enablesWhisperPostProcessing, forKey: prefix + "enablesWhisperPostProcessing")
        defaults.set(settings.commitsAppleTextWhenWhisperFails, forKey: prefix + "commitsAppleTextWhenWhisperFails")
        defaults.synchronize()
    }

    static func load() -> Settings {
        let defaults = UserDefaults.standard
        
        let oldLanguage = defaults.string(forKey: prefix + "selectedLanguageOption")
        let appleLangOpt = defaults.string(forKey: prefix + "appleSpeechLanguageOption") ?? oldLanguage ?? "auto"
        let customLang = defaults.string(forKey: prefix + "customLanguage") ?? ""
        let appleCustomLang = defaults.string(forKey: prefix + "appleSpeechCustomLanguage") ?? customLang
        
        let whisperLang = defaults.string(forKey: prefix + "whisperLanguage") ?? "pt"
        let whisperTsk = defaults.string(forKey: prefix + "whisperTask") ?? "transcribe"
        
        let enablesApple = loadBool(forKey: prefix + "enablesAppleSpeech", default: true)
        
        let enablesVAD = defaults.object(forKey: prefix + "enablesLocalVAD") != nil ?
            defaults.bool(forKey: prefix + "enablesLocalVAD") :
            (defaults.string(forKey: prefix + "vadMode") == VoiceVADMode.localModel.rawValue)
        
        let savedVadMode = (enablesVAD ? VoiceVADMode.localModel : VoiceVADMode.timedTextActivity).rawValue
        
        return Settings(
            silenceBreakInterval: loadDouble(forKey: prefix + "silenceBreakInterval", default: 0.45),
            minimumSegmentDuration: loadDouble(forKey: prefix + "minimumSegmentDuration", default: 0.35),
            maximumSegmentDuration: loadDouble(forKey: prefix + "maximumSegmentDuration", default: 20.0),
            appleSpeechLanguageOption: appleLangOpt,
            appleSpeechCustomLanguage: appleCustomLang,
            whisperLanguage: whisperLang,
            whisperTask: whisperTsk,
            enablesAppleSpeech: enablesApple,
            enablesLocalVAD: enablesVAD,
            vadMode: savedVadMode,
            vadModelPath: defaults.string(forKey: prefix + "vadModelPath") ?? "",
            vadThreshold: loadDouble(forKey: prefix + "vadThreshold", default: 0.5),
            vadMinSpeechDuration: loadDouble(forKey: prefix + "vadMinSpeechDuration", default: 0.15),
            vadMinSilenceDuration: loadDouble(forKey: prefix + "vadMinSilenceDuration", default: 0.45),
            vadNoTextFallbackInterval: loadDouble(forKey: prefix + "vadNoTextFallbackInterval", default: 5.0),
            whisperModelPath: defaults.string(forKey: prefix + "whisperModelPath") ?? "",
            whisperCoreMLModelPath: defaults.string(forKey: prefix + "whisperCoreMLModelPath") ?? "",
            whisperTranscriptionUsesCPUOnly: loadBool(forKey: prefix + "whisperTranscriptionUsesCPUOnly", default: false),
            whisperTranscriptionCPUThreadCount: loadDouble(forKey: prefix + "whisperTranscriptionCPUThreadCount", default: 2),
            enablesWhisperPostProcessing: loadBool(forKey: prefix + "enablesWhisperPostProcessing", default: true),
            commitsAppleTextWhenWhisperFails: loadBool(forKey: prefix + "commitsAppleTextWhenWhisperFails", default: true),
            segmentAudioOverlapDuration: loadDouble(forKey: prefix + "segmentAudioOverlapDuration", default: 0.10),
            paragraphBreakSilenceDuration: loadDouble(forKey: prefix + "paragraphBreakSilenceDuration", default: 4.0),
            enablesParagraphBreaks: loadBool(forKey: prefix + "enablesParagraphBreaks", default: true)
        )
    }
}

struct DSAudioTranscriptionInputLiveVoicePreview: View {
    @State private var configID = UUID()
    @State private var text: String = ""

    @State private var silenceBreakInterval: Double
    @State private var minimumSegmentDuration: Double
    @State private var maximumSegmentDuration: Double
    @State private var enablesWhisperPostProcessing: Bool
    @State private var commitsAppleTextWhenWhisperFails: Bool
    
    @State private var appleSpeechLanguageOption: String
    @State private var appleSpeechCustomLanguage: String
    
    @State private var whisperLanguage: String
    @State private var whisperTask: WhisperTranscriptionTask
    
    @State private var enablesAppleSpeech: Bool
    @State private var enablesLocalVAD: Bool

    @State private var whisperModelPath: String
    @State private var whisperCoreMLModelPath: String
    @State private var whisperTranscriptionUsesCPUOnly: Bool
    @State private var whisperTranscriptionCPUThreadCount: Double

    @State private var vadModelPath: String
    @State private var vadThreshold: Double
    @State private var vadMinSpeechDuration: Double
    @State private var vadMinSilenceDuration: Double
    @State private var vadNoTextFallbackInterval: Double
    @State private var segmentAudioOverlapDuration: Double
    @State private var paragraphBreakSilenceDuration: Double
    @State private var enablesParagraphBreaks: Bool

    init() {
        let saved = DSAudioTranscriptionLivePreviewSettingsStore.load()
        self._silenceBreakInterval = State(initialValue: saved.silenceBreakInterval)
        self._minimumSegmentDuration = State(initialValue: saved.minimumSegmentDuration)
        self._maximumSegmentDuration = State(initialValue: saved.maximumSegmentDuration)
        self._enablesWhisperPostProcessing = State(initialValue: saved.enablesWhisperPostProcessing)
        self._commitsAppleTextWhenWhisperFails = State(initialValue: saved.commitsAppleTextWhenWhisperFails)
        
        self._appleSpeechLanguageOption = State(initialValue: saved.appleSpeechLanguageOption)
        self._appleSpeechCustomLanguage = State(initialValue: saved.appleSpeechCustomLanguage)
        self._whisperLanguage = State(initialValue: saved.whisperLanguage)
        self._whisperTask = State(initialValue: WhisperTranscriptionTask(rawValue: saved.whisperTask) ?? .transcribe)
        self._enablesAppleSpeech = State(initialValue: saved.enablesAppleSpeech)
        self._enablesLocalVAD = State(initialValue: saved.enablesLocalVAD)
        
        self._whisperModelPath = State(initialValue: saved.whisperModelPath)
        self._whisperCoreMLModelPath = State(initialValue: saved.whisperCoreMLModelPath)
        self._whisperTranscriptionUsesCPUOnly = State(initialValue: saved.whisperTranscriptionUsesCPUOnly)
        self._whisperTranscriptionCPUThreadCount = State(initialValue: saved.whisperTranscriptionCPUThreadCount)
        self._vadModelPath = State(initialValue: saved.vadModelPath)
        self._vadThreshold = State(initialValue: saved.vadThreshold)
        self._vadMinSpeechDuration = State(initialValue: saved.vadMinSpeechDuration)
        self._vadMinSilenceDuration = State(initialValue: saved.vadMinSilenceDuration)
        self._vadNoTextFallbackInterval = State(initialValue: saved.vadNoTextFallbackInterval)
        self._segmentAudioOverlapDuration = State(initialValue: saved.segmentAudioOverlapDuration)
        self._paragraphBreakSilenceDuration = State(initialValue: saved.paragraphBreakSilenceDuration)
        self._enablesParagraphBreaks = State(initialValue: saved.enablesParagraphBreaks)
    }

    private var resolvedAppleSpeechLanguage: String {
        if appleSpeechLanguageOption == "custom" {
            return appleSpeechCustomLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return appleSpeechLanguageOption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            DSAudioTranscriptionInputLiveVoicePreviewContent(
                text: $text,
                config: VoiceAudioTranscriptionConfig(
                    silenceBreakInterval: silenceBreakInterval,
                    minimumSegmentDuration: minimumSegmentDuration,
                    maximumSegmentDuration: maximumSegmentDuration,
                    realtimeDebounceInterval: 0.08,
                    enablesWhisperPostProcessing: enablesWhisperPostProcessing,
                    commitsAppleTextWhenWhisperFails: commitsAppleTextWhenWhisperFails,
                    appleSpeechLanguage: resolvedAppleSpeechLanguage,
                    whisperLanguage: whisperLanguage,
                    whisperTask: whisperTask,
                    enablesAppleSpeech: enablesAppleSpeech,
                    whisperModelPath: whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : whisperModelPath,
                    whisperCoreMLModelPath: whisperCoreMLModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : whisperCoreMLModelPath,
                    whisperTranscriptionUsesCPUOnly: whisperTranscriptionUsesCPUOnly,
                    whisperTranscriptionCPUThreadCount: Int(max(1, whisperTranscriptionCPUThreadCount)),
                    vadMode: enablesLocalVAD ? .localModel : .timedTextActivity,
                    vadModelPath: vadModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vadModelPath,
                    vadThreshold: vadThreshold,
                    vadMinSpeechDuration: vadMinSpeechDuration,
                    vadMinSilenceDuration: vadMinSilenceDuration,
                    vadNoTextFallbackInterval: vadNoTextFallbackInterval,
                    segmentAudioOverlapDuration: segmentAudioOverlapDuration,
                    paragraphBreakSilenceDuration: paragraphBreakSilenceDuration,
                    enablesParagraphBreaks: enablesParagraphBreaks
                )
            )
            .id(configID)

            controls {
                let settings = DSAudioTranscriptionLivePreviewSettingsStore.Settings(
                    silenceBreakInterval: silenceBreakInterval,
                    minimumSegmentDuration: minimumSegmentDuration,
                    maximumSegmentDuration: maximumSegmentDuration,
                    appleSpeechLanguageOption: appleSpeechLanguageOption,
                    appleSpeechCustomLanguage: appleSpeechCustomLanguage,
                    whisperLanguage: whisperLanguage,
                    whisperTask: whisperTask.rawValue,
                    enablesAppleSpeech: enablesAppleSpeech,
                    enablesLocalVAD: enablesLocalVAD,
                    vadMode: (enablesLocalVAD ? VoiceVADMode.localModel : VoiceVADMode.timedTextActivity).rawValue,
                    vadModelPath: vadModelPath,
                    vadThreshold: vadThreshold,
                    vadMinSpeechDuration: vadMinSpeechDuration,
                    vadMinSilenceDuration: vadMinSilenceDuration,
                    vadNoTextFallbackInterval: vadNoTextFallbackInterval,
                    whisperModelPath: whisperModelPath,
                    whisperCoreMLModelPath: whisperCoreMLModelPath,
                    whisperTranscriptionUsesCPUOnly: whisperTranscriptionUsesCPUOnly,
                    whisperTranscriptionCPUThreadCount: whisperTranscriptionCPUThreadCount,
                    enablesWhisperPostProcessing: enablesWhisperPostProcessing,
                    commitsAppleTextWhenWhisperFails: commitsAppleTextWhenWhisperFails,
                    segmentAudioOverlapDuration: segmentAudioOverlapDuration,
                    paragraphBreakSilenceDuration: paragraphBreakSilenceDuration,
                    enablesParagraphBreaks: enablesParagraphBreaks
                )
                DSAudioTranscriptionLivePreviewSettingsStore.save(settings: settings)
                configID = UUID()
            }
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

    private func controls(onApply: @escaping () -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Runtime configuration")
                    .font(.headline)

                Group {
                    HStack {
                        Text("Silence break")
                        Slider(value: $silenceBreakInterval, in: 0.15...2.0)
                        Text(silenceBreakInterval, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Minimum segment")
                        Slider(value: $minimumSegmentDuration, in: 0.1...2.0)
                        Text(minimumSegmentDuration, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Maximum segment")
                        Slider(value: $maximumSegmentDuration, in: 2...60)
                        Text(maximumSegmentDuration, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Segment audio overlap")
                            Slider(value: $segmentAudioOverlapDuration, in: 0.00...0.30)
                            Text(segmentAudioOverlapDuration, format: .number.precision(.fractionLength(2)))
                                .monospacedDigit()
                        }
                        Text("Adds a small audio overlap from the previous segment to the next Whisper/InSber segment to avoid losing words at VAD boundaries.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                Text("Isolation Toggles")
                    .font(.headline)
                
                Toggle("Enable Apple Speech", isOn: $enablesAppleSpeech)
                Toggle("Enable Local VAD", isOn: $enablesLocalVAD)
                Toggle("Enable Whisper post-processing", isOn: $enablesWhisperPostProcessing)
                Toggle("Enable paragraph breaks", isOn: $enablesParagraphBreaks)
                
                if enablesParagraphBreaks {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Paragraph break silence")
                            Slider(value: $paragraphBreakSilenceDuration, in: 2.0...12.0)
                            Text(paragraphBreakSilenceDuration, format: .number.precision(.fractionLength(1)))
                                .monospacedDigit()
                        }
                        Text("If the user stays silent for this long, a blank line is inserted before the next speech continues.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Apple Speech")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Speech Language")
                    Picker("Apple Speech Language", selection: $appleSpeechLanguageOption) {
                        Text("Auto").tag("auto")
                        Text("Portuguese (Brazil)").tag("pt-BR")
                        Text("English (US)").tag("en-US")
                        Text("Spanish (Spain)").tag("es-ES")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(.segmented)
                }

                if appleSpeechLanguageOption == "custom" {
                    HStack {
                        Text("Custom Language Code")
                        TextField("e.g. fr-FR", text: $appleSpeechCustomLanguage)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 120)
                    }
                }

                Divider()

                Text("Whisper / InSber")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper Language")
                    Picker("Whisper Language", selection: $whisperLanguage) {
                        Text("Portuguese").tag("pt")
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("Auto").tag("auto")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper Task")
                    Picker("Whisper Task", selection: $whisperTask) {
                        Text("Transcribe").tag(WhisperTranscriptionTask.transcribe)
                        Text("Translate").tag(WhisperTranscriptionTask.translate)
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Whisper Model Path")
                        TextField("Path to ggml-model.bin", text: $whisperModelPath)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Browse...") {
                        selectWhisperModelPath()
                    }
                    .padding(.top, 18)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Whisper CoreML Path")
                        TextField("Path to companion-encoder.mlmodelc", text: $whisperCoreMLModelPath)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Browse...") {
                        selectWhisperCoreMLModelPath()
                    }
                    .padding(.top, 18)
                }

                Toggle("Use CPU only for Whisper transcription", isOn: $whisperTranscriptionUsesCPUOnly)

                if whisperTranscriptionUsesCPUOnly {
                    HStack {
                        Text("Whisper CPU threads")
                        Slider(value: $whisperTranscriptionCPUThreadCount, in: 1...8, step: 1)
                        Text("\(Int(whisperTranscriptionCPUThreadCount))")
                            .monospacedDigit()
                    }
                }

                Toggle("Commit Apple text when Whisper fails", isOn: $commitsAppleTextWhenWhisperFails)

                if enablesLocalVAD {
                    Divider()
                    Text("Local VAD Configuration")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VAD Model Path (required)")
                            TextField("Path to VAD model", text: $vadModelPath)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button("Browse...") {
                            selectVADModelPath()
                        }
                        .padding(.top, 18)
                    }

                    HStack {
                        Text("VAD Threshold")
                        Slider(value: $vadThreshold, in: 0.05...0.95)
                        Text(vadThreshold, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Min Speech Duration")
                        Slider(value: $vadMinSpeechDuration, in: 0.05...1.0)
                        Text(vadMinSpeechDuration, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Min Silence Duration")
                        Slider(value: $vadMinSilenceDuration, in: 0.1...2.0)
                        Text(vadMinSilenceDuration, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("No-text fallback")
                        Slider(value: $vadNoTextFallbackInterval, in: 2.0...12.0)
                        Text(vadNoTextFallbackInterval, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                    }
                    
                    Text("If Apple Speech text does not change for this many seconds, the current realtime segment is force-closed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button("Apply Settings", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)

                Text("Recreates the transcription controller with the configured values.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectWhisperModelPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Whisper Model (.bin)"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.whisperModelPath = url.path
            }
        }
    }

    private func selectWhisperCoreMLModelPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Whisper CoreML Companion (.mlmodelc)"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.whisperCoreMLModelPath = url.path
            }
        }
    }

    private func selectVADModelPath() {
        let panel = NSOpenPanel()
        panel.title = "Select VAD Model"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.vadModelPath = url.path
            }
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
