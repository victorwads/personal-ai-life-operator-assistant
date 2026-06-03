import SwiftUI

struct SentMessageRowView: View {
    let sentMessage: SentMessage
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        DSListCardRow(
            title: sentMessage.chatTitle ?? sentMessage.chatId,
            subtitle: "Issue: \(sentMessage.issueId) • Chat: \(sentMessage.chatId)",
            description: messagesPreview,
            systemImage: "paperplane"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DSBadge(
                        "Status",
                        secondaryText: sentMessage.status.rawValue,
                        style: statusBadgeStyle
                    )

                    DSBadge(
                        "Observed IDs",
                        secondaryText: "\(sentMessage.chatMessageIds.count)",
                        style: .info
                    )

                    if let sentAtText {
                        DSBadge(
                            "Sent At",
                            secondaryText: sentAtText,
                            style: .neutral
                        )
                    }
                }

                messageBubbles

                if !sentMessage.chatMessageIds.isEmpty {
                    Text("Chat Message IDs: \(sentMessage.chatMessageIds.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = sentMessage.errorMessage,
                   !errorMessage.isEmpty {
                    Text("Error: \(errorMessage)")
                        .font(.caption)
                        .foregroundStyle(sentMessage.status == .failed ? .red : .secondary)
                }
            }
        }
    }

    private var messagesPreview: String {
        guard !sentMessage.messages.isEmpty else {
            return "No outbound message content."
        }

        return sentMessage.messages.joined(separator: " ")
    }

    @ViewBuilder
    private var messageBubbles: some View {
        if !sentMessage.messages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(sentMessage.messages.enumerated()), id: \.offset) { index, message in
                    DSMessageBubbleRow(
                        alignment: .trailing,
                        title: "Outbound \(index + 1)",
                        subtitle: sentMessage.chatTitle ?? sentMessage.chatId
                    ) {
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var sentAtText: String? {
        guard let sentAt = sentMessage.sentAt else {
            return nil
        }

        return dateFormatter.string(from: sentAt)
    }

    private var statusBadgeStyle: DSBadge.Style {
        switch sentMessage.status {
        case .pending:
            return .warning
        case .sent:
            return .success
        case .failed:
            return .danger
        case .partiallySent:
            return .info
        }
    }
}
