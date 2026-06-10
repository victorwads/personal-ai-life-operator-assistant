import XCTest
@testable import AIAssistantHub

final class CommandCenterMenuRegistryTests: XCTestCase {
    func testIntegrationsSectionExposesGoogleWorkspaceInsteadOfEmailAndCalendar() {
        let sections = CommandCenterMenuRegistry.sections()
        let integrations = sections.first { $0.id == "integrations" }
        let titles = integrations?.items.map(\.title) ?? []
        let icons = integrations?.items.map(\.icon) ?? []

        XCTAssertTrue(titles.contains("Google Workspace"))
        XCTAssertFalse(titles.contains("Email"))
        XCTAssertFalse(titles.contains("Calendar"))
        XCTAssertTrue(icons.contains("square.grid.2x2"))
    }
}
