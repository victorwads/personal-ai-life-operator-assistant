import SwiftUI

struct SensitiveDataScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Sensitive Data",
            subtitle: "Protected profile-scoped values and controls."
        ) {
            EmptyStateView(
                title: "Sensitive data workspace is not implemented yet",
                message: "Profile-scoped sensitive data controls and stored protected values will appear here.",
                systemImage: "lock.shield"
            )
        }
    }
}
