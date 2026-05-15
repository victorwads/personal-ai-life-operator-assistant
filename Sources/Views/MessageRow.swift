import SwiftUI

struct MessageRow: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(message.direction.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(message.kind.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(message.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(message.text ?? message.rawAccessibilityText)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    MessageRow(
        message: Message(
            id: "m-preview",
            chatId: "chat-preview",
            direction: .incoming,
            kind: .text,
            text: "Olá! Isso é um preview.",
            durationSeconds: nil,
            timestamp: Date(),
            status: .delivered,
            rawAccessibilityText: "Olá! Isso é um preview."
        )
    )
    .padding()
    .frame(width: 420)
}
