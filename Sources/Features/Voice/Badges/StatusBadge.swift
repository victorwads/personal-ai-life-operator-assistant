import SwiftUI

struct StatusBadge: View {
    let title: String
    let isOnline: Bool
    let help: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
        .help(help ?? "")
    }
}

#Preview("Online") {
    StatusBadge(title: "OK", isOnline: true, help: "All good")
        .padding()
}

#Preview("Offline") {
    StatusBadge(title: "Microphone", isOnline: false, help: "Click to open settings")
        .padding()
}
