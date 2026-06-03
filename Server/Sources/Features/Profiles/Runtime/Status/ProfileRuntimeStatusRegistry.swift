import Foundation

@MainActor
final class ProfileRuntimeStatusRegistry {
    private var providers: [any ProfileRuntimeStatusProvider] = []

    var items: [ProfileRuntimeStatusItem] {
        providers.flatMap { $0.statusItems() }
    }

    func register(_ provider: any ProfileRuntimeStatusProvider) {
        providers.append(provider)
    }
}
