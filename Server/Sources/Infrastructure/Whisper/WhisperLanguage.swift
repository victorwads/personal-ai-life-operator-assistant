import Foundation

enum WhisperLanguage: String, CaseIterable, Identifiable {
    case auto
    case portuguese = "pt"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto Detect"
        case .portuguese:
            return "Portuguese"
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .french:
            return "French"
        case .german:
            return "German"
        case .italian:
            return "Italian"
        case .japanese:
            return "Japanese"
        }
    }
}
