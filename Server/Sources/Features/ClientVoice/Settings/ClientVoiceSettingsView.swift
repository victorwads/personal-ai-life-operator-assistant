import SwiftUI
import AppKit

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
