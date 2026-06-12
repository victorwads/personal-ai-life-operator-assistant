enum SpeakMethod: String, CaseIterable, Identifiable {
    case command
    case swiftAPI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .command:
            return "Terminal say"
        case .swiftAPI:
            return "AVSpeechSynthesizer"
        }
    }
}
