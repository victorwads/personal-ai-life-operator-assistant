import SwiftUI

struct AIConnectionScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "AI Connection",
            subtitle: "AI provider status, model execution, assistant prompts, streaming output, tool calls, and traces."
        ) {
            EmptyStateView(
                title: "AI connection workspace is not implemented yet",
                message: "Provider status, model execution, assistant prompts, streaming output, tool calls, and traces will appear here.",
                systemImage: "cpu"
            )
        }
    }
}
