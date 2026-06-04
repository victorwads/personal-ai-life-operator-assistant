import SwiftUI

struct ClientVoiceAskDialog: View {
    @StateObject private var viewModel: ClientVoiceAskDialogViewModel

    init(viewModel: ClientVoiceAskDialogViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask Client")
                .font(.title2.weight(.semibold))

            Text(viewModel.promptText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if viewModel.isSpeaking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Speaking prompt to the client...")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isListening {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                    Text("Listening for the client response...")
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Client response", text: $viewModel.responseText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...8)
                .onSubmit {
                    viewModel.submit()
                }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button("Submit") {
                    viewModel.submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting)

                Button("Cancel Listening") {
                    viewModel.cancelListening()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isListening || viewModel.isSubmitting)

                Button("Answer Later") {
                    viewModel.answerLaterAndClose()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSubmitting)
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 520)
        .task {
            viewModel.startIfNeeded()
        }
    }
}
