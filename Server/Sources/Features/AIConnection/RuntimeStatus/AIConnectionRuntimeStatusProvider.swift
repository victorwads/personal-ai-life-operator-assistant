import Foundation

@MainActor
struct AIConnectionRuntimeStatusProvider: ProfileRuntimeStatusProvider {
    let runtimeService: AIConnectionRuntimeService

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let actionTitle: String?
        switch runtimeService.state.status {
        case .initializing, .promptProcessing, .reasoning, .executingTool, .receivingOutput, .waitingUser, .waitingEvent:
            actionTitle = "Stop"
        case .stopped, .paused, .completed, .failed, .cancelled:
            actionTitle = "Start"
        }

        return [
            ProfileRuntimeStatusItem(
                id: "ai.connection.status",
                title: "AI Connection",
                stateLabel: stateLabel(for: runtimeService.state.status),
                detail: runtimeService.state.status.displayName,
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
        switch runtimeService.state.status {
        case .initializing, .promptProcessing, .reasoning, .executingTool, .receivingOutput, .waitingUser, .waitingEvent:
            runtimeService.cancelRun()
        case .stopped, .paused, .completed, .failed, .cancelled:
            runtimeService.startRun(userPrompt: "start your job")
        }
    }

    private func stateLabel(for status: AIConnectionRuntimeStatus) -> String {
        switch status {
        case .initializing, .promptProcessing:
            return "Starting"
        case .reasoning, .executingTool, .receivingOutput, .waitingUser, .waitingEvent:
            return "Running"
        case .failed:
            return "Failed"
        case .stopped, .paused, .completed, .cancelled:
            return "Stopped"
        }
    }
}
