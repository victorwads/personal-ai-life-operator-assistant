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
    }

    func testCustomListenConfig() {
        let config = ListenConfig(language: "en-US", debounceFinalMs: 500)
        XCTAssertEqual(config.language, "en-US")
        XCTAssertEqual(config.debounceFinalMs, 500)
    }

    func testBrazilianPortugueseLocaleConfig() {
        let config = ListenConfig(language: "pt-BR", debounceFinalMs: 1000)
        XCTAssertEqual(config.language, "pt-BR")
        let locale = Locale(identifier: config.language)
        XCTAssertTrue(locale.identifier.contains("pt"))
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
