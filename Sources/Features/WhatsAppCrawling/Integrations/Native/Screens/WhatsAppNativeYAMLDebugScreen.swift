import SwiftUI

struct WhatsAppNativeYAMLDebugScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Native YAML Debug",
            subtitle: "Native accessibility YAML, extraction results, and flow diagnostics."
        ) {
            EmptyStateView(
                title: "Native YAML debug is not implemented yet",
                message: "Native accessibility YAML, extraction results, active flows, and element matching diagnostics will appear here.",
                systemImage: "ladybug"
            )
        }
    }
}
