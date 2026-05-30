import SwiftUI

struct IssuesScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Issues",
            subtitle: "Profile-scoped issues, active work, and resolution history."
        ) {
            EmptyStateView(
                title: "Issues workspace is not implemented yet",
                message: "Profile-scoped issues, active work, status, and resolution history will appear here.",
                systemImage: "list.bullet.clipboard"
            )
        }
    }
}
