import Foundation

@MainActor
struct ClientVoiceWorkerStatusProvider: ProfileRuntimeStatusProvider {
    let workerService: any ProfileRuntimeService

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let actionTitle = ProfileRuntimeServiceStatusFormatting.actionTitle(for: workerService.state)

        return [
            ProfileRuntimeStatusItem(
                id: "client.voice.worker",
                title: "Voice Worker",
                stateLabel: ProfileRuntimeServiceStatusFormatting.stateLabel(for: workerService.state),
                detail: ProfileRuntimeServiceStatusFormatting.detail(for: workerService.state),
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
        switch workerService.state {
        case .stopped, .failed:
            await workerService.start()
        case .running, .starting:
            await workerService.stop()
        case .stopping:
            break
        }
    }
}
