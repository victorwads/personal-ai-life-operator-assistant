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

            if !pendingAsks.isEmpty {
                pendingPanel
            }

            List {
                Section("History") {
                    ForEach(historyEvents) { event in
                        if event.kind == .ask {
                            askRow(event, showAnswer: true)
                        } else {
                            speakRow(event)
                        }
                    }
                }
            }
        }
        .padding(12)
        .task {
            guard !PreviewSupport.isRunningForPreviews else { return }
            await reload()
        }
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

    private var pendingAsks: [ClientVoiceEvent] {
        events.filter { $0.kind == .ask && $0.askStatus == .pending }
    }

    private var historyEvents: [ClientVoiceEvent] {
        events.filter { $0.kind != .ask || $0.askStatus != .pending }
    }

    private var pendingPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Pending response")
                        .font(.headline)
                    Spacer()
                }

                ForEach(pendingAsks) { event in
                    pendingAskCard(event)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func pendingAskCard(_ event: ClientVoiceEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ask")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await replay(event) }
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Play again")
                .disabled(isWorking || (event.prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(event.prompt ?? "")
                .font(.body)

            HStack(spacing: 10) {
                TextField("Type the client's response", text: Binding(
                    get: { pendingAnswerById[event.id, default: ""] },
                    set: { pendingAnswerById[event.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    Task { await submitAnswer(event) }
                }

                Button {
                    Task { await submitAnswer(event) }
                } label: {
                    Text("Submit")
                }
                .disabled(isWorking || pendingAnswerById[event.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.35))
        )
    }

    @ViewBuilder
    private func speakRow(_ event: ClientVoiceEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await replay(event) }
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Play again")
                .disabled(isWorking || (event.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(event.text ?? "")
                .font(.body)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func askRow(_ event: ClientVoiceEvent, showAnswer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ask")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await replay(event) }
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Play again")
                .disabled(isWorking || (event.prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(event.prompt ?? "")
                .font(.body)

            if showAnswer, let transcript = event.transcript, !transcript.isEmpty {
                Text("Response: \(transcript)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func reload() async {
        events = await appModel.clientVoiceEventsRepository.list()
    }

    private func replay(_ event: ClientVoiceEvent) async {
        let text = (event.kind == .ask ? (event.prompt ?? "") : (event.text ?? ""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            _ = try await appModel.clientVoiceEventsRepository.answerAsk(id: event.id, response: text)
            await appModel.refreshPendingClientAskCount()
            pendingAnswerById[event.id] = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    ClientVoiceScreen()
        .environmentObject(AppModel.preview)
        .frame(width: 980, height: 680)
}
