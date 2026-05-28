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

enum WhatsAppCrawlingAccessPolicy: String, CaseIterable, Codable, Identifiable {
    case allowAllExceptDenyList
    case denyAllExceptAllowList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowAllExceptDenyList:
            return "Allow except deny list"
        case .denyAllExceptAllowList:
            return "Deny except allow list"
        }
    }
}
