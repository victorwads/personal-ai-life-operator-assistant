import Foundation

@MainActor
final class ClientVoicePresenceService: ObservableObject {
    @Published private(set) var isPresent = false

    private let repository: ClientVoicePresenceRepository
    private var listenerToken: RealtimeDatabaseListenerToken?
    private var isObserving = false

    init(repository: ClientVoicePresenceRepository) {
        self.repository = repository
    }

    func start() async {
        guard !isObserving else { return }

        isObserving = true
        listenerToken = repository.observePresence { [weak self] isPresent in
            Task { @MainActor in
                guard let self, self.isObserving else { return }
                self.isPresent = isPresent
            }
        }
    }

    func stop() async {
        guard isObserving else { return }

        isObserving = false
        listenerToken?.cancel()
        listenerToken = nil
    }

    func setPresent() async throws {
        try await setPresence(true)
    }

    func setAbsent() async throws {
        try await setPresence(false)
    }

    func setPresence(_ isPresent: Bool) async throws {
        try await repository.setPresence(isPresent)
        self.isPresent = isPresent
    }
}
