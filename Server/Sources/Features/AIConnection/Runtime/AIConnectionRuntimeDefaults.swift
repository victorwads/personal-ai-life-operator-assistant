import Foundation

enum AIConnectionRuntimeDefaults {
    static let baseSystemPrompt = loadSystemPrompt()

    static func systemPrompt(assistantName: String) -> String {
        let trimmedName = assistantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return baseSystemPrompt
        }

        return """
        \(baseSystemPrompt)

        ## Assistant identity

        Your name is \(trimmedName).
        """
    }

    private static func loadSystemPrompt() -> String {
        if let contents = try? BundledPromptLoader.loadPrompt(named: "AssistantSystemPrompt") {
            return contents
        }

        return """
        You are running inside the AI Connection Playground of a local-first macOS personal assistant app.

        Failed to load bundled AssistantSystemPrompt.md.
        Return a short diagnostic response acknowledging this fallback.
        """
    }
}
