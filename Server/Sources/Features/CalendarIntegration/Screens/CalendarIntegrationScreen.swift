import SwiftUI

struct CalendarIntegrationScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Calendar",
            subtitle: "Calendar integration workspace."
        ) {
            EmptyStateView(
                title: "Calendar integration is not implemented yet",
                message: "Calendar integration tools and setup will appear here.",
                systemImage: "calendar"
            )
        }
    }
}

