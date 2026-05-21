import XCTest

@testable import AssistantMCPServer

@MainActor
final class ConversationAccessPolicyTests: XCTestCase {
    func test_allowAllExceptDeny_blocksOnlyExplicitDeny() {
        let model = AppModel(profile: .default, profileIndex: 0, basePort: 8080, startupMode: .preview)
        model.conversationAccessMode = .allowAllExceptDeny
        model.denyConversationNames = ["Blocked"]
        model.allowConversationNames = []

        XCTAssertTrue(model.isBlocked("Blocked"))
        XCTAssertFalse(model.isBlocked("Allowed"))
    }

    func test_denyAllExceptAllow_blocksByDefault() {
        let model = AppModel(profile: .default, profileIndex: 0, basePort: 8080, startupMode: .preview)
        model.conversationAccessMode = .denyAllExceptAllow
        model.allowConversationNames = ["Allowed"]
        model.denyConversationNames = []

        XCTAssertFalse(model.isBlocked("Allowed"))
        XCTAssertTrue(model.isBlocked("NotAllowed"))
    }

    func test_switchingMode_changesEffectiveBlocking() {
        let model = AppModel(profile: .default, profileIndex: 0, basePort: 8080, startupMode: .preview)
        model.allowConversationNames = ["Chat A"]
        model.denyConversationNames = ["Chat B"]

        model.conversationAccessMode = .allowAllExceptDeny
        XCTAssertFalse(model.isBlocked("Chat A"))
        XCTAssertTrue(model.isBlocked("Chat B"))
        XCTAssertFalse(model.isBlocked("Chat C"))

        model.conversationAccessMode = .denyAllExceptAllow
        XCTAssertFalse(model.isBlocked("Chat A"))
        XCTAssertTrue(model.isBlocked("Chat B"))
        XCTAssertTrue(model.isBlocked("Chat C"))
    }
}

