import SwiftUI

struct ClientVoiceScreen: View {
    @StateObject private var viewModel: ClientVoiceScreenViewModel

    init(feature: ClientVoiceFeature) {
        _viewModel = StateObject(
            wrappedValue: ClientVoiceScreenViewModel(repository: feature.repository)
        )
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Voice Client",
                    subtitle: "Auditable ask and speak requests between the assistant and the client."
                ) {
                    DSRefreshButton(isLoading: viewModel.isLoading) {
                        viewModel.refresh()
                    }
                }

                HStack(spacing: 8) {
                    DSBadge("Pending", secondaryText: "\(viewModel.pendingRequests.count)", style: .info)
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
                        message: "Pending asks and speak requests will appear here once Voice Client starts creating audit records.",
                        systemImage: "waveform"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if !viewModel.pendingRequests.isEmpty {
                                requestSection(
                                    title: "Pending",
                                    subtitle: "Pending requests are shown first and ordered from oldest to newest.",
                                    requests: viewModel.pendingRequests
                                )
                            }

                            if !viewModel.historyRequests.isEmpty {
                                requestSection(
                                    title: "History",
                                    subtitle: "Delivered, completed, cancelled, and failed requests.",
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
            systemImage: title == "Pending" ? "clock.badge.exclamationmark" : "clock.arrow.circlepath"
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
            title: requestTitle(for: request),
            systemImage: request.kind == .ask ? "questionmark.bubble" : "speaker.wave.2"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    DSBadge("Kind", secondaryText: request.kind.rawValue, style: .info)
                    DSBadge(
                        "Status",
                        secondaryText: request.status.rawValue,
                        style: badgeStyle(for: request.status)
                    )
                    DSBadge(
                        "Presence",
                        secondaryText: request.clientPresenceAtCreation.rawValue,
                        style: badgeStyle(for: request.clientPresenceAtCreation)
                    )
                }

                Text(nonEmpty(request.promptText, fallback: "No prompt text recorded."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if let responseText = trimmed(request.responseText) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(responseText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                if let errorMessage = trimmed(request.errorMessage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    metadataRow("Issue ID", nonEmpty(request.issueId, fallback: "Not recorded"))
                    metadataRow("Created", formattedDate(request.requestedAt, fallback: "Not recorded"))

                    if request.completedAt != nil {
                        metadataRow("Completed", formattedDate(request.completedAt, fallback: "Not recorded"))
                    }

                    metadataRow("Source", sourceSummary(for: request))

                    if let answeredByDeviceId = trimmed(request.answeredByDeviceId) {
                        metadataRow("Answered By Device", answeredByDeviceId)
                    }

                    if !request.metadata.isEmpty {
                        metadataRow("Metadata", metadataSummary(for: request.metadata))
                    }
                }
            }
        }
    }

    private func requestTitle(for request: ClientInteractionRequest) -> String {
        switch request.kind {
        case .ask:
            return "Ask Client"
        case .speak:
            return "Speak To Client"
        }
    }

    private func badgeStyle(for status: ClientInteractionStatus) -> DSBadge.Style {
        switch status {
        case .pending:
            return .info
        case .delivered:
            return .warning
        case .completed:
            return .success
        case .cancelled, .failed:
            return .danger
        }
    }

    private func badgeStyle(for presence: ClientPresenceState) -> DSBadge.Style {
        switch presence {
        case .present:
            return .success
        case .absent:
            return .warning
        case .unknown:
            return .neutral
        }
    }

    private func sourceSummary(for request: ClientInteractionRequest) -> String {
        var components = [request.source.rawValue]

        if let targetDeviceId = trimmed(request.targetDeviceId) {
            components.append("target \(targetDeviceId)")
        }

        return components.joined(separator: " • ")
    }

    private func metadataSummary(for metadata: [String: String]) -> String {
        metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
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

    private func formattedDate(_ date: Date?, fallback: String) -> String {
        guard let date else {
            return fallback
        }

        return date.formatted(date: .abbreviated, time: .shortened)
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

@MainActor
final class ClientVoiceScreenViewModel: ObservableObject {
    @Published private(set) var requests: [ClientInteractionRequest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var pendingRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .pending }
    }

    var historyRequests: [ClientInteractionRequest] {
        requests.filter { $0.status != .pending }
    }

    private let repository: ClientInteractionRequestRepository
    private var listenerToken: FirestoreListenerToken?
    private var hasLoaded = false

    init(repository: ClientInteractionRequestRepository) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        refresh()
    }

    func refresh() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                requests = try await repository.listRequests()
                hasLoaded = true
                isLoading = false
                ensureObservation()
            } catch {
                errorMessage = error.localizedDescription
                requests = []
                isLoading = false
            }
        }
    }

    private func ensureObservation() {
        guard listenerToken == nil else { return }
        listenerToken = repository.observeRequests { [weak self] requests in
            Task { @MainActor in
                self?.requests = requests
            }
        }
    }
}
