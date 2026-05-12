import SwiftUI

struct StatusBadge: View {
    let title: String
    let isOnline: Bool
    let subtitle: String?
    let help: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
        .help(help ?? "")
    }
}

