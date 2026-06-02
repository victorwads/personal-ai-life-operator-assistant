import XCTest
@testable import AIAssistantHub

final class RuntimeEnvironmentTests: XCTestCase {
    func testIsTestingRuntimeIsTrueWhileRunningUnitTests() {
        XCTAssertTrue(RuntimeEnvironment.isTestingRuntime)
    }
}
