import Foundation

enum WhatsAppCrawlingServiceState: Equatable {
    case stopped
    case starting
    case started
    case stopping
    case failed(String)
}
