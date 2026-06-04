import SwiftUI

struct DSRuntimeStatusBadge: View {
    let title: String
    let secondaryText: String?
    let state: State
    let trailingSystemImage: String?
    let trailingActionLabel: String?
    let trailingAction: (() -> Void)?

    enum State {
        case running
        case stopped
        case failed
        case starting
        case stopping
        case idle

        // TODO: set on ProfileRuntimeStatusItem
        init(statusLabel: String) {
            switch statusLabel.lowercased() {
            case "running":
                self = .running
            case "stopped":
                self = .stopped
            case "failed":
                self = .failed
            case "starting":
                self = .starting
            case "stopping":
                self = .stopping
            default:
                self = .idle
            }
        }
    }

    init(
        title: String,
        secondaryText: String? = nil,
        state: State = .idle,
        trailingSystemImage: String? = nil,
        trailingActionLabel: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.secondaryText = secondaryText
        self.state = state
        self.trailingSystemImage = trailingSystemImage
        self.trailingActionLabel = trailingActionLabel
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let secondaryText, !secondaryText.isEmpty {
                Circle()
                    .fill(.tertiary)
                    .frame(width: 3, height: 3)

                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let trailingSystemImage {
                if let trailingAction {
                    Button {
                        trailingAction()
                    } label: {
                        Image(systemName: trailingSystemImage)
                    }
                    .buttonStyle(.plain)
                    .controlSize(.mini)
                    .help(trailingActionLabel ?? title)
                } else {
                    Image(systemName: trailingSystemImage)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }

    private var stateColor: Color {
        switch state {
        case .running:
            return .green
        case .starting, .stopping:
            return .orange
        case .failed:
            return .red
        case .stopped, .idle:
            return .secondary
        }
    }
}
