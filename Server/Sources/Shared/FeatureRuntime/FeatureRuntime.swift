import Foundation

@MainActor
struct MCPContext {
    let toolRegistry: MCPToolRegistry
}

@MainActor
struct FeatureServicesContext {
    let serviceRegistry: ProfileRuntimeServiceRegistry
}

@MainActor
struct FeatureStatusContext {
    let statusRegistry: ProfileRuntimeStatusRegistry
}

@MainActor
class FeatureRuntime {
    class var id: String {
        fatalError("Subclasses must override id.")
    }

    let context: FeatureContext

    private(set) var observingStarted = false
    private(set) var servicesStarted = false

    required init(context: FeatureContext) {
        self.context = context
    }

    final func startObserving() async {
        guard !observingStarted else { return }

        await onStartObserving()
        observingStarted = true
    }

    final func stopObserving() async {
        guard observingStarted else { return }

        await onStopObserving()
        observingStarted = false
    }

    final func startServices() async {
        guard !servicesStarted else { return }

        await startObserving()
        await onStartServices()
        servicesStarted = true
    }

    final func stopServices() async {
        guard servicesStarted else { return }

        await onStopServices()
        servicesStarted = false
    }

    func onStartObserving() async {}
    func onStopObserving() async {}
    func onStartServices() async {}
    func onStopServices() async {}
}
