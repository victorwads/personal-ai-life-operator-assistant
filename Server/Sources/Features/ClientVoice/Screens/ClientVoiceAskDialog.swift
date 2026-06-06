import SwiftUI

struct ClientVoiceAskDialog: View {
    @StateObject private var viewModel: ClientVoiceAskDialogViewModel
    private let responseEditorHeight: CGFloat = 120

    init(viewModel: ClientVoiceAskDialogViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask Client")
                .font(.title2.weight(.semibold))

            ScrollView {
                Text(viewModel.promptText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 96)

            ClientVoiceAskSendModePicker(selection: askSendModeBinding)

            Text("Hands-free auto-submits when listening ends. Manual send keeps the result in the field until you submit it yourself.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            statusRow

            TextEditor(text: $viewModel.responseText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: responseEditorHeight, maxHeight: responseEditorHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )

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

                Button(viewModel.dismissActionTitle) {
                    viewModel.dismissWithoutResponse()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSubmitting)
            }
        }
        .padding(20)
        .task {
            viewModel.startIfNeeded()
        }
    }

    private var askSendModeBinding: Binding<ClientVoiceAskSendMode> {
        Binding {
            viewModel.askSendMode
        } set: { value in
            viewModel.toggleAskSendMode(value)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 8) {
            if viewModel.isSpeaking {
                ProgressView()
                    .controlSize(.small)
                Text("Speaking prompt to the client...")
                    .foregroundStyle(.secondary)
            } else if viewModel.isListening {
                Image(systemName: "mic.fill")
                Text("Listening for the client response...")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.cancelListening()
                } label: {
                    Image(systemName: "mic.slash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Stop listening")
                .disabled(viewModel.isSubmitting)
            } else {
                Text("Waiting for your review before submitting.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }
}
