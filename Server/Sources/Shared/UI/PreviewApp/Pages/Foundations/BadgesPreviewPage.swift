import SwiftUI

struct BadgesPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Badges",
                    subtitle: "Pills for status, metadata, and lightweight labeling."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            DSBadge("Neutral")
                            DSBadge("Info", systemImage: "info.circle", style: .info)
                            DSBadge("Success", systemImage: "checkmark.circle", style: .success)
                            DSBadge("Warning", systemImage: "exclamationmark.triangle", style: .warning)
                            DSBadge("Danger", systemImage: "xmark.octagon", style: .danger)
                        }

                        DSBadge("Status", secondaryText: "Waiting", systemImage: "clock", style: .neutral)
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
