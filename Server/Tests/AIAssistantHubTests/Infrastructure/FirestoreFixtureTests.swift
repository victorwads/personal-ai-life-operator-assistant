import XCTest
@testable import AIAssistantHub

final class FirestoreFixtureTests: XCTestCase {
    func testLoadThrowsForUnknownAccountProfileCollection() {
        XCTAssertThrowsError(try FirestoreFixture.load(named: "unknown-collection.json")) { error in
            let message = (error as NSError).localizedDescription
            XCTAssertTrue(message.contains("BogusThings"))
            XCTAssertTrue(message.contains("valid AccountProfiles collection"))
        }
    }
}
