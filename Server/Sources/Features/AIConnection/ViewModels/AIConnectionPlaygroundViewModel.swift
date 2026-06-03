import Combine
import Foundation

@MainActor
final class AIConnectionPlaygroundViewModel: ObservableObject {
    @Published var prompt = "start your job"
    @Published private(set) var runtimeState: AIConnectionRuntimeState

    private let runtimeService: AIConnectionRuntimeService
    private var cancellables: Set<AnyCancellable> = []

    init(feature: AIConnectionFeature) {
        runtimeService = feature.runtimeService
        runtimeState = feature.runtimeService.state

        runtimeService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.runtimeState = $0
            }
            .store(in: &cancellables)
    }

    var isLoadingTools: Bool { runtimeState.isLoadingTools }
    var canStart: Bool { runtimeState.canStart }
    var canCancel: Bool { runtimeState.canCancel }
    var canReset: Bool { runtimeState.canReset }

    var promptState: AIRunPromptState {
        AIRunPromptState(systemPrompt: runtimeState.systemPrompt, userPrompt: runtimeState.userPrompt)
    }

    func loadTools() async {
        await runtimeService.loadTools()
    }

    func startJob() {
        runtimeService.startRun(userPrompt: normalizedPrompt)
    }

    func cancelRun() {
        runtimeService.cancelRun()
    }

    func resetRun() {
        runtimeService.resetRun()
    }

    private var normalizedPrompt: String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "start your job" : trimmed
    }
}
