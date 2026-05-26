import Foundation

@MainActor
final class ProfileRuntime: ObservableObject {
    let context: ProfileContext

    @Published private(set) var state: ProfileRuntimeState = .stopped
    @Published private(set) var windowState: ProfileWindowState = .hidden

    init(context: ProfileContext) {
        self.context = context
    }

    func start() async {
        guard state == .stopped || state == .failed else { return }
        state = .starting

        // Placeholder startup work; real runtime (MCP/WhatsApp/assistant) comes later.
        try? await Task.sleep(nanoseconds: 250_000_000)

        state = .running
    }

    func stop() async {
        guard state == .running || state == .starting else { return }
        state = .stopping

        try? await Task.sleep(nanoseconds: 150_000_000)

        state = .stopped
        windowState = .hidden
    }

    func setWindowState(_ newState: ProfileWindowState) {
        windowState = newState
    }
}
