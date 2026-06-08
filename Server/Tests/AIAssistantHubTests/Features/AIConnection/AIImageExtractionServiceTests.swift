import XCTest
@testable import AIAssistantHub

@MainActor
final class AIImageExtractionServiceTests: XCTestCase {
    func testSingleImageCacheHitSkipsStreamingServiceCall() async throws {
        let prompt = "Prompt from bundle"
        let image = try makeTempImageURL(fileName: "cached-image.png", contents: Data("cached-image".utf8))
        let cacheRepository = FakeAIImageExtractionCacheRepository()
        cacheRepository.cachedTextByKey["profile-1|cached-image"] = "  Cached text  "

        let streamingService = FakeAIImageExtractionStreamingService(responseEvents: [])
        let service = makeService(
            profileId: "profile-1",
            streamingService: streamingService,
            prompt: prompt,
            cacheRepository: cacheRepository
        )

        let extractedText = try await service.extractTextAndDescription(
            from: [image],
            mediaKind: .sticker
        )

        XCTAssertEqual(extractedText, "Cached text")
        XCTAssertTrue(streamingService.recordedRequests.isEmpty)
        XCTAssertEqual(cacheRepository.getRequests.count, 1)
        XCTAssertEqual(cacheRepository.getRequests.first?.0, "profile-1")
        XCTAssertEqual(cacheRepository.getRequests.first?.1, "cached-image")
        XCTAssertTrue(cacheRepository.saveRequests.isEmpty)
    }

    func testSingleImageCacheMissCallsAIAndSavesCache() async throws {
        let prompt = "Prompt from bundle"
        let image = try makeTempImageURL(fileName: "fresh-image.jpg", contents: Data("fresh-image".utf8))
        let cacheRepository = FakeAIImageExtractionCacheRepository()

        let streamingService = FakeAIImageExtractionStreamingService(
            responseEvents: [
                .textDelta("  Visible text  "),
                .completed(
                    AIProviderResponse(
                        id: "response-1",
                        model: "image-model",
                        provider: .openRouter,
                        finishReason: "stop",
                        text: "Visible text",
                        reasoning: "",
                        toolCalls: [],
                        usage: nil
                    )
                )
            ]
        )
        let service = makeService(
            profileId: "profile-1",
            streamingService: streamingService,
            prompt: prompt,
            cacheRepository: cacheRepository
        )

        let extractedText = try await service.extractTextAndDescription(
            from: [image],
            mediaKind: .image
        )

        XCTAssertEqual(extractedText, "Visible text")
        XCTAssertEqual(streamingService.recordedRequests.count, 1)
        let request = try XCTUnwrap(streamingService.recordedRequests.first)
        XCTAssertFalse(request.loadAvailableTools)
        XCTAssertEqual(cacheRepository.getRequests.count, 1)
        XCTAssertEqual(cacheRepository.getRequests.first?.0, "profile-1")
        XCTAssertEqual(cacheRepository.getRequests.first?.1, "fresh-image")
        XCTAssertEqual(cacheRepository.saveRequests.count, 1)
        XCTAssertEqual(cacheRepository.saveRequests.first?.0, "profile-1")
        XCTAssertEqual(cacheRepository.saveRequests.first?.1, "fresh-image")
        XCTAssertEqual(cacheRepository.saveRequests.first?.2, "Visible text")
    }

    func testMultiImageExtractionUsesCachePerImageAndPreservesOrder() async throws {
        let prompt = "Prompt from bundle"
        let image1 = try makeTempImageURL(fileName: "image-one.png", contents: Data("image-one".utf8))
        let image2 = try makeTempImageURL(fileName: "image-two.webp", contents: Data("image-two".utf8))
        let image3 = try makeTempImageURL(fileName: "image-three.jpg", contents: Data("image-three".utf8))
        let cacheRepository = FakeAIImageExtractionCacheRepository()
        cacheRepository.cachedTextByKey["profile-1|image-one"] = "cached one"
        cacheRepository.cachedTextByKey["profile-1|image-three"] = "cached three"
        let streamingService = FakeAIImageExtractionStreamingService(
            responseEvents: [
                .textDelta("  live two  "),
                .completed(
                    AIProviderResponse(
                        id: "response-1",
                        model: "image-model",
                        provider: .openRouter,
                        finishReason: "stop",
                        text: "live two",
                        reasoning: "",
                        toolCalls: [],
                        usage: nil
                    )
                )
            ]
        )
        let service = makeService(
            profileId: "profile-1",
            streamingService: streamingService,
            prompt: prompt,
            cacheRepository: cacheRepository
        )

        let extractedText = try await service.extractTextAndDescription(
            from: [image1, image2, image3],
            mediaKind: .image
        )

        XCTAssertEqual(
            extractedText,
            """
            cached one

            live two

            cached three
            """
        )
        XCTAssertEqual(streamingService.recordedRequests.count, 1)
        XCTAssertFalse(try XCTUnwrap(streamingService.recordedRequests.first).loadAvailableTools)
        XCTAssertEqual(cacheRepository.getRequests.count, 3)
        XCTAssertEqual(cacheRepository.getRequests.map { $0.1 }, ["image-one", "image-two", "image-three"])
        XCTAssertEqual(cacheRepository.saveRequests.count, 1)
        XCTAssertEqual(cacheRepository.saveRequests.first?.1, "image-two")
        XCTAssertEqual(cacheRepository.saveRequests.first?.2, "live two")
    }

