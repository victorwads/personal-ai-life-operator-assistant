import XCTest
@testable import AIAssistantHub

@MainActor
final class FeatureRuntimeInitializationTests: XCTestCase {
    func testAppFeaturesInitializeAllRuntimes() {
        FirebaseAppConfigurator.configure()

        let profile = Profile(id: "profile-1", name: "Test Profile", mcpPort: 1234)
        let settings = SettingsStore(profileId: "profile-1", repository: InMemorySettingsRepository())
        let featureResolver = FeatureResolverBox()
        let context = FeatureContext(
            profileContext: ProfileContext(profile: profile),
            settings: SettingsContext(store: settings, sectionRegistry: SettingsSectionRegistry()),
            mcp: MCPContext(toolRegistry: MCPToolRegistry()),
            services: FeatureServicesContext(serviceRegistry: ProfileRuntimeServiceRegistry()),
            status: FeatureStatusContext(statusRegistry: ProfileRuntimeStatusRegistry()),
            featureWindows: FeatureWindowsContext(show: { _ in }, hide: { _ in }),
            sharedLocks: SharedLockRegistry(),
            featureResolver: featureResolver
        )

        let appFeatures = AppFeatures(context: context)
        featureResolver.appFeatures = appFeatures

        XCTAssertEqual(appFeatures.all.count, 12)
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    func loadAllScopes() async throws -> [SettingsDocument] { [] }
    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        SettingsDocument(scopeName: scopeName, values: [:])
    }
    func saveScope(_ scopeName: String, values: [String : String]) async throws {
        _ = scopeName
        _ = values
    }
    func getValue(scopeName: String, key: String) async throws -> String? {
        _ = scopeName
        _ = key
        return nil
    }
    func setValue(scopeName: String, key: String, value: String) async throws {
        _ = scopeName
        _ = key
        _ = value
    }
    func deleteValue(scopeName: String, key: String) async throws {
        _ = scopeName
        _ = key
    }
    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        _ = scopeName
        _ = listener
        return FirestoreListenerToken {}
    }
    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        _ = listener
        return FirestoreListenerToken {}
    }
}
