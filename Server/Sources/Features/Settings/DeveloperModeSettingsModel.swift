import Combine
import Foundation

@MainActor
final class DeveloperModeSettingsModel: ObservableObject {
    @Published var isEnabled: Bool

    private let repository: DeveloperModeSettingsRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        loadPersistedValues: Bool = true,
        repository: DeveloperModeSettingsRepository
    ) {
        self.repository = repository
        isEnabled = false

        guard loadPersistedValues else { return }
        loadStoredValue()
        bindPersistence()
    }

    private func loadStoredValue() {
        isEnabled = repository.load()
    }

    private func bindPersistence() {
        $isEnabled
            .dropFirst()
            .sink { [weak self] value in
                self?.repository.save(value)
            }
            .store(in: &cancellables)
    }
}

