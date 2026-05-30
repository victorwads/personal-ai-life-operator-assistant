import SwiftUI

struct IssuesScreen: View {
    let feature: IssuesFeature

    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        FeatureScreenContainer(
            title: "Issues",
            subtitle: "Active operational issues for this profile."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button("Refresh") {
                        Task { await loadIssues() }
                    }
                    .disabled(isLoading)
                }

                if isLoading {
                    ProgressView("Loading active issues...")
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
                        title: "No active issues",
                        message: "Pending or suspended issues will appear here.",
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
        .task {
            await loadIssues()
        }
    }

    private func issueCard(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(issue.title)
                    .font(.headline)

                Spacer()

                Button("Open") {
                    // TODO: Open issue details screen.
                }
                .buttonStyle(.bordered)
            }

            Text(issue.description)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Status: \(issue.status.rawValue)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15), in: Capsule())

                Text("Priority: \(issue.priority.rawValue)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15), in: Capsule())
            }

            if let suspendUntil = issue.suspendUntil {
                Text("Suspended until: \(suspendUntil.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func loadIssues() async {
        isLoading = true
        errorMessage = nil

        do {
            issues = try await feature.repository.getActiveIssues()
        } catch {
            errorMessage = error.localizedDescription
            issues = []
        }

        isLoading = false
    }
}
