import Foundation

@MainActor
protocol WhatsAppCrawlingService: AnyObject {
    var state: WhatsAppCrawlingServiceState { get }
    var activeIntegration: WhatsAppCrawlingActiveIntegration { get }
    var integration: (any WhatsAppCrawlingIntegration)? { get }

    func start() async
    func stop() async
}
