import SwiftUI

struct ContainersPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Containers",
                    subtitle: "Reusable framing for feature screens, empty states, and nested content."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureScreenContainer(
                            title: "FeatureScreenContainer Title",
                            subtitle: "Optional subtitle text gives context for the feature screen."
                        ) {
                            KeyValueCardView(
                                title: "Content Closure Example",
                                rows: [
                                    KeyValueCardRow("Content Row", "Rendered inside the container"),
                                    KeyValueCardRow("Layout", "Top-leading with shared padding")
                                ]
                            )
                        }

                        EmptyStateView(
                            title: "EmptyStateView Title",
                            message: "Message text explains what is missing and what can happen next.",
                            systemImage: "tray",
                            actionTitle: "Action Title",
                            action: {}
                        )
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
