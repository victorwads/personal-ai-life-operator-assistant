import SwiftUI

struct EmailIntegrationScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Email",
            subtitle: "Email integration workspace."
        ) {
            EmptyStateView(
                title: "Email integration is not implemented yet",
                message: "Email integration tools and setup will appear here.",
                systemImage: "envelope"
            )
        }
    }
}

