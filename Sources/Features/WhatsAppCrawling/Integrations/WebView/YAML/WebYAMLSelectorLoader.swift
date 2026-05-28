import Foundation

enum WebYAMLSelectorLoader {
    static func loadBundledYAML() throws -> String {
        if let url = Bundle.main.url(
            forResource: "whatsapp_web_selectors",
            withExtension: "yaml"
        ) {
            return try String(contentsOf: url, encoding: .utf8)
        }

        throw WebYAMLExtractionRunnerError.bundledYAMLNotFound
    }
}
