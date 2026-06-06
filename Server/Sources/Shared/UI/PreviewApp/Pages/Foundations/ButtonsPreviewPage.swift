import SwiftUI

struct ButtonsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Buttons",
                    subtitle: "Simple shared button primitives and loading affordances."
                ) {
                    HStack(spacing: 12) {
                        DSRefreshButton(action: {})
                        DSRefreshButton(isLoading: true, action: {})
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
