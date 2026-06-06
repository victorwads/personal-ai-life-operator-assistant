import SwiftUI

struct MessageBubblesPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Message Bubbles",
                    subtitle: "Chat-like presentation for client and assistant dialogue."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        DSMessageBubbleRow(
                            alignment: .leading,
                            title: "Client",
                            subtitle: "10:42 AM"
                        ) {
                            Text("Could you send the latest issue summary when you get a chance?")
                        } footer: {
                            Text("Received")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        DSMessageBubbleRow(
                            alignment: .trailing,
                            title: "Assistant",
                            subtitle: "10:43 AM"
                        ) {
                            Text("Absolutely. I can send the summary and flag anything still blocked.")
                                .foregroundStyle(.white)
                        } footer: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Sent")
                            }
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.82))
                        }

                        DSMessageBubbleRow(
                            alignment: .leading,
                            title: "Client Voice",
                            subtitle: "Input controls also fit here"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("This row supports arbitrary content, not just plain text.")
                                Toggle("Include transcript", isOn: .constant(true))
                            }
                        }
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
