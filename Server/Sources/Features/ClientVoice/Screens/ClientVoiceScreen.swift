import SwiftUI

struct ClientVoiceScreen: View {
    @StateObject private var viewModel: ClientVoiceScreenViewModel
    private let openAnswerDialog: (ClientInteractionRequest) -> Void

    init(feature: ClientVoiceFeature) {
        openAnswerDialog = { request in
            feature.openAnswerDialog(for: request)
        }
        let settings = feature.settings
        _viewModel = StateObject(
            wrappedValue: ClientVoiceScreenViewModel(
                repository: feature.repository,
                createManualRequestAction: { [weak feature] in
                    try await feature?.openNewManualRequestDialog()
                },
                speakConfigProvider: { settings.speechSpeakConfig }
            )
        )
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Voice Client",
                    subtitle: "Manual and auditable interaction requests for the client."
                ) {
                    HStack(spacing: 8) {
                        Button("New") {
                            viewModel.createManualRequest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isCreatingRequest)

                        DSRefreshButton(isLoading: viewModel.isLoading) {
                            viewModel.refresh()
                        }
                    }
                }

                if let creationErrorMessage = viewModel.creationErrorMessage {
                    Text(creationErrorMessage)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    DSBadge("Initialized", secondaryText: "\(viewModel.initializedRequests.count)", style: .info)
                    DSBadge("Speaking", secondaryText: "\(viewModel.speakingRequests.count)", style: .warning)
                    DSBadge("Waiting User", secondaryText: "\(viewModel.waitingUserRequests.count)", style: .warning)
                    DSBadge("Waiting Agent", secondaryText: "\(viewModel.waitingAgentRequests.count)", style: .warning)
                    DSBadge("History", secondaryText: "\(viewModel.historyRequests.count)", style: .neutral)
                }

                if viewModel.isLoading && viewModel.requests.isEmpty {
                    ProgressView("Loading client interaction requests...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage = viewModel.errorMessage {
                    EmptyStateView(
                        title: "Could not load Voice Client requests",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle",
                        actionTitle: "Retry",
                        action: {
                            viewModel.refresh()
                        }
                    )
                } else if viewModel.requests.isEmpty {
                    EmptyStateView(
                        title: "No client interaction requests yet",
                        message: "Ask and speak records will appear here as auditable requests.",
                        systemImage: "text.bubble"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if !viewModel.waitingUserRequests.isEmpty {
                                requestSection(
                                    title: "Waiting User",
                                    subtitle: "Questions already spoken and waiting for the client response.",
                                    requests: viewModel.waitingUserRequests
                                )
                            }

                            if !viewModel.activeRequests.filter({ $0.status != .waitingUser }).isEmpty {
                                requestSection(
                                    title: "All Other States",
                                    subtitle: "Requests that are not waiting for the client and are not completed yet.",
                                    requests: viewModel.activeRequests.filter { $0.status != .waitingUser }
                                )
                            }

                            if !viewModel.historyRequests.isEmpty {
                                requestSection(
                                    title: "History",
                                    subtitle: "Completed interaction records.",
                                    requests: viewModel.historyRequests
                                )
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private func requestSection(
        title: String,
        subtitle: String,
        requests: [ClientInteractionRequest]
    ) -> some View {
        DSTitledSection(
            title: title,
            subtitle: subtitle,
            systemImage: sectionIcon(for: title)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(requests, id: \.id) { request in
                    requestCard(request)
                }
            }
        }
    }

    private func requestCard(_ request: ClientInteractionRequest) -> some View {
        DSCard(
            title: request.kind == .ask ? "Ask Client" : "Speak To Client",
            systemImage: request.kind == .ask ? "questionmark.bubble" : "speaker.wave.2"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    DSBadge("Kind", secondaryText: request.kind.rawValue, style: .info)
                    DSBadge("Status", secondaryText: statusText(for: request.status), style: badgeStyle(for: request.status))
                    Spacer()

                    if viewModel.canDeletePermanently(request) {
                        Button {
                            viewModel.deleteRequest(request)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .help("Delete permanently")
                        .disabled(viewModel.isSubmitting(requestID: request.id))
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    let prompt = request.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let response = request.responseText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasText = !prompt.isEmpty || !response.isEmpty

                    if hasText {
                        if let id = request.id, viewModel.speakingRequestID == id {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Button(action: {
                                viewModel.speakRequest(request)
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Speak text aloud")
                            .frame(width: 16, height: 16)
                        }
                    }

                    Text(nonEmpty(request.promptText, fallback: "No prompt text recorded."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }


                if request.kind == .speak, request.status == .initialized {
                    initializedSpeakActions(for: request)
                }

                if canAnswerAsk(request) {
                    answerAskActions(for: request)
                }

                if let responseText = trimmed(request.responseText) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.status == .waitingAgent ? "Client Response" : "Response")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(responseText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    metadataRow("Issue ID", nonEmpty(request.issueId, fallback: "Not recorded"))
                    metadataRow("Source", request.device?.rawValue ?? "Not recorded")

                    if let actionError = viewModel.submissionError(for: request.id) {
                        Text(actionError)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func initializedSpeakActions(for request: ClientInteractionRequest) -> some View {
        HStack(spacing: 8) {
            Button("Mark as completed/read") {
                viewModel.markSpeakCompleted(request)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting(requestID: request.id))
        }
    }

    private func answerAskActions(for request: ClientInteractionRequest) -> some View {
        HStack(spacing: 8) {
            Button("Responder") {
                openAnswerDialog(request)
            }
            .buttonStyle(.borderedProminent)
            .disabled(request.id == nil)

            if request.status == .speaking {
                Text("This question may have been left open in a previous dialog.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionIcon(for title: String) -> String {
        switch title {
        case "Waiting User":
            return "person.crop.circle.badge.questionmark"
        case "All Other States":
            return "square.grid.2x2"
        case "History":
            return "clock.arrow.circlepath"
        default:
            return "bubble.left.and.bubble.right"
        }
    }

    private func statusText(for status: ClientInteractionRequest.Status) -> String {
        switch status {
        case .initialized:
            return "initialized"
        case .speaking:
            return "speaking"
        case .waitingUser:
            return "waiting user"
        case .waitingAgent:
            return "answered / waiting agent"
        case .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        }
    }

    private func badgeStyle(for status: ClientInteractionRequest.Status) -> DSBadge.Style {
        switch status {
        case .initialized:
            return .info
        case .speaking, .waitingAgent, .waitingUser:
            return .warning
        case .completed:
            return .success
        case .cancelled:
            return .danger
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func nonEmpty(_ value: String?, fallback: String) -> String {
        guard let value else { return fallback }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? fallback : value
    }

    private func canAnswerAsk(_ request: ClientInteractionRequest) -> Bool {
        request.kind == .ask && [.speaking, .waitingUser, .waitingAgent].contains(request.status)
    }
}
