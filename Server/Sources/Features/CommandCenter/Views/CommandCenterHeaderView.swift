import SwiftUI

struct CommandCenterHeaderView: View {
    let profile: Profile
    let runtimeState: ProfileRuntimeState
    let windowState: ProfileWindowState
    let statusRegistry: ProfileRuntimeStatusRegistry?

    @State private var refreshID = UUID()
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideHeader
            compactHeader
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.background)
        .onReceive(refreshTimer) { _ in
            refreshID = UUID()
        }
    }

    private var wideHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            profileTitleBlock
                .layoutPriority(2)
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            runtimeBadgesBlock
                .layoutPriority(0)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            profileTitleBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            runtimeBadgesBlock
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var profileTitleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("Profile workspace")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var runtimeBadgesBlock: some View {
        DSFlowLayout(alignment: .trailing, spacing: 6, rowSpacing: 6) {
            ForEach(statusRegistry?.items ?? []) { item in
                statusItemView(item)
            }
        }
        .id(refreshID)
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
