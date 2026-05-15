import SwiftUI

struct ClientVoiceScreen: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var events: [ClientVoiceEvent] = []
    @State private var errorText: String?
    @State private var isWorking = false

    @State private var pendingAnswerById: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            List(events) { event in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(event.kind == .ask ? "Ask" : "Speak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(event.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if event.kind == .speak {
                        Text(event.text ?? "")
                            .font(.body)

                        HStack {
                            Spacer()
                            Button {
                                Task { await replay(event) }
                            } label: {
                                Label("Play again", systemImage: "play.circle")
                            }
                            .disabled(isWorking || (event.text ?? "").isEmpty)
                        }
                    } else {
                        Text(event.prompt ?? "")
                            .font(.body)

                        if event.askStatus == .pending {
                            HStack(spacing: 10) {
                                TextField("Type the client's response", text: Binding(
                                    get: { pendingAnswerById[event.id, default: ""] },
                                    set: { pendingAnswerById[event.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)

                                Button("Submit") {
                                    Task { await submitAnswer(event) }
                                }
                                .disabled(isWorking || pendingAnswerById[event.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .keyboardShortcut(.defaultAction)
                            }
                        } else if let transcript = event.transcript, !transcript.isEmpty {
                            Text("Answer: \(transcript)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .task { await reload() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Client Voice")
                    .font(.headline)

                let pending = events.filter { $0.kind == .ask && $0.askStatus == .pending }.count
                if pending > 0 {
                    Text("\(pending) pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No pending asks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Refresh") {
                Task { await reload() }
            }
            .disabled(isWorking)
        }
    }

    private func reload() async {
        events = await appModel.clientVoiceEventsRepository.list()
    }

    private func replay(_ event: ClientVoiceEvent) async {
        let text = (event.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorText = nil
        isWorking = true
        defer { isWorking = false }
        await appModel.voiceAssistant.speak(text, language: appModel.speechLanguage, voiceIdentifier: appModel.speechVoiceIdentifier, rate: appModel.speechRate)
    }

    private func submitAnswer(_ event: ClientVoiceEvent) async {
        errorText = nil
        isWorking = true
        defer { isWorking = false }

        let text = (pendingAnswerById[event.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            _ = try await appModel.clientVoiceEventsRepository.answerAsk(id: event.id, transcript: text)
            await appModel.refreshPendingClientAskCount()
            pendingAnswerById[event.id] = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
