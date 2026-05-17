import SwiftUI

enum StatusBadgeState {
    case online
    case offline
    case paused

    var indicatorColor: Color {
        switch self {
        case .online:
            return .green
        case .offline:
            return .red
        case .paused:
            return .yellow
        }
    }

    var backgroundColor: Color {
        switch self {
        case .paused:
            return Color.yellow.opacity(0.14)
        case .online, .offline:
            return Color(nsColor: .controlBackgroundColor)
        }
    }
}

struct StatusBadge: View {
    let title: String
    let state: StatusBadgeState
    let help: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.indicatorColor)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(state.backgroundColor)
        .clipShape(Capsule())
        .help(help ?? "")
    }
}

struct SpeechStatusBadge: View {
    let isSpeaking: Bool
    let onStop: () -> Void

    var body: some View {
        if isSpeaking {
            Button(action: onStop) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.caption.weight(.semibold))

                    Text("Stop speaking")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Stop the current speech")
        }
    }
}

#Preview("Online") {
    StatusBadge(title: "OK", state: .online, help: "All good")
        .padding()
}

#Preview("Offline") {
    StatusBadge(title: "Microphone", state: .offline, help: "Click to open settings")
        .padding()
}

#Preview("Paused") {
    StatusBadge(title: "WhatsApp paused", state: .paused, help: "Polling is paused")
        .padding()
}

#Preview("Speaking") {
    SpeechStatusBadge(isSpeaking: true, onStop: {})
        .padding()
}
