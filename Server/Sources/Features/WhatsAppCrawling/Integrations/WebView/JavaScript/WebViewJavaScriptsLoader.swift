import Foundation

enum WebViewJavaScripts {
    static let assistantBridge: String = loadBundledJavaScript(
        named: "WebViewAssistantBridge",
        subdirectory: nil
    )

    private static func loadBundledJavaScript(
        named name: String,
        subdirectory: String?
    ) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: subdirectory) else {
            preconditionFailure("Missing bundled JavaScript resource \(resourceName(name, subdirectory: subdirectory)).js")
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                preconditionFailure("Bundled JavaScript resource \(resourceName(name, subdirectory: subdirectory)).js is empty")
            }
            return contents
        } catch {
            preconditionFailure("Failed to load bundled JavaScript resource \(resourceName(name, subdirectory: subdirectory)).js: \(error.localizedDescription)")
        }
    }

    private static func resourceName(_ name: String, subdirectory: String?) -> String {
        if let subdirectory, !subdirectory.isEmpty {
            return "\(subdirectory)/\(name)"
        }
        return name
    }
}
