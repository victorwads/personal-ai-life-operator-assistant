import Foundation

@MainActor
final class ProfileRuntimeController: ObservableObject {
    let registry: ProfileRuntimeRegistry

    private let windowManager: ProfileWindowManaging?

    init(registry: ProfileRuntimeRegistry, windowManager: ProfileWindowManaging? = nil) {
        self.registry = registry
        self.windowManager = windowManager
    }

    func runtime(for profileId: String) -> ProfileRuntime? {
        registry.runtime(for: profileId)
    }

    func isRunning(profileId: String) -> Bool {
        registry.runtime(for: profileId)?.state == .running || registry.runtime(for: profileId)?.state == .starting
    }

    func displayState(for profile: Profile) -> ProfileDisplayState {
        let runtime = registry.runtime(for: profile.id ?? "")
        return ProfileDisplayState(
            profile: profile,
            runtimeState: runtime?.state ?? .stopped,
            windowState: runtime?.windowState ?? .hidden
        )
    }

    func displayStates(for profiles: [Profile]) -> [ProfileDisplayState] {
        profiles.map(displayState(for:))
    }

    func startProfile(_ profile: Profile) async {
        guard let runtime = registry.upsertRuntime(for: profile) else {
            return
        }
        await runtime.start()
        objectWillChange.send()
    }

    func stopProfile(profileId: String) async {
        guard let runtime = registry.runtime(for: profileId) else { return }
        windowManager?.hideProfileWindow(profileId: profileId)
        await runtime.stop()
        registry.removeRuntime(for: profileId)
        objectWillChange.send()
    }

    func openProfileWindow(_ profile: Profile) async {
        guard let profileId = profile.id, !profileId.isEmpty else { return }

        if registry.runtime(for: profileId) == nil {
            await startProfile(profile)
        }

        windowManager?.showProfileWindow(profile: profile)
        registry.runtime(for: profileId)?.setWindowState(.visible)
        objectWillChange.send()
    }

    func hideProfileWindow(profileId: String) {
        windowManager?.hideProfileWindow(profileId: profileId)
        registry.runtime(for: profileId)?.setWindowState(.hidden)
        objectWillChange.send()
    }

    func stopAllProfiles() async {
        for runtime in registry.allRuntimes {
            if let profileId = runtime.context.profile.id {
                windowManager?.hideProfileWindow(profileId: profileId)
            }
            await runtime.stop()
        }
        registry.clear()
        objectWillChange.send()
    }
}
