import SwiftUI

struct ClientVoiceScreen: View {
    @StateObject private var viewModel: ClientVoiceScreenViewModel

    init(feature: ClientVoiceFeature) {
        _viewModel = StateObject(
            wrappedValue: ClientVoiceScreenViewModel(
                repository: feature.repository,
                sharedLocks: feature.context.sharedLocks
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
                    DSRefreshButton(isLoading: viewModel.isLoading) {
                        viewModel.refresh()
                    }
                }

                HStack(spacing: 8) {
                    DSBadge("Initialized", secondaryText: "\(viewModel.initializedRequests.count)", style: .info)
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
                            if !viewModel.initializedRequests.isEmpty {
                                requestSection(
                                    title: "Initialized",
                                    subtitle: "Requests waiting for a manual client or device action.",
                                    requests: viewModel.initializedRequests
                                )
                            }

                            if !viewModel.waitingAgentRequests.isEmpty {
                                requestSection(
                                    title: "Answered / Waiting Agent",
                                    subtitle: "The client already answered and the agent can now consume the response.",
                                    requests: viewModel.waitingAgentRequests
                                )
                            }

                            if !viewModel.historyRequests.isEmpty {
                                requestSection(
                                    title: "History",
                                    subtitle: "Completed, failed, and cancelled interaction records.",
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
                }

                Text(nonEmpty(request.promptText, fallback: "No prompt text recorded."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if request.kind == .ask, request.status == .initialized {
                    initializedAskComposer(for: request)
                } else if request.kind == .speak, request.status == .initialized {
                    initializedSpeakActions(for: request)
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
                    metadataRow("Source", request.source?.rawValue ?? "Not recorded")
                }
            }
        }
    }

    private func initializedAskComposer(for request: ClientInteractionRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Response")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                TextField(
                    "Type the client response and press Enter",
                    text: viewModel.bindingForResponseDraft(requestID: request.id)
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.submitResponse(for: request)
                }

                Button("Submit") {
                    viewModel.submitResponse(for: request)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmitResponse(for: request))
            }

            if let submissionError = viewModel.submissionError(for: request.id) {
                Text(submissionError)
                    .foregroundStyle(.red)
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

            if let actionError = viewModel.submissionError(for: request.id) {
                Text(actionError)
                    .foregroundStyle(.red)
            }
        }
    }

    private func sectionIcon(for title: String) -> String {
        switch title {
        case "Initialized":
            return "clock.badge.exclamationmark"
        case "Answered / Waiting Agent":
            return "bubble.left.and.text.bubble.right"
        default:
            return "clock.arrow.circlepath"
        }
    }

    private func statusText(for status: ClientInteractionRequest.Status) -> String {
        switch status {
        case .initialized:
            return "initialized"
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
        case .waitingAgent:
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

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? fallback : value
    }
}
