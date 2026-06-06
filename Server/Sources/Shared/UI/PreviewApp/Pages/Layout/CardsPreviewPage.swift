import SwiftUI

struct CardsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Cards",
                    subtitle: "Reusable section cards for consistent visual grouping."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        DSCard(title: "Normal Card") {
                            Text("Reusable section cards keep feature screens visually consistent.")
                                .foregroundStyle(.secondary)
                        }

                        DSCard(
                            title: "Emphasized Card",
                            systemImage: "hammer",
                            prominence: .emphasized
                        ) {
                            Text("Use emphasized cards sparingly for primary metadata or screen-level context.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
