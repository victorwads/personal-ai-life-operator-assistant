import SwiftUI

struct ProfileStatusBadgeView: View {
    let runtimeState: ProfileRuntimeState

    var body: some View {
        Text(runtimeState.rawValue.uppercased())
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.16))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch runtimeState {
        case .stopped: return .secondary
        case .starting: return .orange
        case .running: return .green
        case .stopping: return .orange
        case .failed: return .red
        }
    }
}

