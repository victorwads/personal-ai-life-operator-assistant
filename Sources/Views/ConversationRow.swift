import SwiftUI

struct ConversationRow: View {
    let conversation: ConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(conversation.name)
                    .font(.headline)
                    .lineLimit(1)

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.green))
                }

                Spacer()

                if let lastMessageAtText = conversation.lastMessageAtText {
                    Text(lastMessageAtText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                if conversation.lastMessageDirection == .outgoing {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }

                Text(conversation.isTyping ? "typing..." : conversation.lastMessagePreview ?? "No preview")
                    .font(.caption)
                    .foregroundStyle(conversation.isTyping ? .green : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch conversation.lastMessageStatus {
        case .read: "checkmark.circle.fill"
        case .delivered: "checkmark.circle"
        case .sent: "checkmark"
        case .unknown: "arrowshape.turn.up.right"
        }
    }

    private var statusColor: Color {
        conversation.lastMessageStatus == .read ? .blue : .secondary
    }
}

#Preview {
    ConversationRow(
        conversation: ConversationSummary(
            id: "chat-preview",
            accessibilityPath: [0, 1],
            name: "Family",
            unreadCount: 3,
            isPinned: true,
            isSelected: false,
            lastMessagePreview: "Chego em 10 minutos.",
            lastMessageAtText: "09:41",
            lastMessageDirection: .outgoing,
            lastMessageStatus: .read,
            isTyping: false
        )
    )
    .padding()
    .frame(width: 420)
}
