import SwiftUI

struct MessageRow: View {
    let message: Message
    let onMarkAsUnhandled: (() -> Void)?
    let onMarkAsUnhandledAndFollowing: (() -> Void)?
    let onMarkAsHandled: (() -> Void)?
    let onMarkAsHandledAndFollowing: (() -> Void)?

    var body: some View {
        HStack {
            if isOutgoingBubble {
                Spacer(minLength: 40)
            }

            bubbleContent
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)

            if !isOutgoingBubble {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusChip: some View {
        HStack(spacing: 4) {
            Image(systemName: message.isHandled ? "checkmark.circle.fill" : "clock.fill")
                .font(.caption2.weight(.semibold))
            Text(message.isHandled ? "handled" : "pending")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(message.isHandled ? Color.secondary : Color.orange)
        .help("pending = the assistant has not marked this incoming message as read/handled yet. handled = already consumed by a wait/tool or manually marked.")
    }

    private var shouldShowMarkUnhandledMenu: Bool {
        message.direction == .incoming && message.isHandled
    }

    private var shouldShowMarkHandledMenu: Bool {
        message.direction == .incoming && !message.isHandled
    }

    private var authorLabel: String {
        switch message.direction {
        case .incoming:
            return message.authorName ?? "Incoming (author unknown)"
        case .outgoing:
            return "You"
        case .unknown:
            return "Unknown (direction)"
        }
    }

    private var authorHelp: String {
        switch message.direction {
        case .incoming:
            if let author = message.authorName, !author.isEmpty {
                return "Parsed author name: \(author)"
            }
            return "Incoming message, but author name was not found (common in 1:1 chats or when DOM selectors miss group headers)."
        case .outgoing:
            return "Outgoing message from this device/account."
        case .unknown:
            return "Direction could not be inferred from the DOM snapshot."
        }
    }

    private var timestampLabel: String? {
        if let timestamp = message.timestamp {
            return timestamp.formatted(date: .abbreviated, time: .shortened)
        }

        return message.whatsappTimestampText
    }

    @ViewBuilder
    private var originChip: some View {
        let label: String = {
            switch message.origin {
            case .assistant: "assistant"
            case .human: "human"
            case .unknown: "unknown"
            }
        }()

        HStack(spacing: 4) {
            Image(systemName: originIcon)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(originColor)
        .help("Origin only applies to outgoing messages. assistant = sent by MCP tool; human = typed by you; unknown = not inferred.")
    }

    private var backgroundColor: Color {
        if message.direction == .incoming && !message.isHandled {
            return .orange.opacity(0.12)
        }

        if message.direction == .outgoing {
            return .green.opacity(0.14)
        }

        if message.direction == .incoming {
            return .blue.opacity(0.10)
        }

        return Color(nsColor: .controlBackgroundColor)
    }

    private var isOutgoingBubble: Bool {
        message.direction == .outgoing
    }

    private var bubbleMaxWidth: CGFloat {
        520
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: headerIcon)
                        .font(.caption.weight(.semibold))

                    Text(authorLabel)
                        .font(.caption.weight(.semibold))
                        .help(authorHelp)
                }
                .foregroundStyle(message.direction == .incoming ? .secondary : .primary)

                Spacer()

                if let timestampLabel {
                    Text(timestampLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(message.text ?? message.rawAccessibilityText)
                .font(.body)
                .textSelection(.enabled)

            HStack(alignment: .bottom, spacing: 10) {
                HStack(spacing: 6) {
                    labeledChip(title: message.kind.rawValue, systemImage: kindIcon)
                        .help("Message kind (text/voice/image/etc). For WhatsApp Web we currently map most items as text.")

                    labeledChip(title: message.status.rawValue, systemImage: statusIcon)
                        .help("Delivery status (sent/delivered/read). WhatsApp Web parsing still treats most as unknown.")

                    statusChip

                    if message.direction == .outgoing {
                        originChip
                    }
                }

                Spacer()

                if shouldShowMarkUnhandledMenu {
                    Menu("Desler") {
                        Button("Desler so esta") {
                            onMarkAsUnhandled?()
                        }

                        Button("Desler esta e seguintes") {
                            onMarkAsUnhandledAndFollowing?()
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .help("Recoloca esta mensagem, ou ela e as seguintes, na fila dos waits do assistente.")
                }

                if shouldShowMarkHandledMenu {
                    Menu("Mark as read") {
                        Button("Mark this as read") {
                            onMarkAsHandled?()
                        }

                        Button("Mark this and following as read") {
                            onMarkAsHandledAndFollowing?()
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .help("Marks this message, or this message and the following ones, as read by the assistant.")
                }
            }
        }
        .padding(12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor)
        )
    }

    private func labeledChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    private var headerIcon: String {
        switch message.direction {
        case .incoming:
            return "person.crop.circle.fill"
        case .outgoing:
            return "person.crop.circle.badge.checkmark"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var kindIcon: String {
        switch message.kind {
        case .text:
            return "text.justify"
        case .voice:
            return "waveform"
        case .image:
            return "photo"
        case .document:
            return "doc"
        case .deleted:
            return "trash"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusIcon: String {
        switch message.status {
        case .sent:
            return "paperplane"
        case .delivered:
            return "tray.and.arrow.down"
        case .read:
            return "checkmark.seal"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var originIcon: String {
        switch message.origin {
        case .assistant:
            return "gearshape.2.fill"
        case .human:
            return "person.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var originColor: Color {
        switch message.origin {
        case .assistant:
            return .blue
        case .human:
            return .secondary
        case .unknown:
            return .secondary
        }
    }

    private var borderColor: Color {
        if message.direction == .incoming && !message.isHandled {
            return .orange.opacity(0.30)
        }

        if message.direction == .outgoing {
            return .green.opacity(0.28)
        }

        if message.direction == .incoming {
            return .blue.opacity(0.22)
        }

        return .secondary.opacity(0.18)
    }
}

#Preview {
    MessageRow(
        message: Message(
            id: "m-preview",
            chatId: "chat-preview",
            direction: .incoming,
            kind: .text,
            authorName: "Leonardo Eloy",
            origin: .unknown,
            text: "Olá! Isso é um preview.",
            durationSeconds: nil,
            timestamp: Date(),
            status: .delivered,
            rawAccessibilityText: "Olá! Isso é um preview."
        ),
        onMarkAsUnhandled: {},
        onMarkAsUnhandledAndFollowing: {},
        onMarkAsHandled: {},
        onMarkAsHandledAndFollowing: {}
    )
    .padding()
    .frame(width: 420)
}
