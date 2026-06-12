import AppKit
import SwiftUI

/// Reusable configuration form for `VoiceAudioTranscriptionConfig`.
///
/// This view does not persist settings and does not own a transcription controller.
/// Callers are responsible for storing the configuration and applying it to a runtime.
struct VoiceAudioTranscriptionConfigForm: View {
    @Binding var config: VoiceAudioTranscriptionConfig

    private let showsFilePickers: Bool
    private let onChange: ((VoiceAudioTranscriptionConfig) -> Void)?

    @State private var appleSpeechLanguageSelection: AppleSpeechLanguageSelection
    @State private var appleSpeechCustomLanguage: String

    init(
        config: Binding<VoiceAudioTranscriptionConfig>,
        showsFilePickers: Bool = true,
        onChange: ((VoiceAudioTranscriptionConfig) -> Void)? = nil
    ) {
        self._config = config
        self.showsFilePickers = showsFilePickers
        self.onChange = onChange
        let initialConfig = config.wrappedValue
        self._appleSpeechLanguageSelection = State(
            initialValue: AppleSpeechLanguageSelection(configValue: initialConfig.appleSpeechLanguage)
        )
        self._appleSpeechCustomLanguage = State(initialValue: initialConfig.appleSpeechLanguage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(
                    title: "Segmentation",
                    note: "Maximum segment should usually be around 60s to avoid huge audio chunks. Segment overlap around 0.10s helps avoid losing words at VAD boundaries."
                ) {
                    sliderRow(
                        title: "Silence break",
                        value: binding(for: \.silenceBreakInterval),
                        range: 0.15...2.0,
                        fractionDigits: 2
                    )

                    sliderRow(
                        title: "Minimum segment",
                        value: binding(for: \.minimumSegmentDuration),
                        range: 0.1...2.0,
                        fractionDigits: 2
                    )

                    sliderRow(
                        title: "Maximum segment",
                        value: binding(for: \.maximumSegmentDuration),
                        range: 2.0...60.0,
                        fractionDigits: 1
                    )

                    sliderRow(
                        title: "Segment audio overlap",
                        value: binding(for: \.segmentAudioOverlapDuration),
                        range: 0.0...0.30,
                        fractionDigits: 2
                    )
                }

                section(title: "Runtime toggles") {
                    Toggle("Enable Apple Speech", isOn: binding(for: \.enablesAppleSpeech))
                    Toggle("Enable Whisper post-processing", isOn: binding(for: \.enablesWhisperPostProcessing))
                    Toggle("Commit Apple text when Whisper fails", isOn: binding(for: \.commitsAppleTextWhenWhisperFails))

                    Toggle("Use CPU only for Whisper transcription", isOn: binding(for: \.whisperTranscriptionUsesCPUOnly))

                    if config.whisperTranscriptionUsesCPUOnly {
                        sliderRow(
                            title: "Whisper CPU threads",
                            value: whisperCPUThreadCountBinding,
                            range: 1.0...8.0,
                            step: 1,
                            fractionDigits: 0
                        )
                    }
                }

                section(title: "Apple Speech") {
                    Picker("Apple Speech Language", selection: appleSpeechLanguageSelectionBinding) {
                        ForEach(AppleSpeechLanguageSelection.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if appleSpeechLanguageSelection == .custom {
                        TextField("Custom language code", text: $appleSpeechCustomLanguage)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                section(title: "Whisper / InSber") {
                    Picker("Whisper Language", selection: binding(for: \.whisperLanguage)) {
                        Text("Portuguese").tag("pt")
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("Auto").tag("auto")
                    }
                    .pickerStyle(.segmented)

                    Picker("Whisper Task", selection: binding(for: \.whisperTask)) {
                        Text("Transcribe").tag(WhisperTranscriptionTask.transcribe)
                        Text("Translate").tag(WhisperTranscriptionTask.translate)
                    }
                    .pickerStyle(.segmented)

                    pathField(
                        title: "Whisper Model Path",
                        keyPath: \.whisperModelPath,
                        panelTitle: "Select Whisper Model (.bin)",
                        canChooseDirectories: false
                    )

                    pathField(
                        title: "Whisper CoreML Companion Path",
                        keyPath: \.whisperCoreMLModelPath,
                        panelTitle: "Select Whisper CoreML Companion (.mlmodelc)",
                        canChooseDirectories: true
                    )
                }

                section(
                    title: "VAD",
                    note: "No-text fallback is only an emergency fallback. VAD silence should be the primary segment close trigger in local VAD mode."
                ) {
                    Toggle("Enable Local VAD", isOn: localVADEnabledBinding)

                    if config.vadMode == .localModel {
                        pathField(
                            title: "VAD Model Path",
                            keyPath: \.vadModelPath,
                            panelTitle: "Select VAD Model",
                            canChooseDirectories: false
                        )

                        sliderRow(
                            title: "VAD Threshold",
                            value: binding(for: \.vadThreshold),
                            range: 0.05...0.95,
                            fractionDigits: 2
                        )

                        sliderRow(
                            title: "Min Speech Duration",
                            value: binding(for: \.vadMinSpeechDuration),
                            range: 0.05...1.0,
                            fractionDigits: 2
                        )

                        sliderRow(
                            title: "Min Silence Duration",
                            value: binding(for: \.vadMinSilenceDuration),
                            range: 0.1...2.0,
                            fractionDigits: 2
                        )

                        sliderRow(
                            title: "No-text fallback",
                            value: binding(for: \.vadNoTextFallbackInterval),
                            range: 2.0...12.0,
                            fractionDigits: 1
                        )
                    }
                }

                section(
                    title: "Paragraph breaks",
                    note: "When silence lasts this long, the input inserts a paragraph break before the next speech appears."
                ) {
                    Toggle("Enable paragraph breaks", isOn: binding(for: \.enablesParagraphBreaks))

                    if config.enablesParagraphBreaks {
                        sliderRow(
                            title: "Paragraph break silence",
                            value: binding(for: \.paragraphBreakSilenceDuration),
                            range: 2.0...12.0,
                            fractionDigits: 1
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            onChange?(config)
        }
        .onChange(of: config) { _, newValue in
            syncLocalAppleSpeechSelectionIfNeeded(from: newValue)
            onChange?(newValue)
        }
        .onChange(of: appleSpeechLanguageSelection) { _, newValue in
            applyAppleSpeechLanguageSelection(newValue)
        }
        .onChange(of: appleSpeechCustomLanguage) { _, newValue in
            guard appleSpeechLanguageSelection == .custom else { return }

            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                config.appleSpeechLanguage = trimmed
            }
        }
    }

    private var appleSpeechLanguageSelectionBinding: Binding<AppleSpeechLanguageSelection> {
        Binding(
            get: { appleSpeechLanguageSelection },
            set: { appleSpeechLanguageSelection = $0 }
        )
    }

    private var localVADEnabledBinding: Binding<Bool> {
        Binding(
            get: { config.vadMode == .localModel },
            set: { isEnabled in
                config.vadMode = isEnabled ? .localModel : .timedTextActivity
            }
        )
    }

    private var whisperCPUThreadCountBinding: Binding<Double> {
        Binding(
            get: { Double(max(1, config.whisperTranscriptionCPUThreadCount)) },
            set: { newValue in
                config.whisperTranscriptionCPUThreadCount = max(1, Int(newValue.rounded()))
            }
        )
    }

    private func binding<Value>(for keyPath: WritableKeyPath<VoiceAudioTranscriptionConfig, Value>) -> Binding<Value> {
        Binding(
            get: { config[keyPath: keyPath] },
            set: { config[keyPath: keyPath] = $0 }
        )
    }

    private func binding(for keyPath: WritableKeyPath<VoiceAudioTranscriptionConfig, String?>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                config[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func applyAppleSpeechLanguageSelection(_ selection: AppleSpeechLanguageSelection) {
        switch selection {
        case .auto, .ptBR, .enUS, .esES:
            config.appleSpeechLanguage = selection.configValue
        case .custom:
            let trimmed = appleSpeechCustomLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                config.appleSpeechLanguage = trimmed
            }
        }
    }

    private func syncLocalAppleSpeechSelectionIfNeeded(from newValue: VoiceAudioTranscriptionConfig) {
        let nextSelection = AppleSpeechLanguageSelection(configValue: newValue.appleSpeechLanguage)
        if nextSelection != appleSpeechLanguageSelection {
            appleSpeechLanguageSelection = nextSelection
        }

        if nextSelection == .custom {
            appleSpeechCustomLanguage = newValue.appleSpeechLanguage
        }
    }

    private func pathField(
        title: String,
        keyPath: WritableKeyPath<VoiceAudioTranscriptionConfig, String?>,
        panelTitle: String,
        canChooseDirectories: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(title, text: binding(for: keyPath))
                    .textFieldStyle(.roundedBorder)

                if showsFilePickers {
                    Button("Browse...") {
                        selectPath(
                            title: panelTitle,
                            canChooseDirectories: canChooseDirectories
                        ) { url in
                            config[keyPath: keyPath] = url.path
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func selectPath(
        title: String,
        canChooseDirectories: Bool,
        onPick: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            onPick(url)
        }
    }

    private func section<Content: View>(
        title: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        fractionDigits: Int = 2
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .frame(width: 160, alignment: .leading)

            Slider(value: value, in: range, step: step)

            Text(formattedValue(value.wrappedValue, fractionDigits: fractionDigits))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func formattedValue(_ value: Double, fractionDigits: Int) -> String {
        String(format: "%.\(max(0, fractionDigits))f", value)
    }

    private enum AppleSpeechLanguageSelection: String, CaseIterable, Identifiable {
        case auto
        case ptBR
        case enUS
        case esES
        case custom

        var id: String { rawValue }

        init(configValue: String) {
            switch configValue {
            case "auto":
                self = .auto
            case "pt-BR":
                self = .ptBR
            case "en-US":
                self = .enUS
            case "es-ES":
                self = .esES
            default:
                self = .custom
            }
        }

        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .ptBR: return "Portuguese (Brazil)"
            case .enUS: return "English (US)"
            case .esES: return "Spanish (Spain)"
            case .custom: return "Custom"
            }
        }

        var configValue: String {
            switch self {
            case .auto: return "auto"
            case .ptBR: return "pt-BR"
            case .enUS: return "en-US"
            case .esES: return "es-ES"
            case .custom: return ""
            }
        }
    }
}
