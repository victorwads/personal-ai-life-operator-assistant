import Foundation

public struct AIRuntimePrompt: Sendable {
    public let name: String
    public let subdirectory: String?
    public let content: String
    public let hash: String

    public init(
        name: String,
        subdirectory: String?,
        content: String,
        hash: String
    ) {
        self.name = name
        self.subdirectory = subdirectory
        self.content = content
        self.hash = hash
    }
}

extension AIRuntimePrompt {
    static func loadImageExtractionPrompt(
        configuration: AIRuntimeConfiguration
    ) throws -> AIRuntimePrompt {
        do {
            let content = try BundledPromptLoader.loadPrompt(
                named: configuration.imageExtractionPromptName,
            )
            return AIRuntimePrompt(
                name: configuration.imageExtractionPromptName,
                subdirectory: configuration.imageExtractionPromptSubdirectory,
                content: content,
                hash: AIRuntimePromptHasher.sha256(content)
            )
        } catch let error as BundledPromptLoaderError {
            throw AIRuntimeError.promptResourceNotFound(
                error.localizedDescription
            )
        } catch {
            throw AIRuntimeError.promptResourceNotFound(
                error.localizedDescription
            )
        }
    }
}
