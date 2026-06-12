import Foundation
import AVFoundation

@MainActor
enum SpeechSpeaker {
    static func speak(
        text: String,
        config: SpeakConfig? = nil
    ) async throws -> SpeechSpeakHandler {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return CompletedSpeechSpeakHandler() }

        let resolvedConfig = config ?? SayCommandSpeakConfig()

        switch resolvedConfig.method {
        case .command:
            let sayConfig = resolvedConfig as? SayCommandSpeakConfig ?? SayCommandSpeakConfig()
            return try speakWithSay(text: trimmedText, rate: sayConfig.rate)
        case .swiftAPI:
            let swiftConfig = resolvedConfig as? SwiftAPISpeakConfig ?? SwiftAPISpeakConfig()
            return speakWithSwiftAPI(
                text: trimmedText,
                voice: swiftConfig.voice,
                language: swiftConfig.language,
                rate: swiftConfig.rate
            )
        }
    }

    private static func speakWithSay(text: String, rate: Float?) throws -> SpeechSpeakHandler {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = makeSayArguments(text: text, rate: rate)

        let handler = ProcessSpeechSpeakHandler(process: process)
        try handler.start()
        return handler
    }

    private static func makeSayArguments(text: String, rate: Float?) -> [String] {
        var arguments: [String] = []

        if let rate, rate > 0 {
            arguments.append("-r")
            arguments.append(String(Int(rate.rounded())))
        }

        arguments.append(text)
        return arguments
    }

    @MainActor
    private static func speakWithSwiftAPI(
        text: String,
        voice: String?,
        language: String?,
        rate: Float?
    ) -> SpeechSpeakHandler {
        let utterance = AVSpeechUtterance(string: text)

        if let voice = voice, !voice.isEmpty, let targetVoice = AVSpeechSynthesisVoice(identifier: voice) {
            utterance.voice = targetVoice
        } else if let language = language, !language.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        }

        if let rate {
            utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, rate))
        } else {
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        }

        let handler = AVSpeechSpeakHandler(utterance: utterance)
        handler.start()
        return handler
    }

}
