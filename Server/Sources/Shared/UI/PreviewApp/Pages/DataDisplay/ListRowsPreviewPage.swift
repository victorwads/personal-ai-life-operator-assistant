import SwiftUI

struct ListRowsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "List Rows",
                    subtitle: "Card rows for indexes, lists, and master-detail screens."
                ) {
                    DSListCardRow(
                        title: "Unread client message",
                        subtitle: "Needs response",
                        description: "A shared list row keeps feature indexes consistent without baking feature-specific logic into Shared/UI.",
                        systemImage: "message"
                    ) {
                        HStack(spacing: 6) {
                            DSBadge("Urgent", style: .warning)
                            DSBadge("Open", style: .info)
                        }
                    } trailing: {
                        Button("Open") {}
                            .buttonStyle(.bordered)
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
