import SwiftUI

struct TitledSectionsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Titled Sections",
                    subtitle: "Section headers that stay outside the card for grouped content."
                ) {
                    DSTitledSection(
                        title: "Execution Result",
                        subtitle: "Titles stay outside the content bubble for section-level context.",
                        systemImage: "terminal",
                        prominence: .emphasized
                    ) {
                        Button("Retry") {}
                            .buttonStyle(.bordered)
                    } content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Use titled sections for settings groups, metadata panes, and other reusable content blocks.")
                                .foregroundStyle(.secondary)

                            DSCodeBlock(
                                """
                                {
                                  "status": "ok",
                                  "duration_ms": 142
                                }
                                """
                            )
                            .frame(height: 84)
                        }
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
