import Foundation

@MainActor
struct MCPServerRuntimeStatusProvider: ProfileRuntimeStatusProvider {
    let service: any ProfileRuntimeService
    let port: Int

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let actionTitle = ProfileRuntimeServiceStatusFormatting.actionTitle(for: service.state)
        return [
            ProfileRuntimeStatusItem(
                id: "mcp.server.status",
                title: "MCP Server",
                stateLabel: ProfileRuntimeServiceStatusFormatting.stateLabel(for: service.state),
                detail: ProfileRuntimeServiceStatusFormatting.detail(for: service.state, fallback: "Port \(port)"),
                actionTitle: actionTitle,
                action: actionTitle.map { _ in
                    {
                        await performAction()
                    }
                }
            )
        ]
    }

    private func performAction() async {
        switch service.state {
        case .stopped, .failed:
            await service.start()
        case .running, .starting:
            await service.stop()
        case .stopping:
            break
        }
    }
}
