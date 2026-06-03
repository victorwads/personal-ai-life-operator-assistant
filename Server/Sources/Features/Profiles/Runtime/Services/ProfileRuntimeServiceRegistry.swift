import Foundation

@MainActor
final class ProfileRuntimeServiceRegistry {
    private var servicesById: [String: any ProfileRuntimeService] = [:]

    var allServices: [any ProfileRuntimeService] {
        servicesById.values.sorted { $0.title < $1.title }
    }

    func register(_ service: any ProfileRuntimeService) {
        servicesById[service.id] = service
    }

    func service(id: String) -> (any ProfileRuntimeService)? {
        servicesById[id]
    }

    func startServices(where shouldStart: (any ProfileRuntimeService) -> Bool) async {
        for service in allServices where shouldStart(service) {
            await service.start()
        }
    }

    func stopAll() async {
        for service in allServices {
            await service.stop()
        }
    }
}
