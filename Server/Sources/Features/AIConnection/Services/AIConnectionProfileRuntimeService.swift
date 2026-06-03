import Foundation

@MainActor
final class AIConnectionProfileRuntimeService: ProfileRuntimeService {
    let id: String
    let title: String

    private let runtimeService: AIConnectionRuntimeService

    init(
        id: String,
        title: String,
        runtimeService: AIConnectionRuntimeService
    ) {
        self.id = id
        self.title = title
        self.runtimeService = runtimeService
    }

    var state: ProfileRuntimeServiceState {
        switch runtimeService.state.status {
        case .stopped, .completed, .cancelled:
            return .stopped
        case .initializing, .promptProcessing:
            return .starting
        case .reasoning, .executingTool, .receivingOutput, .cycleCompleted, .recovering, .waitingUser, .waitingEvent:
            return .running
        case .paused:
            return .stopping
        case .failed:
            return .failed(runtimeService.state.errors.last ?? "AI Connection failed.")
        }
    }

    func start() async {
        guard canStart else { return }
        runtimeService.startRun(userPrompt: "start your job")
    }

    func stop() async {
        guard canStop else { return }
        runtimeService.cancelRun()
    }

    private var canStart: Bool {
        switch state {
        case .stopped, .failed:
            return true
        case .starting, .running, .stopping:
            return false
        }
    }

    private var canStop: Bool {
        switch state {
        case .starting, .running:
            return true
        case .stopped, .stopping, .failed:
            return false
        }
    }
}
