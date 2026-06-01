import SwiftUI

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
                kindBadge

                if message.handled {
                    DSBadge("Handled", systemImage: "checkmark.circle", style: .success)
                } else {
                    DSBadge("Unhandled", systemImage: "clock.badge.exclamationmark", style: .warning)
                }

                Spacer(minLength: 8)

                DSCodableDebugInspector(title: "Message JSON", value: message)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.kind {
        case .text:
            Text(message.text ?? "(empty text message)")
        case .image:
            Label(message.text ?? "Image message", systemImage: "photo")
        case .sticker:
            Label(message.text ?? "Sticker message", systemImage: "face.smiling")
        case .audio:
            Label(message.text ?? "Audio message", systemImage: "waveform")
        case .unknown:
            Label(message.text ?? "Unsupported message payload", systemImage: "questionmark.circle")
        }
    }

    private var alignment: DSMessageBubbleAlignment {
        message.direction == .sent ? .trailing : .leading
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
}
