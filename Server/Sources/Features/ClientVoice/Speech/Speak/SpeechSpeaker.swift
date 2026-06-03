import Foundation

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
            return try await speakWithSay(text: trimmedText, rate: sayConfig.rate)
        case .swiftAPI:
            throw SpeechSpeakerError.notImplemented("Swift speech API is not implemented yet.")
        }
    }

    private static func speakWithSay(text: String, rate: Float?) async throws -> SpeechSpeakHandler {
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

}
