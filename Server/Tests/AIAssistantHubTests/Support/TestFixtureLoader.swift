import Foundation

enum TestFixtureLoader {
    static func text(relativePath: String, bundle: Bundle = fixtureBundle) throws -> String {
        let url = try fixtureURL(relativePath: relativePath, bundle: bundle)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func directoryURLs(in relativeDirectory: String, bundle: Bundle = fixtureBundle) throws -> [URL] {
        let directoryURL = try fixtureURL(relativePath: relativeDirectory, bundle: bundle)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func relativePath(from fileURL: URL, bundle: Bundle = fixtureBundle) throws -> String {
        let baseURL = try fixtureBaseURL(bundle: bundle)
        return fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
    }

    private static func fixtureURL(relativePath: String, bundle: Bundle) throws -> URL {
        let sanitizedPath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let candidateURL = try fixtureBaseURL(bundle: bundle).appendingPathComponent(sanitizedPath)
        guard FileManager.default.fileExists(atPath: candidateURL.path) else {
            throw FixtureLoaderError.missingFixture(candidateURL.path)
        }
        return candidateURL
    }

    private static func fixtureBaseURL(bundle: Bundle) throws -> URL {
        if let resourceURL = bundle.resourceURL?.appendingPathComponent("Fixtures"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        // Fallback to the source tree for command-line or partially regenerated runs.
        let sourceURL = URL(fileURLWithPath: #filePath)
        let testsDirectoryURL = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = testsDirectoryURL.appendingPathComponent("Fixtures")
        if FileManager.default.fileExists(atPath: fixtureURL.path) {
            return fixtureURL
        }

        throw FixtureLoaderError.missingFixtureBase
    }

    private static var fixtureBundle: Bundle {
        Bundle(for: FixtureBundleToken.self)
    }
}

private final class FixtureBundleToken {}

private enum FixtureLoaderError: LocalizedError {
    case missingFixture(String)
    case missingFixtureBase

    var errorDescription: String? {
        switch self {
        case let .missingFixture(path):
            return "Missing test fixture at path: \(path)"
        case .missingFixtureBase:
            return "Could not locate the test fixture base directory."
        }
    }
}
