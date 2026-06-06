import SwiftUI

struct DebugInspectorsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Debug Inspectors",
                    subtitle: "Popover and inline inspectors for structured values."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Text("Open JSON popover")
                                .foregroundStyle(.secondary)

                            DSDebugObjectsInspector(
                                title: "Sample Debug Objects",
                                items: SampleDebugItems.items
                            )
                        }

                        DSDebugObjectsInspector(
                            title: "Inline Debug Objects",
                            items: SampleDebugItems.items,
                            presentationStyle: .inline
                        )
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
