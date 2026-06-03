import Foundation

@MainActor
final class NativeWhatsAppCrawlingService: WhatsAppCrawlingService {
    private let settings: WhatsAppNativeSettingsWrapper

    private(set) var state: WhatsAppCrawlingServiceState = .stopped
    var statusText: String? { nil }
    let activeIntegration: WhatsAppCrawlingActiveIntegration = .nativeAccessibility

    var integration: (any WhatsAppCrawlingIntegration)? {
        // TODO: Expose NativeWhatsAppIntegration once AccessibilityRuntime is
        // initialized by this service instead of placeholder UI/debug paths.
        nil
    }

    init(settings: WhatsAppNativeSettingsWrapper) {
        self.settings = settings
    }

    func start() async {
        guard state == .stopped else { return }
        _ = settings.enabled
        // TODO: Initialize the profile-owned AccessibilityRuntime here.
        // TODO: Keep native crawling disabled until orchestration owns polling and business rules.
        state = .started
    }

    func stop() async {
        guard state == .started else { return }
        // TODO: Tear down Accessibility observers and runtime state here.
        state = .stopped
    }
}
