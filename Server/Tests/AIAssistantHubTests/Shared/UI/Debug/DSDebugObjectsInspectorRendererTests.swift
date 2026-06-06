import XCTest
@testable import AIAssistantHub

final class DSDebugObjectsInspectorRendererTests: XCTestCase {
    func testRecomputesRenderedItemsForNewSelectionWithSameItemCount() {
        let firstSelection = [
            DebugObjectItem(id: UUID(), title: "Summary", value: "first-summary"),
            DebugObjectItem(id: UUID(), title: "Metadata", value: #"{"provider":"one"}"#)
        ]
        let secondSelection = [
            DebugObjectItem(id: UUID(), title: "Summary", value: "second-summary"),
            DebugObjectItem(id: UUID(), title: "Metadata", value: #"{"provider":"two"}"#)
        ]

        let firstRendered = DSDebugObjectsInspectorRenderer.renderedItems(for: firstSelection)
        let secondRendered = DSDebugObjectsInspectorRenderer.renderedItems(for: secondSelection)

        XCTAssertEqual(firstRendered.count, 2)
        XCTAssertEqual(secondRendered.count, 2)
        XCTAssertEqual(firstRendered.map(\.title), ["Summary", "Metadata"])
        XCTAssertEqual(secondRendered.map(\.title), ["Summary", "Metadata"])
        XCTAssertEqual(firstRendered[0].renderedValue, "first-summary")
        XCTAssertEqual(secondRendered[0].renderedValue, "second-summary")
        XCTAssertTrue(firstRendered[1].renderedValue.contains("\"provider\" : \"one\""))
        XCTAssertTrue(secondRendered[1].renderedValue.contains("\"provider\" : \"two\""))
        XCTAssertNotEqual(firstRendered.map(\.renderedValue), secondRendered.map(\.renderedValue))
    }

    func testRecomputesRenderedValueWhenIdentityStaysTheSameButContentChanges() {
        let sharedID = UUID()
        let firstSelection = [
            DebugObjectItem(id: sharedID, title: "Summary", value: "first-summary")
        ]
        let secondSelection = [
            DebugObjectItem(id: sharedID, title: "Summary", value: "second-summary")
        ]

        let firstRendered = DSDebugObjectsInspectorRenderer.renderedItems(for: firstSelection)
        let secondRendered = DSDebugObjectsInspectorRenderer.renderedItems(for: secondSelection)

        XCTAssertEqual(firstRendered[0].id, sharedID)
        XCTAssertEqual(secondRendered[0].id, sharedID)
        XCTAssertEqual(firstRendered[0].title, "Summary")
        XCTAssertEqual(secondRendered[0].title, "Summary")
        XCTAssertEqual(firstRendered[0].renderedValue, "first-summary")
        XCTAssertEqual(secondRendered[0].renderedValue, "second-summary")
    }
}
