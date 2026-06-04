import XCTest
@testable import AIAssistantHub

@MainActor
final class ClientVoiceSettingsWrapperTests: XCTestCase {
    func testSpeechRecognitionLanguageDefaultsToSystem() {
        let wrapper = ClientVoiceSettingsWrapper(
            settings: SettingsStore(
                profileId: "profile-1",
                repository: InMemoryClientVoiceSettingsRepository()
            )
        )

        XCTAssertEqual(wrapper.speechRecognitionLanguage, .systemDefault)
        XCTAssertEqual(wrapper.speechRecognitionListenConfig.language, "auto")
        XCTAssertEqual(wrapper.speechRecognitionDebounceFinalMs, 1_200)
        XCTAssertEqual(wrapper.speechRecognitionListenConfig.debounceFinalMs, 1_200)
    }

    func testSpeechRecognitionLanguagePersistsSelectedValue() {
        let wrapper = ClientVoiceSettingsWrapper(
            settings: SettingsStore(
                profileId: "profile-1",
                repository: InMemoryClientVoiceSettingsRepository()
            )
        )

        wrapper.speechRecognitionLanguage = .brazilianPortuguese

        XCTAssertEqual(wrapper.speechRecognitionLanguage, .brazilianPortuguese)
        XCTAssertEqual(wrapper.speechRecognitionListenConfig.language, "pt-BR")
    }

    func testSpeechRecognitionDebouncePersistsSelectedValue() {
        let wrapper = ClientVoiceSettingsWrapper(
            settings: SettingsStore(
                profileId: "profile-1",
                repository: InMemoryClientVoiceSettingsRepository()
            )
        )

        wrapper.speechRecognitionDebounceFinalMs = 2_300

        XCTAssertEqual(wrapper.speechRecognitionDebounceFinalMs, 2_300)
        XCTAssertEqual(wrapper.speechRecognitionListenConfig.debounceFinalMs, 2_300)
    }
}

private final class InMemoryClientVoiceSettingsRepository: SettingsRepository {
    private var documents: [String: SettingsDocument] = [:]

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        documents[scopeName] ?? SettingsDocument(scopeName: scopeName, values: [:])
    }

    func loadAllScopes() async throws -> [SettingsDocument] {
        Array(documents.values)
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        documents[scopeName]?.values[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        var values = documents[scopeName]?.values ?? [:]
        values[key] = value
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func deleteValue(scopeName: String, key: String) async throws {
        var values = documents[scopeName]?.values ?? [:]
        values.removeValue(forKey: key)
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }

    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }
}
