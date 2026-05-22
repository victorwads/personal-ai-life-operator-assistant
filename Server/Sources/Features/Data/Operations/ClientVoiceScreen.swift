import SwiftUI

struct ClientVoiceScreen: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var events: [ClientVoiceEvent] = []
    @State private var errorText: String?
    @State private var isWorking = false
    @State private var showingClearHistoryConfirmation = false

    @State private var pendingAnswerById: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if events.isEmpty {
                        emptyState
                    } else {
                        // Preserve the original order while presenting each record as a chat bubble.
                        ForEach(events) { event in
                            chatEntry(event)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.windowBackgroundColor),
                        Color(.controlBackgroundColor).opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(12)
        .task {
            guard !PreviewSupport.isRunningForPreviews else { return }
            await reload()
        }
        .task {
            guard !PreviewSupport.isRunningForPreviews else { return }
            for await _ in NotificationCenter.default.notifications(named: .clientVoiceEventsRepositoryDidChange) {
                await reload()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
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

            Button("Clear") {
                showingClearHistoryConfirmation = true
            }
            .disabled(isWorking || events.isEmpty)
            .foregroundStyle(.red)
        }
        .alert("Clear client voice history?", isPresented: $showingClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                Task { await clearHistory() }
            }
        } message: {
            Text("This removes all client voice events from local history.")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No client voice history yet.")
                .font(.headline)
            Text("Speak or ask something from the voice client and the conversation will appear here as chat bubbles.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder
    private func chatEntry(_ event: ClientVoiceEvent) -> some View {
        switch event.kind {
        case .speak:
            speakBubble(event)
        case .ask:
            askBubble(event)
        }
    }

    @ViewBuilder
    private func speakBubble(_ event: ClientVoiceEvent) -> some View {
        let text = (event.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        HStack {
            VStack(alignment: .leading, spacing: 8) {
                bubbleHeader(
                    title: "Assistant",
                    systemImage: "speaker.wave.2.fill",
                    trailing: AnyView(replayButton(for: event, text: text))
                )

                Text(text.isEmpty ? " " : text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: 480, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.20))
            )

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func askBubble(_ event: ClientVoiceEvent) -> some View {
        let isLost = event.askStatus == .lost
        let prompt = (event.prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = (event.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingDraft = pendingAnswerById[event.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    bubbleHeader(
                        title: "Assistant",
                        systemImage: "questionmark.circle.fill",
                        isLost: isLost,
                        trailing: AnyView(replayButton(for: event, text: prompt))
                    )

                    Text(prompt.isEmpty ? " " : prompt)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: 480, alignment: .leading)
                .background(
                    (isLost ? Color.orange.opacity(0.10) : Color.accentColor.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isLost ? Color.orange.opacity(0.30) : Color.accentColor.opacity(0.20))
                )

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 2)

            if !transcript.isEmpty {
                HStack {
                    Spacer(minLength: 32)

                    // Incoming answers stay right-aligned to read like a reply from the client.
                    VStack(alignment: .leading, spacing: 6) {
                        bubbleHeader(title: "Client", systemImage: "person.fill")

                        Text(transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.green.opacity(0.20))
                    )
                }
                .padding(.horizontal, 2)
            } else if event.askStatus == .pending {
                HStack {
                    Spacer(minLength: 32)

                    // Pending asks keep the reply field attached to the question itself.
                    VStack(alignment: .leading, spacing: 10) {
                        bubbleHeader(title: "Waiting for client response", systemImage: "clock.arrow.circlepath")

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
                            .disabled(isWorking || pendingDraft.isEmpty)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.yellow.opacity(0.35))
                    )
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func bubbleHeader(title: String, systemImage: String, isLost: Bool = false, trailing: AnyView? = nil) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            if isLost {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .help("Essa chamada foi perdida")
                    .accessibilityLabel("Essa chamada foi perdida")
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
    }

    @ViewBuilder
    private func replayButton(for event: ClientVoiceEvent, text: String) -> some View {
        Button {
            Task { await replay(event) }
        } label: {
            Image(systemName: "play.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Play again")
        .disabled(isWorking || text.isEmpty)
    }

    private func reload() async {
        events = await appModel.clientVoiceEventsRepository.list()
    }

    private func clearHistory() async {
        errorText = nil
        isWorking = true
        defer { isWorking = false }

        pendingAnswerById.removeAll()
        await appModel.clientVoiceEventsRepository.clearAll()
        await appModel.refreshPendingClientAskCount()
        await reload()
    }

    private func replay(_ event: ClientVoiceEvent) async {
        let text = (event.kind == .ask ? (event.prompt ?? "") : (event.text ?? ""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorText = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await appModel.voiceAssistant.speak(
                text,
                language: appModel.voiceSettings.speechLanguage,
                voiceIdentifier: appModel.voiceSettings.speechVoiceIdentifier,
                rate: appModel.voiceSettings.speechRate
            )
        } catch {
            errorText = error.localizedDescription
        }
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
