import XCTest
@testable import AIAssistantHub

final class AIJSONValueToolArgumentParsingTests: FixtureBackedTestCase {
    func testParseObjectAcceptsEmptyObjectVariants() throws {
        try assertFixtureInputs(
            in: "AIConnection/ToolArgumentParsing/Success/EmptyObject"
        ) { raw in
            XCTAssertEqual(try AIJSONValue.parseObject(from: raw), [:])
        }
    }

    func testParseObjectAcceptsLimitOnlyObjectVariants() throws {
        try assertFixtureInputs(
            in: "AIConnection/ToolArgumentParsing/Success/LimitOnlyObject"
        ) { raw in
            XCTAssertEqual(try AIJSONValue.parseObject(from: raw), ["limit": .int(10)])
        }
    }

    func testParseObjectAcceptsLimitAndQueryObjectVariants() throws {
        try assertFixtureInputs(
            in: "AIConnection/ToolArgumentParsing/Success/LimitAndQueryObject"
        ) { raw in
            XCTAssertEqual(
                try AIJSONValue.parseObject(from: raw),
                ["limit": .int(10), "query": .string("chat")]
            )
        }
    }

    func testParseObjectAcceptsLimitAndOffsetObjectVariants() throws {
        try assertFixtureInputs(
            in: "AIConnection/ToolArgumentParsing/Success/LimitAndOffsetObject"
        ) { raw in
            XCTAssertEqual(
                try AIJSONValue.parseObject(from: raw),
                ["limit": .int(10), "offset": .int(0)]
            )
        }
    }

    func testParseObjectRejectsInvalidRootFixtures() throws {
        try assertFixtureInputs(
            in: "AIConnection/ToolArgumentParsing/Failure/NonObjectRoot"
        ) { raw in
            XCTAssertThrowsError(try AIJSONValue.parseObject(from: raw))
        }
    }
}
