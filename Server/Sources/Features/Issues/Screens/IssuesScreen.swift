import SwiftUI

struct IssuesScreen: View {
    let feature: IssuesFeature
    let onOpenIssueDetail: (String) -> Void

    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: IssueListFilter = .active

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
    }

    private func issueCard(_ issue: Issue) -> some View {
        DSListCardRow(
            title: issue.title,
            description: issue.description
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DSBadge(
                        "Status",
                        secondaryText: issue.status.rawValue,
                        style: badgeStyle(for: issue.status)
                    )

                    DSBadge(
                        "Priority",
                        secondaryText: String(issue.priority.rawValue),
                        style: badgeStyle(for: issue.priority)
                    )
                }

                if let suspendUntil = issue.suspendUntil {
                    Text("Suspended until: \(suspendUntil.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Button("Open") {
                openIssue(issue)
            }
            .buttonStyle(.bordered)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openIssue(issue)
        }
    }

    private func badgeStyle(for status: IssueStatus) -> DSBadge.Style {
        switch status {
        case .pending:
            return .info
        case .suspended:
            return .warning
        case .resolved:
            return .success
        case .cancelled:
            return .danger
        }
    }

    private func badgeStyle(for priority: IssuePriority) -> DSBadge.Style {
        switch priority.rawValue {
        case 1, 2:
            return .neutral
        case 3:
            return .info
        case 4:
            return .warning
        default:
            return .danger
        }
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

    private func openIssue(_ issue: Issue) {
        guard let issueId = issue.id, !issueId.isEmpty else {
            return
        }

        onOpenIssueDetail(issueId)
    }
}
