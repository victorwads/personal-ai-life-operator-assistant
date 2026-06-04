import SwiftUI

struct CommandCenterHeaderView: View {
    let profile: Profile
    let runtimeState: ProfileRuntimeState
    let windowState: ProfileWindowState
    let statusRegistry: ProfileRuntimeStatusRegistry?

    @State private var refreshID = UUID()
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                Text("Profile workspace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(statusRegistry?.items ?? []) { item in
                    statusItemView(item)
                }
            }
            .id(refreshID)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.background)
        .onReceive(refreshTimer) { _ in
            refreshID = UUID()
        }
    }

    private func statusItemView(_ item: ProfileRuntimeStatusItem) -> some View {
        let actionTitle = actionTitleToRender(for: item)
        return DSRuntimeStatusBadge(
            title: item.title,
            secondaryText: item.detail,
            state: DSRuntimeStatusBadge.State(statusLabel: item.stateLabel),
            trailingSystemImage: actionTitle.map(iconName(for:)),
            trailingActionLabel: actionTitle.map { "\($0) \(item.title)" },
            trailingAction: actionTitle.flatMap { _ in
                guard let action = item.action else { return nil }
                return {
                    Task { @MainActor in
                        await action()
                        refreshID = UUID()
                    }
                }
            }
        )
    }

    private func actionTitleToRender(for item: ProfileRuntimeStatusItem) -> String? {
        switch item.stateLabel.lowercased() {
        case "starting", "stopping":
            return nil
        default:
            return item.actionTitle
        }
    }

    // TODO: set on ProfileRuntimeStatusItem
    private func iconName(for actionTitle: String) -> String {
        switch actionTitle {
        case "Set Present", "Start", "Play":
            return "play.fill"
        case "Pause":
            return "pause.fill"
        case "Set Absent", "Stop":
            return "stop.fill"
        default:
            return "questionmark"
        }
    }
}
