import Foundation

@MainActor
protocol AIImageExtracting: Sendable {
    func extractTextAndDescription(from imageURLs: [URL]) async throws -> String
}

@MainActor
final class AIImageExtractionService: AIImageExtracting {
    private let streamingService: any AIConnectionStreamingServing
    private let settingsProvider: @Sendable () async -> AIConnectionProviderConfiguration
    private let promptProvider: @Sendable () throws -> String

    init(
        streamingService: any AIConnectionStreamingServing,
        settingsProvider: @escaping @Sendable () async -> AIConnectionProviderConfiguration,
        promptProvider: @escaping @Sendable () throws -> String
    ) {
        self.streamingService = streamingService
        self.settingsProvider = settingsProvider
        self.promptProvider = promptProvider
    }

    func extractTextAndDescription(from imageURLs: [URL]) async throws -> String {
        guard !imageURLs.isEmpty else { return "" }

        let configuration = await settingsProvider()
        let prompt = try promptProvider()
        let imageParts = try imageURLs.map { url -> AIConversationContentPart in
            .imageURL(try Self.dataURLString(for: url))
        }

        let request = AIProviderRequest(
            model: configuration.model,
            messages: [
                AIConversationMessage(role: .system, content: prompt),
                AIConversationMessage(role: .user, contentParts: imageParts)
            ],
            tools: [],
            temperature: 0.0,
            reasoningEffort: .off,
            maxOutputTokens: 4096,
            cacheMode: configuration.cacheMode,
            loadAvailableTools: false
        )

        var extractedText = ""
        for try await event in streamingService.streamEvents(for: request) {
            switch event {
            case let .textDelta(delta):
                extractedText += delta
            case let .completed(response):
                if extractedText.isEmpty {
                    extractedText = response.text
                }
            default:
                break
            }
        }

        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dataURLString(for url: URL) throws -> String {
        guard url.isFileURL else {
            throw AIImageExtractionServiceError.nonFileURL(url)
        }

        let data = try Data(contentsOf: url)
        let mimeType = mimeType(for: url)
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "png":
            return "image/png"
        default:
            return "image/png"
        }
    }
}

enum AIImageExtractionServiceError: LocalizedError {
    case nonFileURL(URL)

    var errorDescription: String? {
        switch self {
        case let .nonFileURL(url):
            return "Image extraction requires a file URL, got \(url.absoluteString)"
        }
    }
}
