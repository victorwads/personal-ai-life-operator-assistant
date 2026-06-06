import SwiftUI

struct RuntimeStatusPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Runtime Status",
                    subtitle: "Compact service status capsules with state dots and trailing actions."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            DSRuntimeStatusBadge(
                                title: "MCP Server",
                                secondaryText: "Port 8080",
                                state: .running,
                                trailingSystemImage: "stop.fill",
                                trailingActionLabel: "Stop MCP Server",
                                trailingAction: {}
                            )

                            DSRuntimeStatusBadge(
                                title: "Crawling",
                                secondaryText: "Stopped",
                                state: .stopped,
                                trailingSystemImage: "play.fill",
                                trailingActionLabel: "Start Crawling",
                                trailingAction: {}
                            )
                        }

                        HStack(spacing: 8) {
                            DSRuntimeStatusBadge(title: "AI Connection", secondaryText: "Starting", state: .starting)
                            DSRuntimeStatusBadge(title: "WebView", secondaryText: "Failed", state: .failed)
                            DSRuntimeStatusBadge(title: "Runtime", state: .idle)
                        }
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
