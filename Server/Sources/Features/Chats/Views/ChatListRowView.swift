import SwiftUI
import AppKit

struct ChatListRowView: View {
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let timeText = chat.lastMessageTimeText, !timeText.isEmpty {
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                DSCodableDebugInspector(title: "Chat JSON", value: chat)
            }

            if let image = previewImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 72, maxHeight: 72, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let preview = chat.lastMessagePreview, !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("No preview available")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                if chat.unreadCount > 0 {
                    DSBadge("Unread", secondaryText: "\(chat.unreadCount)", systemImage: "envelope.badge", style: .warning)
                }

                if chat.unhandledCount > 0 {
                    DSBadge("Unhandled", secondaryText: "\(chat.unhandledCount)", systemImage: "exclamationmark.circle", style: .warning)
                }

                DSBadge("WhatsApp", systemImage: "message", style: .info)
            }
        }
        .padding(.vertical, 4)
    }

    private func previewImage() -> NSImage? {
        guard let relativePath = chat.lastMessageLocalMediaPath, !relativePath.isEmpty else { return nil }
        let absoluteURL = ChatMediaStorage.absoluteURL(forRelativePath: relativePath)
        return NSImage(contentsOf: absoluteURL)
    }
}
