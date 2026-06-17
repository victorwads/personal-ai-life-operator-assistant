import Foundation

@MainActor
protocol AIImageExtracting: Sendable {
    func extractTextAndDescription(
        from imageURLs: [URL],
        mediaKind: ChatMessage.Kind
    ) async throws -> String
}

@MainActor
final class AIImageExtractionService: AIImageExtracting {
    private let profileId: String
    private let streamingService: any AIConnectionStreamingServing
    private let settingsProvider: @Sendable () async -> AIConnectionProviderConfiguration
    private let promptProvider: @Sendable () throws -> String
    private let cacheRepository: any AIImageExtractionCacheRepository
    private let resourceUsageRepository: any AIResourceUsageRepository
    private let runtimeLogger: AIConnectionRuntimeLogger
    private let tokenEstimator = AITokenEstimator()

    init(
        profileId: String,
        streamingService: any AIConnectionStreamingServing,
        settingsProvider: @escaping @Sendable () async -> AIConnectionProviderConfiguration,
        promptProvider: @escaping @Sendable () throws -> String,
        cacheRepository: any AIImageExtractionCacheRepository,
        resourceUsageRepository: any AIResourceUsageRepository = NoopAIResourceUsageRepository(),
        runtimeLogger: AIConnectionRuntimeLogger? = nil
    ) {
        self.profileId = profileId
        self.streamingService = streamingService
        self.settingsProvider = settingsProvider
        self.promptProvider = promptProvider
        self.cacheRepository = cacheRepository
        self.resourceUsageRepository = resourceUsageRepository
        self.runtimeLogger = runtimeLogger ?? AIConnectionRuntimeLogger(
            errorLogStore: AIConnectionErrorLogStore(),
            serverLogsProvider: {
                ServerLogsService(
                    repository: SQLiteServerLogRepository(profileId: "ai-connection-default")
                )
            }
        )
    }

