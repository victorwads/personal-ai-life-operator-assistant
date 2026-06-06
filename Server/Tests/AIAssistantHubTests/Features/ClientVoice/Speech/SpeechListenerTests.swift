import XCTest
import Speech
import AVFoundation
@testable import AIAssistantHub

final class SpeechListenerTests: XCTestCase {
    func testWhisperProviderThrowsNotImplemented() async {
        do {
            _ = try await SpeechListener.listen(provider: .whisper)
            XCTFail("Expected notImplemented error to be thrown")
        } catch SpeechListenerError.notImplemented(let message) {
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testListenConfigDefaults() {
        let config = ListenConfig()
        XCTAssertEqual(config.language, "auto")
        XCTAssertEqual(config.debounceFinalMs, 1200)
        XCTAssertNil(config.postProcessing)
    }

    func testCustomListenConfig() {
        let whisperConfig = WhisperPostProcessingConfig(
            isEnabled: true,
            modelPath: "/tmp/model.bin",
            coreMLModelPath: "/tmp/model-encoder.mlmodelc",
            language: "pt"
        )
        let config = ListenConfig(
            language: "en-US",
            debounceFinalMs: 500,
            postProcessing: whisperConfig
        )
        XCTAssertEqual(config.language, "en-US")
        XCTAssertEqual(config.debounceFinalMs, 500)
        XCTAssertEqual(config.postProcessing?.isEnabled, true)
        XCTAssertEqual(config.postProcessing?.modelPath, "/tmp/model.bin")
        XCTAssertEqual(config.postProcessing?.coreMLModelPath, "/tmp/model-encoder.mlmodelc")
        XCTAssertEqual(config.postProcessing?.language, "pt")
    }

    func testBrazilianPortugueseLocaleConfig() {
        let config = ListenConfig(language: "pt-BR", debounceFinalMs: 1000)
        XCTAssertEqual(config.language, "pt-BR")
        let locale = Locale(identifier: config.language)
        XCTAssertTrue(locale.identifier.contains("pt"))
    }

    func testWhisperPostProcessingConfigDefaults() {
        let config = WhisperPostProcessingConfig()
        XCTAssertFalse(config.isEnabled)
        XCTAssertNil(config.modelPath)
        XCTAssertNil(config.coreMLModelPath)
        XCTAssertEqual(config.language, "auto")
    }

    func testMakeFinalTextResolverReturnsNilWhenWhisperPostProcessingDisabled() {
        let resolver = SpeechListener.makeFinalTextResolver(
            whisperPostProcessingConfig: WhisperPostProcessingConfig(isEnabled: false)
        )

        XCTAssertNil(resolver)
    }

    func testListenHandlerUsesAppleSpeechTextDirectlyWhenWhisperPostProcessingDisabled() async {
        let locale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return
        }

        let resolver = MockSpeechFinalTextResolver(resolvedText: "should not be used")
        let handler = ListenHandler(
            config: ListenConfig(
                language: "en-US",
                debounceFinalMs: 500,
                postProcessing: WhisperPostProcessingConfig(isEnabled: false)
            ),
            recognizer: recognizer,
            audioEngine: AVAudioEngine(),
            finalTextResolver: resolver
        )

        let resolvedText = await handler.resolveFinalText(
            appleSpeechText: "apple speech",
            capturedSamples: [0.1, 0.2]
        )

        XCTAssertEqual(resolvedText, "apple speech")
        XCTAssertFalse(handler.usesWhisperPostProcessing)
        let warmUpCallCount = await resolver.warmUpCallCount
        let resolveCallCount = await resolver.resolveCallCount
        XCTAssertEqual(warmUpCallCount, 0)
        XCTAssertEqual(resolveCallCount, 0)
    }

    func testListenHandlerUsesResolverWhenWhisperPostProcessingEnabled() async {
        let locale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return
        }

        let resolver = MockSpeechFinalTextResolver(resolvedText: "whisper text")
        let handler = ListenHandler(
            config: ListenConfig(
                language: "en-US",
                debounceFinalMs: 500,
                postProcessing: WhisperPostProcessingConfig(
                    isEnabled: true,
                    modelPath: "/tmp/model.bin",
                    coreMLModelPath: nil,
                    language: "pt"
                )
            ),
            recognizer: recognizer,
            audioEngine: AVAudioEngine(),
            finalTextResolver: resolver
        )

        let resolvedText = await handler.resolveFinalText(
            appleSpeechText: "apple speech",
            capturedSamples: [0.1, 0.2]
        )

        XCTAssertEqual(resolvedText, "whisper text")
        XCTAssertTrue(handler.usesWhisperPostProcessing)
        let resolveCallCount = await resolver.resolveCallCount
        XCTAssertEqual(resolveCallCount, 1)
    }

    func testListenHandlerCancelResolvesAwaitWithEmptyString() async {
        let locale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            // If the test environment doesn't support the English locale, skip this test.
            return
        }
        let audioEngine = AVAudioEngine()
        let handler = ListenHandler(
            config: ListenConfig(),
            recognizer: recognizer,
            audioEngine: audioEngine
        )

        let task = Task {
            await handler.await()
        }

        // Cancel the handler.
        handler.cancel()

        let result = await task.value
        XCTAssertEqual(result, "")
    }
}

private actor MockSpeechFinalTextResolver: SpeechFinalTextResolving {
    private(set) var warmUpCallCount: Int = 0
    private(set) var resolveCallCount: Int = 0

    private let resolvedText: String

    init(resolvedText: String) {
        self.resolvedText = resolvedText
    }

    func warmUp(whisperConfig: WhisperPostProcessingConfig?) async {
        warmUpCallCount += 1
    }

    func resolveFinalText(
        appleSpeechText: String,
        capturedAudioSamples: [Float],
        whisperConfig: WhisperPostProcessingConfig?,
        cancellationToken: WhisperProcessingCancellationToken
    ) async -> String {
        resolveCallCount += 1
        return resolvedText
    }
}
