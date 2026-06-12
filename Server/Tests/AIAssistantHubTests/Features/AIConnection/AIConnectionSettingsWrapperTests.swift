import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionSettingsWrapperTests: XCTestCase {
    func testImageExtractionProviderDefaultsToAssistantProviderValues() {
        let repository = InMemoryAIConnectionSettingsRepository()
        let settings = SettingsStore(profileId: "profile-1", repository: repository)
        let wrapper = AIConnectionSettingsWrapper(settings: settings)

        wrapper.providerKind = .lmStudio
        wrapper.baseURL = "http://localhost:1234/v1/chat/completions"
        wrapper.apiKey = "assistant-secret"
        wrapper.model = "assistant-model"
        wrapper.cacheMode = .disabled

        XCTAssertEqual(wrapper.imageExtractionProviderKind, .lmStudio)
        XCTAssertEqual(wrapper.imageExtractionBaseURL, "http://localhost:1234/v1/chat/completions")
        XCTAssertEqual(wrapper.imageExtractionAPIKey, "assistant-secret")
        XCTAssertEqual(wrapper.imageExtractionModel, "assistant-model")
        XCTAssertEqual(wrapper.imageExtractionCacheMode, .disabled)
        XCTAssertEqual(wrapper.assistantReasoningEffort, .omit)
        XCTAssertEqual(wrapper.imageExtractionReasoningEffort, .omit)
    }

    func testImageExtractionProviderCanOverrideAssistantProviderIndependently() {
        let repository = InMemoryAIConnectionSettingsRepository()
        let settings = SettingsStore(profileId: "profile-1", repository: repository)
        let wrapper = AIConnectionSettingsWrapper(settings: settings)

        wrapper.providerKind = .openRouter
        wrapper.baseURL = "https://openrouter.ai/api/v1/chat/completions"
        wrapper.apiKey = "assistant-secret"
        wrapper.model = "assistant-model"
        wrapper.cacheMode = .automatic

        wrapper.imageExtractionProviderKind = .lmStudio
        wrapper.imageExtractionBaseURL = "http://localhost:1234/v1/chat/completions"
        wrapper.imageExtractionAPIKey = "image-secret"
        wrapper.imageExtractionModel = "image-model"
        wrapper.imageExtractionCacheMode = .disabled

        XCTAssertEqual(wrapper.providerKind, .openRouter)
        XCTAssertEqual(wrapper.baseURL, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(wrapper.apiKey, "assistant-secret")
        XCTAssertEqual(wrapper.model, "assistant-model")
        XCTAssertEqual(wrapper.cacheMode, .automatic)

        XCTAssertEqual(wrapper.imageExtractionProviderKind, .lmStudio)
        XCTAssertEqual(wrapper.imageExtractionBaseURL, "http://localhost:1234/v1/chat/completions")
        XCTAssertEqual(wrapper.imageExtractionAPIKey, "image-secret")
        XCTAssertEqual(wrapper.imageExtractionModel, "image-model")
        XCTAssertEqual(wrapper.imageExtractionCacheMode, .disabled)
    }

    func testAssistantReasoningFallsBackToLegacySharedSetting() {
        let repository = InMemoryAIConnectionSettingsRepository()
        let settings = SettingsStore(profileId: "profile-1", repository: repository)
        settings.setValue(scope: "aiConnection", key: "reasoningEffort", value: AIConnectionReasoningEffort.high.rawValue)

        let wrapper = AIConnectionSettingsWrapper(settings: settings)

        XCTAssertEqual(wrapper.assistantReasoningEffort, .high)
        XCTAssertEqual(wrapper.imageExtractionReasoningEffort, .omit)
    }

    func testReasoningCanBeConfiguredSeparatelyPerProvider() {
        let repository = InMemoryAIConnectionSettingsRepository()
        let settings = SettingsStore(profileId: "profile-1", repository: repository)
        let wrapper = AIConnectionSettingsWrapper(settings: settings)

        wrapper.assistantReasoningEffort = .enabled
        wrapper.imageExtractionReasoningEffort = .qwenOff

        XCTAssertEqual(wrapper.assistantProviderConfiguration.reasoningEffort, .enabled)
        XCTAssertEqual(wrapper.imageExtractionProviderConfiguration.reasoningEffort, .qwenOff)
    }
}

@MainActor
private final class InMemoryAIConnectionSettingsRepository: SettingsRepository {
    private var documents: [String: [String: String]] = [:]

    func loadAllScopes() async throws -> [SettingsDocument] {
        documents.map { SettingsDocument(scopeName: $0.key, values: $0.value) }
    }

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        SettingsDocument(scopeName: scopeName, values: documents[scopeName] ?? [:])
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        documents[scopeName] = values
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        documents[scopeName]?[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        var values = documents[scopeName] ?? [:]
        values[key] = value
        documents[scopeName] = values
    }

    func deleteValue(scopeName: String, key: String) async throws {
        var values = documents[scopeName] ?? [:]
        values.removeValue(forKey: key)
        documents[scopeName] = values
    }

    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        listener(SettingsDocument(scopeName: scopeName, values: documents[scopeName] ?? [:]))
        return FirestoreListenerToken {}
    }

    func observeAllScopes(_ onChange: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        onChange(documents.map { SettingsDocument(scopeName: $0.key, values: $0.value) })
        return FirestoreListenerToken {}
    }
}
