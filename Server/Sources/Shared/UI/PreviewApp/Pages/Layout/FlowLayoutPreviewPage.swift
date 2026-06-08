import SwiftUI

struct FlowLayoutPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Flow Layout",
                    subtitle: "Wrapping rows that keep compact badges readable inside constrained headers."
                ) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trailing alignment in a narrow width")
                                .font(.subheadline.weight(.semibold))

                            DSFlowLayout(alignment: .trailing, spacing: 6, rowSpacing: 6) {
                                DSRuntimeStatusBadge(title: "MCP Server", secondaryText: "Running", state: .running)
                                DSRuntimeStatusBadge(title: "AI Connection", secondaryText: "Starting", state: .starting)
                                DSRuntimeStatusBadge(title: "WebView", secondaryText: "Failed", state: .failed)
                                DSRuntimeStatusBadge(title: "Logs", secondaryText: "Open", state: .idle)
                            }
                            .frame(width: 340, alignment: .trailing)
                            .padding(12)
                            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Leading alignment with more badges")
                                .font(.subheadline.weight(.semibold))

                            DSFlowLayout(alignment: .leading, spacing: 6, rowSpacing: 6) {
                                DSBadge("Profile")
                                DSBadge("Runtime")
                                DSBadge("Window")
                                DSBadge("MCP")
                                DSBadge("WebView", style: .info)
                                DSBadge("WhatsApp", style: .success)
                                DSBadge("AI Connection", style: .warning)
                            }
                            .frame(width: 420, alignment: .leading)
                            .padding(12)
                            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
