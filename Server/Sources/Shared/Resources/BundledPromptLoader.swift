import Foundation

enum BundledPromptLoader {
    static func loadPrompt(
        named name: String,
        subdirectory: String? = nil
    ) throws -> String {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "md",
            subdirectory: subdirectory
        ) else {
            throw BundledPromptLoaderError.missingPromptResource(
                name: name,
                subdirectory: subdirectory
            )
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BundledPromptLoaderError.emptyPromptResource(
                name: name,
                subdirectory: subdirectory
            )
        }

        return contents
    }
}

enum BundledPromptLoaderError: LocalizedError {
    case missingPromptResource(name: String, subdirectory: String?)
    case emptyPromptResource(name: String, subdirectory: String?)

    var errorDescription: String? {
        switch self {
        case let .missingPromptResource(name, subdirectory):
            if let subdirectory {
                return "Missing bundled prompt resource \(subdirectory)/\(name).md"
            }
            return "Missing bundled prompt resource \(name).md"
        case let .emptyPromptResource(name, subdirectory):
            if let subdirectory {
                return "Bundled prompt resource \(subdirectory)/\(name).md is empty"
            }
            return "Bundled prompt resource \(name).md is empty"
        }
    }
}
