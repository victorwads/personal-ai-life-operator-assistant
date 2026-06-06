import SwiftUI
import AppKit

struct ChatMessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        DSMessageBubbleRow(
            alignment: alignment,
            title: message.author,
            subtitle: subtitle
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if let quoted = quotedText {
                    Text(quoted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                contentView
                    .foregroundStyle(alignment == .trailing ? .white : .primary)
            }
        } footer: {
            HStack(spacing: 6) {
                messageRoleBadge

                kindBadge

                if message.handled {
                    DSBadge("Handled", systemImage: "checkmark.circle", style: .success)
                } else {
                    DSBadge("Unhandled", systemImage: "clock.badge.exclamationmark", style: .warning)
                }

                Spacer(minLength: 8)

                DSDebugObjectsInspector(
                    title: "Message Debug",
                    items: [
                        DebugObjectItem(title: "Message", value: message)
                    ]
                )
            }
        }
    }

    private var messageRoleBadge: some View {
        switch messageRole {
        case .assistant:
            return DSBadge("Assistant", systemImage: "sparkles", style: .success)
        case .manualOutgoing:
            return DSBadge("Manual", systemImage: "paperplane", style: .info)
        case .client:
            return DSBadge("Client", systemImage: "person", style: .neutral)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.kind {
        case .text:
            Text(message.text ?? "(empty text message)")
        case .image:
            imageMessageContent
        case .sticker:
            mediaPreviewOrPlaceholder(placeholder: "[Sticker]")
        case .audio:
            Label(message.text ?? "Audio message", systemImage: "waveform")
        case .unknown:
            Label(message.text ?? "Unsupported message payload", systemImage: "questionmark.circle")
        }
    }

    private var alignment: DSMessageBubbleAlignment {
        message.direction == .sent ? .trailing : .leading
    }

    private var messageRole: MessageRole {
        if message.sentByAssistant == true {
            return .assistant
        }
        if message.direction == .sent {
            return .manualOutgoing
        }
        return .client
    }

    private var subtitle: String? {
        guard let date = message.dateTime else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var quotedText: String? {
        guard let quotedMessageText = message.quotedMessageText, !quotedMessageText.isEmpty else { return nil }
        if let quotedMessageAuthor = message.quotedMessageAuthor, !quotedMessageAuthor.isEmpty {
            return "\(quotedMessageAuthor): \(quotedMessageText)"
        }
        return quotedMessageText
    }

    private var trimmedMessageText: String? {
        guard let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    private var kindBadge: some View {
        switch message.kind {
        case .text:
            return DSBadge("Text", systemImage: "text.bubble", style: .neutral)
        case .image:
            return DSBadge("Image", systemImage: "photo", style: .info)
        case .sticker:
            return DSBadge("Sticker", systemImage: "face.smiling", style: .info)
        case .audio:
            return DSBadge("Audio", systemImage: "waveform", style: .info)
        case .unknown:
            return DSBadge("Unknown", systemImage: "questionmark.circle", style: .warning)
        }
    }

    @ViewBuilder
    private var imageMessageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            mediaPreviewOrPlaceholder(placeholder: "[Image]")

            if let trimmedMessageText {
                Text(trimmedMessageText)
            }
        }
    }

    @ViewBuilder
    private func mediaPreviewOrPlaceholder(placeholder: String) -> some View {
        if let image = firstLocalMediaImage() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 240, maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(placeholder)
        }
    }

    private func firstLocalMediaImage() -> NSImage? {
        guard let firstPath = message.localMediaPaths.first else { return nil }
        let absoluteURL = ChatMediaStorage.absoluteURL(forRelativePath: firstPath)
        return NSImage(contentsOf: absoluteURL)
    }
}

private enum MessageRole {
    case assistant
    case manualOutgoing
    case client
}
