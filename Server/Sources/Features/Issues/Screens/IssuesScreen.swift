import SwiftUI

struct IssuesScreen: View {
    let feature: IssuesFeature
    let onOpenIssueDetail: (String) -> Void

    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var actionMessageStyle: ActionMessageStyle = .neutral
    @State private var pendingTransitionRequest: IssueStatusTransitionRequest?
    @State private var selectedFilter: IssueListFilter = .active

    private enum ActionMessageStyle {
        case neutral
        case success
        case danger

        var foregroundColor: Color {
            switch self {
            case .neutral:
                return .secondary
            case .success:
                return .green
            case .danger:
                return .red
            }
        }
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Issues",
                    subtitle: "Operational and audit hub for profile work."
                ) {
                    DSRefreshButton(isLoading: isLoading) {
                        Task { await loadIssues() }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(IssueListFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        DSBadge("Filter", secondaryText: selectedFilter.title, style: .info)

                        if !issues.isEmpty {
                            DSBadge("Count", secondaryText: "\(issues.count)", style: .neutral)
                        }
                    }
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(actionMessageStyle.foregroundColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLoading && issues.isEmpty {
                    ProgressView("Loading issues...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    EmptyStateView(
                        title: "Could not load issues",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle",
                        actionTitle: "Retry",
                        action: {
                            Task { await loadIssues() }
                        }
                    )
                } else if issues.isEmpty {
                    EmptyStateView(
                        title: "No issues in this filter",
                        message: "Issues matching the selected status filter will appear here.",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(issues, id: \.id) { issue in
                                issueCard(issue)
                            }
                        }
                    }
                }
            }
        }
        .task(id: selectedFilter) {
            await loadIssues()
        }
        .sheet(item: $pendingTransitionRequest) { request in
            IssueStatusTransitionSheet(
                request: request,
                onSubmit: performTransition
            )
        }
    }

    private func issueCard(_ issue: Issue) -> some View {
        IssueRowView(
            issue: issue,
            onOpenIssueDetail: {
                openIssue(issue)
            },
            onResolve: {
                beginTransition(issue, mode: .resolve)
            },
            onCancel: {
                beginTransition(issue, mode: .cancel)
            },
            onSuspend: {
                beginTransition(issue, mode: .suspend)
            },
            onReactivate: {
                beginTransition(issue, mode: .reactivate)
            }
        )
    }

    @MainActor
    private func loadIssues() async {
        isLoading = true
        errorMessage = nil

        do {
            issues = try await feature.listIssues(filter: selectedFilter)
        } catch {
            errorMessage = error.localizedDescription
            issues = []
        }

        isLoading = false
    }

    private func beginTransition(_ issue: Issue, mode: IssueStatusTransitionMode) {
        guard let issueId = issue.id, !issueId.isEmpty else {
            return
        }

        pendingTransitionRequest = IssueStatusTransitionRequest(
            issueId: issueId,
            issueTitle: issue.title,
            currentStatus: issue.status,
            mode: mode
        )
    }

    @MainActor
    private func performTransition(
        request: IssueStatusTransitionRequest,
        reason: String?,
        suspendUntil: Date?
    ) async throws {
        switch request.mode {
        case .resolve:
            guard let reason else {
                throw IssueStatusTransitionError.reasonRequired
            }
            try await feature.statusTransitionService.resolveIssue(issueId: request.issueId, reason: reason)
        case .cancel:
            guard let reason else {
                throw IssueStatusTransitionError.reasonRequired
            }
            try await feature.statusTransitionService.cancelIssue(issueId: request.issueId, reason: reason)
        case .suspend:
            guard let suspendUntil else {
                throw IssueStatusTransitionError.suspendUntilMustBeFuture
            }
            try await feature.statusTransitionService.suspendIssue(
                issueId: request.issueId,
                suspendUntil: suspendUntil,
                reason: reason
            )
        case .reactivate:
            guard let reason else {
                throw IssueStatusTransitionError.reasonRequired
            }
            try await feature.statusTransitionService.reactivateIssue(issueId: request.issueId, reason: reason)
        }

        actionMessage = "\(request.issueTitle) updated."
        actionMessageStyle = .success
        pendingTransitionRequest = nil
        await loadIssues()
    }

    private func openIssue(_ issue: Issue) {
        guard let issueId = issue.id, !issueId.isEmpty else {
            return
        }

        onOpenIssueDetail(issueId)
    }
}
