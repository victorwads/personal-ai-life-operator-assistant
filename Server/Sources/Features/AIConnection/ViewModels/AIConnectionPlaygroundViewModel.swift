import Combine
import Foundation

@MainActor
final class AIConnectionPlaygroundViewModel: ObservableObject {
    @Published private(set) var runtimeState: AIConnectionRuntimeState
    @Published private(set) var logsFolderPath: String
    @Published private(set) var logsFolderError: String?

    private let runtimeService: AIConnectionRuntimeService
    private let errorLogStore: AIConnectionErrorLogStore
    private var cancellables: Set<AnyCancellable> = []

    init(feature: AIConnectionFeature) {
        errorLogStore = feature.errorLogStore
        runtimeService = feature.runtimeService
        runtimeState = feature.runtimeService.state
        logsFolderPath = feature.errorLogStore.logsFolderPath()

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
        AIRunPromptState(sections: runtimeState.promptSections)
    }

    func loadTools() async {
        await runtimeService.loadTools()
    }

    func startJob() {
        runtimeService.startRun()
    }

    func cancelRun() {
        runtimeService.cancelRun()
    }

    func resetRun() {
        runtimeService.resetRun()
    }

    func openLogsFolder() {
        do {
            try errorLogStore.openLogsFolder()
            logsFolderError = nil
        } catch {
            logsFolderError = error.localizedDescription
        }
    }
}
