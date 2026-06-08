import SwiftUI
import AppKit

struct ChatMessageBubbleView: View {
    let message: ChatMessage
    let isSelected: Bool
    let isSelectionModeEnabled: Bool
    let onToggleHandled: (ChatMessage) -> Void
    let onMarkThisAndOlderHandled: (ChatMessage) -> Void
    let onMarkThisAndNewerUnhandled: (ChatMessage) -> Void
    let onDeleteMessage: (ChatMessage) -> Void
    let onSelectionChange: (ChatMessage, Bool) -> Void
    let onToggleSentByAssistant: (ChatMessage) -> Void

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
                if isSelectionModeEnabled {
                    selectionCheckbox
                }

                messageRoleBadge

                kindBadge

                handledBadge

                Spacer(minLength: 8)

                DSDebugObjectsInspector(
                    title: "Message Debug",
                    items: [
                        DebugObjectItem(title: "Message", value: message)
                    ]
                )
            }
        }
        .contextMenu {
            Button("Mark this as handled") {
                if !message.handled {
                    onToggleHandled(message)
                }
            }
            .disabled(message.handled)

            Button("Mark this as unhandled") {
                if message.handled {
                    onToggleHandled(message)
                }
            }
            .disabled(!message.handled)

            Button("Mark this and older as handled") {
                onMarkThisAndOlderHandled(message)
            }
            .disabled(message.handled)

            Button("Mark this and newer as unhandled") {
                onMarkThisAndNewerUnhandled(message)
            }
            .disabled(!message.handled)

            Divider()

            Button(message.sentByAssistant == true ? "Remove assistant mark" : "Mark as assistant message") {
                onToggleSentByAssistant(message)
            }

            Divider()

            Button(role: .destructive) {
                onDeleteMessage(message)
            } label: {
                Label("Delete message", systemImage: "trash")
            }
            .disabled(message.id?.isEmpty ?? true)
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

    private var handledBadge: some View {
        Button {
            onToggleHandled(message)
        } label: {
            if message.handled {
                DSBadge("Handled", systemImage: "checkmark.circle", style: .success)
            } else {
                DSBadge("Unhandled", systemImage: "clock.badge.exclamationmark", style: .warning)
            }
        }
        .buttonStyle(.plain)
        .help(message.handled ? "Mark this message as unhandled" : "Mark this message as handled")
    }

    private var selectionCheckbox: some View {
        Button {
            onSelectionChange(message, !isSelected)
        } label: {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(isSelected ? "Deselect this message" : "Select this message")
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.kind {
        case .text:
            Text(message.text ?? "(empty text message)")
        case .image, .sticker:
            mediaMessageContent
        case .audio:
            if let audioURL = audioMediaURL {
                audioMessageContent(audioURL: audioURL)
            } else {
                Label(message.text ?? "Audio message", systemImage: "waveform")
            }
        case .video:
            Label(message.text ?? "Video message", systemImage: "video")
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

    private var audioMediaURL: URL? {
        message.localMediaPaths.first { relativePath in
            URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "ogg"
        }.map(ChatMediaStorage.absoluteURL(forRelativePath:))
    }

    private var mediaPlaceholder: String {
        switch message.kind {
        case .sticker:
            return "[Sticker]"
        case .image:
            return "[Image]"
        default:
            return "[Media]"
        }
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
        case .video:
            return DSBadge("Video", systemImage: "video", style: .info)
        case .unknown:
            return DSBadge("Unknown", systemImage: "questionmark.circle", style: .warning)
        }
    }

    @ViewBuilder
    private var mediaMessageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            mediaContentView

            if let trimmedMessageText {
                Text(trimmedMessageText)
            }
        }
    }

    @ViewBuilder
    private func audioMessageContent(audioURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AudioMessageView(audioURL: audioURL)

            if let trimmedMessageText {
                Text(trimmedMessageText)
            }
        }
    }

    @ViewBuilder
    private var mediaContentView: some View {
        let images = localMediaImages()
        if images.isEmpty {
            Text(mediaPlaceholder)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func localMediaImages() -> [NSImage] {
        message.localMediaPaths.compactMap { relativePath in
            let absoluteURL = ChatMediaStorage.absoluteURL(forRelativePath: relativePath)
            return NSImage(contentsOf: absoluteURL)
        }
    }
}

private enum MessageRole {
    case assistant
    case manualOutgoing
    case client
}