    func extractTextAndDescription(
        from imageURLs: [URL],
        mediaKind: ChatMessage.Kind
    ) async throws -> String {
        guard !imageURLs.isEmpty else { return "" }

        if imageURLs.count == 1, let imageURL = imageURLs.first {
            return try await extractSingleImageText(
                from: imageURL,
                mediaKind: mediaKind,
                imageIndex: 0,
                totalImages: 1
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var extractedTexts: [String] = []
        for (index, imageURL) in imageURLs.enumerated() {
            let text = try await extractSingleImageText(
                from: imageURL,
                mediaKind: mediaKind,
                imageIndex: index,
                totalImages: imageURLs.count
            )
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }
            extractedTexts.append(trimmedText)
        }
        return extractedTexts.joined(separator: "\n\n")
    }

    private func extractSingleImageText(
        from imageURL: URL,
        mediaKind: ChatMessage.Kind,
        imageIndex: Int,
        totalImages: Int
    ) async throws -> String {
        guard imageIndex >= 0, totalImages >= 1 else { return "" }
        let imageId = imageURL.deletingPathExtension().lastPathComponent
        do {
            if let cachedText = try await cacheRepository.getCachedText(
                profileId: profileId,
                imageId: imageId
            ) {
                let trimmedCachedText = cachedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedCachedText.isEmpty {
                    return trimmedCachedText
                }
            }
        } catch {
            // Cache is best-effort. Continue with live extraction if it is unavailable.
        }

        let extractedText = try await extractSingleImageTextFromAI(
            imageURL: imageURL,
            mediaKind: mediaKind
        )
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        do {
            try await cacheRepository.saveCachedText(
                profileId: profileId,
                imageId: imageId,
                text: trimmedText
            )
        } catch {
            // Cache is best-effort. Keep the extracted text even if persistence fails.
        }
        return trimmedText
    }

    private func extractSingleImageTextFromAI(
        imageURL: URL,
        mediaKind: ChatMessage.Kind
    ) async throws -> String {
        let startedAt = Date()
        let configuration = await settingsProvider()
        let prompt = try promptProvider()
        let contentParts = try Self.contentParts(for: imageURL, mediaKind: mediaKind)

        let request = AIProviderRequest(
            model: configuration.model,
            messages: [
                AIConversationMessage(role: .system, content: prompt),
                AIConversationMessage(role: .user, contentParts: contentParts)
            ],
            tools: [],
            temperature: 0.0,
            reasoningEffort: configuration.reasoningEffort,
            maxOutputTokens: 8192,
            cacheMode: configuration.cacheMode,
            loadAvailableTools: false
        )

        let estimatedInputTokens = tokenEstimator.estimateInputTokens(for: request)
        var extractedText = ""
        var providerUsage: AIUsage?
        var provider: AIConnectionProviderKind?
        var model: String?

        let eventsStream: AsyncThrowingStream<AIStreamEvent, Error>
        if configuration.providerKind == .aiRuntime {
            if await !AIRuntimeFeature.sharedRuntime.isModelLoaded() {
                try await AIRuntimeFeature.sharedRuntime.start()
            }
            let runtimeStream = try await AIRuntimeFeature.sharedRuntime.streamImageExtractionDetails(
                imageURL: imageURL,
                prompt: "",
                systemPrompt: prompt,
                runtimeSettings: configuration.runtimeSettings
            )
            eventsStream = AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        continuation.yield(.requestStarted(provider: .aiRuntime, model: "Local Model"))
                        continuation.yield(.responseStarted(id: nil))
                        
                        var accumulatedText = ""
                        for try await event in runtimeStream {
                            switch event {
                            case .startedDecoding:
                                break
                            case .chunk(let text):
                                accumulatedText += text
                                continuation.yield(.textDelta(text))
                            case .stats(let stats):
                                let usage = AIUsage(
                                    promptTokens: stats.promptTokenCount,
                                    completionTokens: stats.generationTokenCount,
                                    reasoningTokens: nil,
                                    totalTokens: stats.promptTokenCount + stats.generationTokenCount,
                                    cachedInputTokens: nil
                                )
                                continuation.yield(.usage(usage))
                                let response = AIProviderResponse(
                                    id: nil,
                                    model: "Local Model",
                                    provider: .aiRuntime,
                                    finishReason: "stop",
                                    text: accumulatedText,
                                    reasoning: "",
                                    toolCalls: [],
                                    usage: usage
                                )
                                continuation.yield(.completed(response))
                            }
                        }
                        continuation.finish()
                    } catch {
                        let failure = AIProviderFailure(
                            message: error.localizedDescription,
                            provider: .aiRuntime,
                            model: "Local Model",
                            underlyingError: String(describing: error)
                        )
                        continuation.yield(.failed(failure))
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        } else {
            eventsStream = streamingService.streamEvents(for: request, overrideConfiguration: configuration)
        }

        for try await event in eventsStream {
            switch event {
            case let .requestStarted(eventProvider, eventModel):
                provider = eventProvider
                model = eventModel
            case let .usage(usage):
                providerUsage = usage
            case let .textDelta(delta):
                extractedText += delta
            case let .completed(response):
                provider = response.provider
                model = response.model
                providerUsage = response.usage ?? providerUsage
                if extractedText.isEmpty {
                    extractedText = response.text
                }
            case .failed(let failure):
                runtimeLogger.logImageExtractionCompleted(
                    profileId: profileId,
                    imageId: imageURL.deletingPathExtension().lastPathComponent,
                    mediaKind: mediaKind,
                    provider: provider,
                    model: model,
                    success: false,
                    extractedText: nil,
                    errorMessage: failure.message,
                    usage: providerUsage,
                    isEstimated: providerUsage == nil,
                    durationMilliseconds: Date().timeIntervalSince(startedAt) * 1_000
                )
                throw failure
            default:
                break
            }
        }

        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let usage = providerUsage ?? AIUsage(
            promptTokens: estimatedInputTokens,
            completionTokens: tokenEstimator.estimateOutputTokens(text: trimmedText),
            reasoningTokens: nil,
            totalTokens: estimatedInputTokens + tokenEstimator.estimateOutputTokens(text: trimmedText),
            cachedInputTokens: nil
        )

        if (usage.promptTokens ?? 0) > 0 ||
            (usage.completionTokens ?? 0) > 0 ||
            (usage.reasoningTokens ?? 0) > 0 ||
            (usage.totalTokens ?? 0) > 0 {
            await resourceUsageRepository.add(
                AIResourceUsageAddition(
                    pool: .imageExtraction,
                    provider: provider,
                    model: model,
                    usage: usage,
                    success: true
                )
            )
        }

        runtimeLogger.logImageExtractionCompleted(
            profileId: profileId,
            imageId: imageURL.deletingPathExtension().lastPathComponent,
            mediaKind: mediaKind,
            provider: provider,
            model: model,
            success: true,
            extractedText: trimmedText.isEmpty ? nil : trimmedText,
            errorMessage: nil,
            usage: usage,
            isEstimated: providerUsage == nil,
            durationMilliseconds: Date().timeIntervalSince(startedAt) * 1_000
        )
        return extractedText
    }

    private static func contentParts(
        for imageURL: URL,
        mediaKind: ChatMessage.Kind
    ) throws -> [AIConversationContentPart] {
        var parts: [AIConversationContentPart] = []
        if let textPart = promptTextPart(for: mediaKind) {
            parts.append(.text(textPart))
        }

        parts.append(.imageURL(try Self.dataURLString(for: imageURL)))
        return parts
    }

    private static func promptTextPart(for mediaKind: ChatMessage.Kind) -> String? {
        switch mediaKind {
        case .sticker:
            return "sticker"
        default:
            return nil
        }
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
