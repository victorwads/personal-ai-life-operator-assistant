import Foundation

public struct AIRuntimeConfiguration: Codable, Sendable, Equatable {
    public var modelDirectory: URL
    public var modelId: String
    public var imageExtractionPromptName: String
    public var imageExtractionPromptSubdirectory: String?
    public var applicationSupportDirectoryName: String

    public init(
        modelDirectory: URL,
        modelId: String,
        imageExtractionPromptName: String,
        imageExtractionPromptSubdirectory: String?,
        applicationSupportDirectoryName: String
    ) {
        self.modelDirectory = modelDirectory
        self.modelId = modelId
        self.imageExtractionPromptName = imageExtractionPromptName
        self.imageExtractionPromptSubdirectory = imageExtractionPromptSubdirectory
        self.applicationSupportDirectoryName = applicationSupportDirectoryName
    }

    public static var localQwenDefault: AIRuntimeConfiguration {
        .init(
            modelDirectory: URL(fileURLWithPath: "/Users/victorwads/.lmstudio/models/mlx-community/Qwen3.6-35B-A3B-4bit"),
            modelId: "mlx-community/Qwen3.6-35B-A3B-4bit",
            imageExtractionPromptName: "ImageExtraction",
            imageExtractionPromptSubdirectory: "Prompts",
            applicationSupportDirectoryName: "AIRuntime"
        )
    }
}
