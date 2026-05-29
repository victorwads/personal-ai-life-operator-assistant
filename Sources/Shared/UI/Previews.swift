import SwiftUI

struct SharedUIPreviews: View {
    var body: some View {
        ScrollView {
            previewSections
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 24)
        }
    }

    private var previewSections: some View {
        VStack(alignment: .leading, spacing: 28) {
            featureScreenContainerPreview
            emptyStatePreview
            keyValueCardPreview
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureScreenContainerPreview: some View {
        previewSection("FeatureScreenContainer") {
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
            .frame(height: 260)
            .previewFrame()
        }
    }

    private var emptyStatePreview: some View {
        previewSection("EmptyStateView") {
            EmptyStateView(
                title: "EmptyStateView Title",
                message: "Message text explains what is missing and what can happen next.",
                systemImage: "tray",
                actionTitle: "Action Title",
                action: {}
            )
            .previewFrame()
        }
    }

    private var keyValueCardPreview: some View {
        previewSection("KeyValueCardView") {
            VStack(alignment: .leading, spacing: 12) {
                KeyValueCardView(
                    title: "KeyValueCardView Title",
                    rows: [
                        KeyValueCardRow("First Key", "Primary value"),
                        KeyValueCardRow("Second Key", "Secondary value"),
                        KeyValueCardRow("Third Key", "Additional value")
                    ]
                )

                KeyValueCardView(
                    key: "Single Key",
                    value: "Single value"
                )
            }
            .previewFrame()
        }
    }

    private func previewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            content()
        }
    }
}

private extension View {
    func previewFrame() -> some View {
        frame(maxWidth: 680, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

#Preview("Shared UI") {
    SharedUIPreviews()
        .frame(width: 760, height: 620)
}
