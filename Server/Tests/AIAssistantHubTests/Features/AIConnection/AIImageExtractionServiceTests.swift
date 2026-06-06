import XCTest
@testable import AIAssistantHub

@MainActor
final class AIImageExtractionServiceTests: XCTestCase {
    func testExtractTextAndDescriptionBuildsOneMultimodalRequestForAllImages() async throws {
        let prompt = "Prompt from bundle"
        let image1 = try makeTempImageURL(fileExtension: "png", contents: Data("image-one".utf8))
        let image2 = try makeTempImageURL(fileExtension: "jpg", contents: Data("image-two".utf8))

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

        let service = AIImageExtractionService(
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
            promptProvider: { prompt }
        )

        let extractedText = try await service.extractTextAndDescription(from: [image1, image2])

        XCTAssertEqual(extractedText, "Visible text")

        let recordedRequests = streamingService.recordedRequests
        XCTAssertEqual(recordedRequests.count, 1)
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.model, "image-model")
        XCTAssertEqual(request.tools.count, 0)
        XCTAssertFalse(request.loadAvailableTools)
        XCTAssertEqual(request.temperature, 0.0)
        XCTAssertEqual(request.reasoningEffort, .off)
        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.messages[0].role, .system)
        XCTAssertEqual(request.messages[0].content, prompt)
        XCTAssertEqual(request.messages[1].role, .user)

        let contentParts = try XCTUnwrap(request.messages[1].contentParts)
        XCTAssertEqual(contentParts.count, 2)

        guard case let .imageURL(firstURL) = contentParts[0] else {
            return XCTFail("Expected first content part to be an image URL")
        }
        guard case let .imageURL(secondURL) = contentParts[1] else {
            return XCTFail("Expected second content part to be an image URL")
        }

        XCTAssertTrue(firstURL.hasPrefix("data:image/png;base64,"))
        XCTAssertTrue(secondURL.hasPrefix("data:image/jpeg;base64,"))
        XCTAssertTrue(firstURL.contains(Data("image-one".utf8).base64EncodedString()))
        XCTAssertTrue(secondURL.contains(Data("image-two".utf8).base64EncodedString()))
    }

    private func makeTempImageURL(fileExtension: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
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
            Task {
                for event in responseEvents {
                    continuation.yield(event)
                }
                continuation.finish()
            }
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
