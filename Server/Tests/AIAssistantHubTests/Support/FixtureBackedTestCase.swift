import XCTest

class FixtureBackedTestCase: XCTestCase {
    func fixtureTexts(in relativeDirectory: String) throws -> [(name: String, text: String)] {
        try TestFixtureLoader.directoryURLs(in: relativeDirectory).map { url in
            let relativePath = try TestFixtureLoader.relativePath(from: url)
            return (url.lastPathComponent, try TestFixtureLoader.text(relativePath: relativePath))
        }
    }

    func fixtureText(_ relativePath: String) throws -> String {
        try TestFixtureLoader.text(relativePath: relativePath)
    }

    func runScenarioNamed(_ name: String, using body: () throws -> Void) throws {
        try XCTContext.runActivity(named: name) { _ in
            try body()
        }
    }

    func assertFixtureInputs(
        in relativeDirectory: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        assertion: (String) throws -> Void
    ) throws {
        let fixtures = try fixtureTexts(in: relativeDirectory)
        XCTAssertFalse(fixtures.isEmpty, "Expected at least one fixture in \(relativeDirectory)", file: file, line: line)

        for fixture in fixtures {
            try runScenarioNamed(fixture.name) {
                try assertion(fixture.text)
            }
        }
    }
}
