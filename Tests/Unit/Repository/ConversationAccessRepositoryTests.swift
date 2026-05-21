import XCTest

@testable import AssistantMCPServer

@MainActor
final class ConversationAccessRepositoryTests: XCTestCase {
    func test_saveAndLoad_roundTripsAndSorts() {
        let suite = "dev.wads.AssistantMCPServer.unittests.conversationAccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let repo = ConversationAccessRepository(defaults: defaults)
        repo.save(
            mode: .denyAllExceptAllow,
            deny: ["Zed", "Alpha"],
            allow: ["B", "A"]
        )

        let loaded = repo.load()
        XCTAssertEqual(loaded.mode, .denyAllExceptAllow)
        XCTAssertEqual(loaded.deny, ["Alpha", "Zed"])
        XCTAssertEqual(loaded.allow, ["A", "B"])
    }
}
