import SwiftUI
import AppKit
import AVFoundation

struct ClientVoiceSettingsView: View {
    let wrapper: ClientVoiceSettingsWrapper

    @State private var workerAutoStart = false
    @State private var speechRecognitionLanguage = ClientVoiceSpeechRecognitionLanguage.systemDefault
    @State private var speechRecognitionDebounceFinalMs = 1_200
    @State private var askSendMode = ClientVoiceAskSendMode.handsFree
    @State private var whisperPostProcessingEnabled = false
    @State private var whisperPostProcessingModelPath = ""
    @State private var whisperPostProcessingCoreMLModelPath = ""
    @State private var whisperPostProcessingLanguage = WhisperLanguage.auto

    @State private var speechOutputMethod = SpeakMethod.command
    @State private var speechOutputVoiceIdentifier = ""
    @State private var speechOutputLanguage = "pt-BR"
    @State private var speechOutputRate = AVSpeechUtteranceDefaultSpeechRate

    @State private var testSpeechText = "Olá, esta é uma mensagem de teste."
    @State private var isSpeakingTest = false
    @State private var currentTestHandler: SpeechSpeakHandler? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start Voice Worker", isOn: workerAutoStartBinding)

            Picker("Speech Recognition Language", selection: speechRecognitionLanguageBinding) {
                ForEach(ClientVoiceSpeechRecognitionLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }

            Stepper(
                "Speech Recognition Silence Debounce: \(speechRecognitionDebounceFinalMs) ms",
                value: speechRecognitionDebounceFinalMsBinding,
                in: 100...10_000,
                step: 100
            )

            Text("How long the listener waits after the last partial transcription before ending audio and waiting for the native final result.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Speech Output")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Output Backend", selection: speechOutputMethodBinding) {
                ForEach(SpeakMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }

            Picker("Speech Language", selection: speechOutputLanguageBinding) {
                ForEach(availableSpeechLanguages, id: \.self) { language in
                    Text(language).tag(language)
                }
            }
            .disabled(speechOutputMethod != .swiftAPI)

            Picker("Voice", selection: speechOutputVoiceIdentifierBinding) {
                Text("Auto").tag("")
                ForEach(availableSpeechVoices(for: speechOutputLanguage), id: \.identifier) { voice in
                    Text(speechVoiceTitle(voice)).tag(voice.identifier)
                }
            }
            .disabled(speechOutputMethod != .swiftAPI)

            HStack {
                Text("Speech Rate")
                Slider(
                    value: speechOutputRateBinding,
                    in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate
                )
                .frame(width: 220)

                Text(String(format: "%.2f", speechOutputRate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            HStack(spacing: 8) {
                TextField("Texto de teste", text: $testSpeechText)
                    .textFieldStyle(.roundedBorder)

                if isSpeakingTest {
                    Button("Parar") {
                        currentTestHandler?.cancel()
                        isSpeakingTest = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Testar") {
                        let text = testSpeechText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }

                        isSpeakingTest = true
                        Task {
                            do {
                                let config = wrapper.speechSpeakConfig
                                let handler = try await SpeechSpeaker.speak(text: text, config: config)
                                currentTestHandler = handler
                                await handler.await()
                                isSpeakingTest = false
                                currentTestHandler = nil
                            } catch {
                                print("Test speech failed: \(error.localizedDescription)")
                                isSpeakingTest = false
                                currentTestHandler = nil
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testSpeechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Text("Terminal say uses the macOS say command and waits for the process to finish. AVSpeechSynthesizer uses the selected Apple voice and also only releases the handler await after didFinish or didCancel.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            ClientVoiceAskSendModePicker(selection: askSendModeBinding)

            Text("Hands-free auto-submits the response as soon as the listener finalizes. Manual send keeps the text ready for review until you press Submit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Enable Whisper Post-Processing", isOn: whisperPostProcessingEnabledBinding)

            Text("Apple Speech still drives live partial transcription. When enabled, the final text waits for Whisper after silence detection and falls back to Apple Speech if the model path is missing or Whisper fails.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Whisper Language", selection: whisperPostProcessingLanguageBinding) {
                ForEach(WhisperLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .disabled(!whisperPostProcessingEnabled)

            DSSettingsTextField(
                title: "Whisper Model Path",
                prompt: "/path/to/ggml-model.bin",
                helperText: "Select a local whisper.cpp model file. The app does not download models automatically.",
                text: whisperPostProcessingModelPathBinding
            )
            .disabled(!whisperPostProcessingEnabled)

            DSSettingsTextField(
                title: "Whisper Core ML Encoder Path",
                prompt: "/path/to/ggml-model-encoder.mlmodelc",
                helperText: "Optional. Select the compiled Core ML encoder companion. If it is not already beside the ggml model, the app will try to create a symlink next to the model automatically.",
                text: whisperPostProcessingCoreMLModelPathBinding
            )
            .disabled(!whisperPostProcessingEnabled)

            HStack(spacing: 8) {
                Button("Choose Model File...") {
                    chooseModelFile()
                }
                .disabled(!whisperPostProcessingEnabled)

                Button("Choose Core ML Encoder...") {
                    chooseCoreMLModelDirectory()
                }
                .disabled(!whisperPostProcessingEnabled)

                Button("Clear Model Path") {
                    whisperPostProcessingModelPath = ""
                    wrapper.whisperPostProcessingModelPath = nil
                }
                .disabled(!whisperPostProcessingEnabled || whisperPostProcessingModelPath.isEmpty)

                Button("Clear Core ML Path") {
                    whisperPostProcessingCoreMLModelPath = ""
                    wrapper.whisperPostProcessingCoreMLModelPath = nil
                }
                .disabled(!whisperPostProcessingEnabled || whisperPostProcessingCoreMLModelPath.isEmpty)
            }

            Text(modelPathStatusText)
                .font(.caption)
                .foregroundStyle(modelPathStatusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            load()
        }
    }

    private var workerAutoStartBinding: Binding<Bool> {
        Binding {
            workerAutoStart
        } set: { value in
            workerAutoStart = value
            wrapper.workerAutoStart = value
        }
    }

    private var speechRecognitionLanguageBinding: Binding<ClientVoiceSpeechRecognitionLanguage> {
        Binding {
            speechRecognitionLanguage
        } set: { value in
            speechRecognitionLanguage = value
            wrapper.speechRecognitionLanguage = value
        }
    }

    private var speechRecognitionDebounceFinalMsBinding: Binding<Int> {
        Binding {
            speechRecognitionDebounceFinalMs
        } set: { value in
            speechRecognitionDebounceFinalMs = value
            wrapper.speechRecognitionDebounceFinalMs = value
        }
    }

    private var askSendModeBinding: Binding<ClientVoiceAskSendMode> {
        Binding {
            askSendMode
        } set: { value in
            askSendMode = value
            wrapper.askSendMode = value
        }
    }

    private var whisperPostProcessingEnabledBinding: Binding<Bool> {
        Binding {
            whisperPostProcessingEnabled
        } set: { value in
            whisperPostProcessingEnabled = value
            wrapper.whisperPostProcessingEnabled = value
        }
    }

    private var whisperPostProcessingModelPathBinding: Binding<String> {
        Binding {
            whisperPostProcessingModelPath
        } set: { value in
            whisperPostProcessingModelPath = value
            wrapper.whisperPostProcessingModelPath = value
        }
    }

    private var whisperPostProcessingLanguageBinding: Binding<WhisperLanguage> {
        Binding {
            whisperPostProcessingLanguage
        } set: { value in
            whisperPostProcessingLanguage = value
            wrapper.whisperPostProcessingLanguage = value
        }
    }

    private var whisperPostProcessingCoreMLModelPathBinding: Binding<String> {
        Binding {
            whisperPostProcessingCoreMLModelPath
        } set: { value in
            whisperPostProcessingCoreMLModelPath = value
            wrapper.whisperPostProcessingCoreMLModelPath = value
        }
    }

    private var modelPathStatusText: String {
        if whisperPostProcessingModelPath.isEmpty {
            return "No model selected. Even with Whisper enabled, final text will fall back to Apple Speech until a model path is configured."
        }

        guard FileManager.default.fileExists(atPath: whisperPostProcessingModelPath) else {
            return "The configured model path does not exist right now. Final text will fall back to Apple Speech."
        }

        if whisperPostProcessingCoreMLModelPath.isEmpty {
            return "Model file found. Whisper post-processing can run now. If you also choose a Core ML encoder companion, the app will try to use it for faster warm starts."
        }

        if FileManager.default.fileExists(atPath: whisperPostProcessingCoreMLModelPath) {
            return "Model file and Core ML encoder found. New listen sessions can warm the model in background and try to use the Core ML companion."
        }

        return "The configured Core ML encoder path does not exist right now. The app can still use the ggml model and will fall back if the companion is unavailable."
    }

    private var modelPathStatusColor: Color {
        if whisperPostProcessingModelPath.isEmpty {
            return .secondary
        }

        if !FileManager.default.fileExists(atPath: whisperPostProcessingModelPath) {
            return .orange
        }

        if !whisperPostProcessingCoreMLModelPath.isEmpty
            && !FileManager.default.fileExists(atPath: whisperPostProcessingCoreMLModelPath) {
            return .orange
        }

        return .secondary
    }

    private func load() {
        workerAutoStart = wrapper.workerAutoStart
        speechRecognitionLanguage = wrapper.speechRecognitionLanguage
        speechRecognitionDebounceFinalMs = wrapper.speechRecognitionDebounceFinalMs
        askSendMode = wrapper.askSendMode
        whisperPostProcessingEnabled = wrapper.whisperPostProcessingEnabled
        whisperPostProcessingModelPath = wrapper.whisperPostProcessingModelPath ?? ""
        whisperPostProcessingCoreMLModelPath = wrapper.whisperPostProcessingCoreMLModelPath ?? ""
        whisperPostProcessingLanguage = wrapper.whisperPostProcessingLanguage
        speechOutputMethod = wrapper.speechOutputMethod
        speechOutputVoiceIdentifier = wrapper.speechOutputVoiceIdentifier ?? ""
        speechOutputLanguage = wrapper.speechOutputLanguage
        speechOutputRate = wrapper.speechOutputRate
    }

    private var speechOutputMethodBinding: Binding<SpeakMethod> {
        Binding {
            speechOutputMethod
        } set: { value in
            speechOutputMethod = value
            wrapper.speechOutputMethod = value
        }
    }

    private var speechOutputVoiceIdentifierBinding: Binding<String> {
        Binding {
            speechOutputVoiceIdentifier
        } set: { value in
            speechOutputVoiceIdentifier = value
            wrapper.speechOutputVoiceIdentifier = value.isEmpty ? nil : value
        }
    }

    private var speechOutputLanguageBinding: Binding<String> {
        Binding {
            speechOutputLanguage
        } set: { value in
            speechOutputLanguage = value
            wrapper.speechOutputLanguage = value
            if !speechOutputVoiceIdentifier.isEmpty {
                let available = availableSpeechVoices(for: value)
                if !available.contains(where: { $0.identifier == speechOutputVoiceIdentifier }) {
                    speechOutputVoiceIdentifier = ""
                    wrapper.speechOutputVoiceIdentifier = nil
                }
            }
        }
    }

    private var speechOutputRateBinding: Binding<Float> {
        Binding {
            speechOutputRate
        } set: { value in
            speechOutputRate = value
            wrapper.speechOutputRate = value
        }
    }

    private var availableSpeechVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { left, right in
                if left.language != right.language { return left.language < right.language }
                if left.quality != right.quality { return left.quality.rawValue > right.quality.rawValue }
                return left.name < right.name
            }
    }

    private var availableSpeechLanguages: [String] {
        Array(Set(availableSpeechVoices.map(\.language))).sorted()
    }

    private func availableSpeechVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return availableSpeechVoices }

        let matches = availableSpeechVoices.filter { $0.language == trimmed }
        return matches.isEmpty ? availableSpeechVoices : matches
    }

    private func speechVoiceTitle(_ voice: AVSpeechSynthesisVoice) -> String {
        let qualitySuffix: String
        switch voice.quality {
        case .enhanced:
            qualitySuffix = " (Enhanced)"
        case .premium:
            qualitySuffix = " (Premium)"
        default:
            qualitySuffix = ""
        }

        return "\(voice.name)\(qualitySuffix)"
    }

    private func chooseModelFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Model"
        panel.title = "Choose Whisper Model"
        panel.message = "Select the local whisper.cpp model file to use for post-processing."

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            whisperPostProcessingModelPath = path
            wrapper.whisperPostProcessingModelPath = path
        }
    }

    private func chooseCoreMLModelDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Core ML Encoder"
        panel.title = "Choose Whisper Core ML Encoder"
        panel.message = "Select the compiled .mlmodelc companion for the whisper.cpp model."

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            whisperPostProcessingCoreMLModelPath = path
            wrapper.whisperPostProcessingCoreMLModelPath = path
        }
    }
}
