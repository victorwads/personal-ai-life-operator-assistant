import Foundation

@MainActor
final class AIConnectionProfileRuntimeService: ProfileRuntimeService {
    let id: String
    let title: String

    private(set) var state: ProfileRuntimeServiceState = .stopped

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    func start() async {
        guard state == .stopped || isFailed else { return }
        state = .starting
        state = .running
    }

    func stop() async {
        guard state == .running || state == .starting || isFailed else { return }
        state = .stopping
        state = .stopped
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}
