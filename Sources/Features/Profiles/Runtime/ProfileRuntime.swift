import Foundation

@MainActor
final class ProfileRuntime: ObservableObject {
    let context: ProfileContext

    @Published private(set) var state: ProfileRuntimeState = .stopped
    @Published private(set) var windowState: ProfileWindowState = .hidden

    private(set) var container: ProfileRuntimeContainer?

    init(context: ProfileContext) {
        self.context = context
    }

    func start() async throws {
        guard state == .stopped || state == .failed else { return }
        state = .starting

        do {
            let container = try ProfileRuntimeContainer(context: context)
            try await container.start()
            self.container = container
            state = .running
        } catch {
            await container?.stop()
            container = nil
            state = .failed
            throw error
        }
    }

    func stop() async {
        guard state == .running || state == .starting else { return }
        state = .stopping

        await container?.stop()
        container = nil

        state = .stopped
        windowState = .hidden
    }

    func setWindowState(_ newState: ProfileWindowState) {
        windowState = newState
    }
}
