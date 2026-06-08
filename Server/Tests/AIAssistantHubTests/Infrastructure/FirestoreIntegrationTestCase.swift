import XCTest
@testable import AIAssistantHub

class FirestoreIntegrationTestCase: XCTestCase {
    var fixtureBuilder: FirestoreFixtureBuilder!
    var scope: FirebaseProfileScope!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        await FirestoreTestEnvironment.configure()
        scope = .testScope()
        fixtureBuilder = FirestoreFixtureBuilder(scope: scope)
    }

    override func tearDown() async throws {
        if let fixtureBuilder {
            try await fixtureBuilder.clearFixture()
        }
        scope = nil
        fixtureBuilder = nil
        try await super.tearDown()
    }
}
