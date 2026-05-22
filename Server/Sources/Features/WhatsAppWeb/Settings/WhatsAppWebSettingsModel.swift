import Combine
import Foundation

@MainActor
final class WhatsAppWebSettingsModel: ObservableObject {
    static let defaultCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"
    static let defaultInspectable = true
    static let defaultMessageSettleDelayMilliseconds = 800.0
    static let defaultPageZoom = 0.85

    @Published var customUserAgent: String
    @Published var isInspectable: Bool
    @Published var messageSettleDelayMilliseconds: Double
    @Published var pageZoom: Double

    private let repository: WhatsAppWebSettingsRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        loadPersistedValues: Bool = true,
        repository: WhatsAppWebSettingsRepository = .shared
    ) {
        self.repository = repository
        customUserAgent = Self.defaultCustomUserAgent
        isInspectable = Self.defaultInspectable
        messageSettleDelayMilliseconds = Self.defaultMessageSettleDelayMilliseconds
        pageZoom = Self.defaultPageZoom

        guard loadPersistedValues else { return }
        loadStoredValue()
        bindPersistence()
    }

    var effectiveCustomUserAgent: String {
        let trimmedValue = customUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? Self.defaultCustomUserAgent : trimmedValue
    }

    func resetToDefault() {
        customUserAgent = Self.defaultCustomUserAgent
        isInspectable = Self.defaultInspectable
        messageSettleDelayMilliseconds = Self.defaultMessageSettleDelayMilliseconds
        pageZoom = Self.defaultPageZoom
    }

    private func loadStoredValue() {
        customUserAgent = repository.loadCustomUserAgent(defaultValue: Self.defaultCustomUserAgent)
        isInspectable = repository.loadInspectable(defaultValue: Self.defaultInspectable)
        messageSettleDelayMilliseconds = repository.loadMessageSettleDelay(defaultValue: Self.defaultMessageSettleDelayMilliseconds)
        pageZoom = repository.loadPageZoom(defaultValue: Self.defaultPageZoom)
    }

    private func bindPersistence() {
        $customUserAgent
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistStoredValue()
            }
            .store(in: &cancellables)

        $isInspectable
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistStoredValue()
            }
            .store(in: &cancellables)

        $messageSettleDelayMilliseconds
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistStoredValue()
            }
            .store(in: &cancellables)

        $pageZoom
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistStoredValue()
            }
            .store(in: &cancellables)
    }

    private func persistStoredValue() {
        repository.saveCustomUserAgent(effectiveCustomUserAgent)
        repository.saveInspectable(isInspectable)
        repository.saveMessageSettleDelay(messageSettleDelayMilliseconds)
        repository.savePageZoom(pageZoom)
    }
}