    func testStickerRequestIncludesStickerTextPart() async throws {
        let prompt = "Prompt from bundle"
        let image = try makeTempImageURL(fileName: "sticker-image.png", contents: Data("sticker-image".utf8))
        let cacheRepository = FakeAIImageExtractionCacheRepository()
        let streamingService = FakeAIImageExtractionStreamingService(
            responseEvents: [
                .textDelta("Sticker text"),
                .completed(
                    AIProviderResponse(
                        id: "response-1",
                        model: "image-model",
                        provider: .openRouter,
                        finishReason: "stop",
                        text: "Sticker text",
                        reasoning: "",
                        toolCalls: [],
                        usage: nil
                    )
                )
            ]
        )
        let service = makeService(
            profileId: "profile-1",
            streamingService: streamingService,
            prompt: prompt,
            cacheRepository: cacheRepository
        )

        _ = try await service.extractTextAndDescription(from: [image], mediaKind: .sticker)

        let request = try XCTUnwrap(streamingService.recordedRequests.first)
        let contentParts = try XCTUnwrap(request.messages[1].contentParts)
        XCTAssertEqual(contentParts.count, 2)
        XCTAssertEqual(contentParts[0], .text("sticker"))
        guard case let .imageURL(imageURL) = contentParts[1] else {
            return XCTFail("Expected sticker image payload to include the image URL.")
        }
        XCTAssertTrue(imageURL.hasPrefix("data:image/png;base64,"))
    }

    func testImageRequestIncludesOnlyImagePayloadForImages() async throws {
        let prompt = "Prompt from bundle"
        let image = try makeTempImageURL(fileName: "image-content.png", contents: Data("image-content".utf8))
        let cacheRepository = FakeAIImageExtractionCacheRepository()
        let streamingService = FakeAIImageExtractionStreamingService(
            responseEvents: [
                .textDelta("Image text"),
                .completed(
                    AIProviderResponse(
                        id: "response-1",
                        model: "image-model",
                        provider: .openRouter,
                        finishReason: "stop",
                        text: "Image text",
                        reasoning: "",
                        toolCalls: [],
                        usage: nil
                    )
                )
            ]
        )
        let service = makeService(
            profileId: "profile-1",
            streamingService: streamingService,
            prompt: prompt,
            cacheRepository: cacheRepository
        )

        _ = try await service.extractTextAndDescription(from: [image], mediaKind: .image)

        let request = try XCTUnwrap(streamingService.recordedRequests.first)
        let contentParts = try XCTUnwrap(request.messages[1].contentParts)
        XCTAssertEqual(contentParts.count, 1)
        guard case let .imageURL(imageURL) = contentParts[0] else {
            return XCTFail("Expected image payload to include the image URL.")
        }
        XCTAssertTrue(imageURL.hasPrefix("data:image/png;base64,"))
    }

    private func makeService(
        profileId: String,
        streamingService: FakeAIImageExtractionStreamingService,
        prompt: String,
        cacheRepository: FakeAIImageExtractionCacheRepository
    ) -> AIImageExtractionService {
        AIImageExtractionService(
            profileId: profileId,
            streamingService: streamingService,
            settingsProvider: {
                AIConnectionProviderConfiguration(
                    providerKind: .openRouter,
                    baseURL: "https://example.com/v1",
                    apiKey: "secret",
                    model: "image-model",
                    temperature: 0.6,
                    reasoningEffort: .off,
                    maxOutputTokens: 4096,
                    streamingEnabled: true,
                    cacheMode: .automatic
                )
            },
            promptProvider: { prompt },
            cacheRepository: cacheRepository
        )
    }

    private func makeTempImageURL(fileName: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try contents.write(to: url, options: .atomic)
        return url
    }
}

private final class FakeAIImageExtractionStreamingService: AIConnectionStreamingServing {
    private let responseEvents: [AIStreamEvent]
    private(set) var recordedRequests: [AIProviderRequest] = []

    init(responseEvents: [AIStreamEvent]) {
        self.responseEvents = responseEvents
    }

    func streamEvents(for request: AIProviderRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        recordedRequests.append(request)
        return AsyncThrowingStream { continuation in
            for event in responseEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func availableTools() async -> [AIToolDefinition] {
        []
    }

    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult {
        AIToolExecutionResult(
            toolName: toolCall.name,
            success: false,
            payload: nil,
            errorMessage: "Not implemented in fake service.",
            suggestedAction: nil,
            validationErrors: [],
            durationMilliseconds: nil
        )
    }
}

@MainActor
private final class FakeAIImageExtractionCacheRepository: AIImageExtractionCacheRepository {
    var cachedTextByKey: [String: String] = [:]
    private(set) var getRequests: [(String, String)] = []
    private(set) var saveRequests: [(String, String, String)] = []

    func getCachedText(profileId: String, imageId: String) async throws -> String? {
        getRequests.append((profileId, imageId))
        return cachedTextByKey[key(profileId: profileId, imageId: imageId)]
    }

    func saveCachedText(profileId: String, imageId: String, text: String) async throws {
        saveRequests.append((profileId, imageId, text))
        cachedTextByKey[key(profileId: profileId, imageId: imageId)] = text
    }

    private func key(profileId: String, imageId: String) -> String {
        "\(profileId)|\(imageId)"
    }
}
