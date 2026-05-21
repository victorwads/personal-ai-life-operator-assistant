import Foundation

@testable import AssistantMCPServer

enum TestContextFactory {
    static func makeDefaults() -> UserDefaults {
        // Per-test-suite isolated storage. We clear it when constructing to keep tests deterministic.
        let suite = "dev.wads.AssistantMCPServer.unittests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @MainActor
    static func makeServerContext(
        defaults: UserDefaults,
        memoryStore: WhatsAppMemoryStore,
        runtime: TestMCPRuntime
    ) -> MCPServerContext {
        MCPServerContext(
            runtime: runtime,
            memoryStore: memoryStore,
            accessibility: AccessibilityService(),
            accessibilityScheduler: AccessibilityActionScheduler(),
            parser: WhatsAppAppParser(),
            interactor: WhatsAppInteractor(),
            voiceAssistant: VoiceAssistant(),
            nicknamesRepository: NicknamesRepository(defaults: defaults),
            memoriesRepository: MemoriesRepository(defaults: defaults),
            sensitiveDataRepository: SensitiveDataRepository(
                store: KeychainDataStore(
                    service: "dev.wads.AssistantMCPServer.unittests",
                    account: "sensitive-data"
                )
            ),
            subjectsRepository: SubjectsRepository(defaults: defaults),
            clientVoiceEventsRepository: ClientVoiceEventsRepository(defaults: defaults)
        )
    }
}
