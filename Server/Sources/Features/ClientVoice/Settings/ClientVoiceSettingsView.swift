import SwiftUI

struct ClientVoiceSettingsView: View {
    let wrapper: ClientVoiceSettingsWrapper

    @State private var workerAutoStart = false
    @State private var speechRecognitionLanguage = ClientVoiceSpeechRecognitionLanguage.systemDefault
    @State private var speechRecognitionDebounceFinalMs = 1_200

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

    private func load() {
        workerAutoStart = wrapper.workerAutoStart
        speechRecognitionLanguage = wrapper.speechRecognitionLanguage
        speechRecognitionDebounceFinalMs = wrapper.speechRecognitionDebounceFinalMs
    }
}
