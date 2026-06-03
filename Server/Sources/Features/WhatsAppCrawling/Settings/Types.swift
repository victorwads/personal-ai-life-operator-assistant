import Foundation

enum WhatsAppCrawlingActiveIntegration: String, CaseIterable, Codable, Identifiable {
    case webView
    case nativeAccessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webView:
            return "WebView"
        case .nativeAccessibility:
            return "Native Accessibility"
        }
    }
}
