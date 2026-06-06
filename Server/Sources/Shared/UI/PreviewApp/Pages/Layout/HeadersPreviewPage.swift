import SwiftUI

struct HeadersPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Headers",
                    subtitle: "Feature headers with optional subtitles, icons, and trailing actions."
                ) {
                    DSFeatureHeader(
                        title: "Memories",
                        subtitle: "Permanent assistant context saved for this profile.",
                        systemImage: "brain.head.profile"
                    ) {
                        DSRefreshButton(action: {})
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
