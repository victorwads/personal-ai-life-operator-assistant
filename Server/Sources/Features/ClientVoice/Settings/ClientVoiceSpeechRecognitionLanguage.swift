import Foundation

enum ClientVoiceSpeechRecognitionLanguage: String, CaseIterable, Identifiable {
    case systemDefault = "auto"
    case brazilianPortuguese = "pt-BR"
    case englishUS = "en-US"
    case spanishSpain = "es-ES"
    case frenchFrance = "fr-FR"
    case germanGermany = "de-DE"
    case italianItaly = "it-IT"
    case japaneseJapan = "ja-JP"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault:
            return "System Default"
        case .brazilianPortuguese:
            return "Portuguese (Brazil)"
        case .englishUS:
            return "English (US)"
        case .spanishSpain:
            return "Spanish (Spain)"
        case .frenchFrance:
            return "French (France)"
        case .germanGermany:
            return "German (Germany)"
        case .italianItaly:
            return "Italian (Italy)"
        case .japaneseJapan:
            return "Japanese (Japan)"
        }
    }
}
