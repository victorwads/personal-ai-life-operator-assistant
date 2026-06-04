import Foundation

@MainActor
final class ProfileRuntimeRegistry: ObservableObject {
    @Published private(set) var runtimesById: [String: ProfileRuntime] = [:]

    init() {}

    func runtime(for profileId: String) -> ProfileRuntime? {
        runtimesById[profileId]
    }

    var allRuntimes: [ProfileRuntime] {
        Array(runtimesById.values)
    }

    func upsertRuntime(for profile: Profile, windowManager: ProfileWindowManaging? = nil) -> ProfileRuntime? {
        guard let id = profile.id, !id.isEmpty else {
            return nil
        }

        if let existing = runtimesById[id] {
            return existing
        }

        let runtime = ProfileRuntime(
            context: ProfileContext(profile: profile),
            windowManager: windowManager
        )
        runtimesById[id] = runtime
        return runtime
    }

    func removeRuntime(for profileId: String) {
        runtimesById.removeValue(forKey: profileId)
    }

    func clear() {
        runtimesById.removeAll()
    }
}
