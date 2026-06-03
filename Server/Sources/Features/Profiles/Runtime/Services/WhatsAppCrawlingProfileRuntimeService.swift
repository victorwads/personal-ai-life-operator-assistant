import Foundation

@MainActor
final class WhatsAppCrawlingProfileRuntimeService: ProfileRuntimeService {
    let id: String
    let title: String

    private let service: any WhatsAppCrawlingService

    init(id: String, title: String, service: any WhatsAppCrawlingService) {
        self.id = id
        self.title = title
        self.service = service
    }

    var state: ProfileRuntimeServiceState {
        switch service.state {
        case .stopped:
            return .stopped
        case .starting:
            return .starting
        case .started:
            return .running
        case .stopping:
            return .stopping
        case .failed(let message):
            return .failed(message)
        }
    }

    var crawlingService: any WhatsAppCrawlingService {
        service
    }

    var statusDetail: String? {
        service.statusText
    }

    func start() async {
        await service.start()
    }

    func stop() async {
        await service.stop()
    }
}
