import SwiftUI

struct IssueRowView: View {
    let issue: Issue
    let onOpenIssueDetail: () -> Void
    let onResolve: () -> Void
    let onCancel: () -> Void
    let onSuspend: () -> Void
    let onReactivate: () -> Void

    var body: some View {
        DSListCardRow(
            title: issue.title,
            description: issue.description
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DSBadge(
                        "Status",
                        secondaryText: IssueDisplaySupport.statusTitle(for: issue.status),
                        style: IssueDisplaySupport.statusBadgeStyle(for: issue.status)
                    )

                    DSBadge(
                        "Priority",
                        secondaryText: IssueDisplaySupport.priorityText(for: issue.priority),
                        style: IssueDisplaySupport.priorityBadgeStyle(for: issue.priority)
                    )

                    if issue.status == .suspended {
                        DSBadge(
                            "Until",
                            secondaryText: IssueDisplaySupport.formattedSuspendUntil(issue.suspendUntil),
                            style: .warning
                        )
                    }
                }
            }
        } trailing: {
            HStack(spacing: 8) {
                Button("Open") {
                    onOpenIssueDetail()
                }
                .buttonStyle(.bordered)

                IssueActionsMenu(
                    status: issue.status,
                    onResolve: onResolve,
                    onCancel: onCancel,
                    onSuspend: onSuspend,
                    onReactivate: onReactivate
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpenIssueDetail()
        }
    }
}
