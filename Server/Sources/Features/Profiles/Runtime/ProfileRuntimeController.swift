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
        guard let runtime = registry.upsertRuntime(for: profile, windowManager: windowManager) else {
            return
        }
        do {
            try await runtime.startServices()
        } catch {
            // ProfileRuntime is responsible for transitioning to .failed; controller keeps UI updated.
            print("ProfileRuntimeController: failed to start profile \(profile.id ?? ""): \(error)")
        }
        objectWillChange.send()
    }

    func stopProfile(profileId: String) async {
        guard let runtime = registry.runtime(for: profileId) else { return }
        await runtime.stopServices()
        objectWillChange.send()
    }

    func openProfileWindow(_ profile: Profile) async {
        guard let profileId = profile.id, !profileId.isEmpty else {
            return
        }

        guard let runtime = registry.upsertRuntime(for: profile, windowManager: windowManager) else {
            return
        }

        do {
            try await runtime.openWindow(using: windowManager)
        } catch {
            print("ProfileRuntimeController: failed to open profile window \(profileId): \(error)")
        }
        objectWillChange.send()
    }

    func openIssueDetailWindow(profileId: String, issueId: String) async {
        guard let runtime = registry.runtime(for: profileId) else {
            return
        }

        do {
            try await runtime.openIssueDetailWindow(
                issueId: issueId,
                using: windowManager
            )
        } catch {
            print("ProfileRuntimeController: failed to open issue detail window \(issueId): \(error)")
        }

        objectWillChange.send()
    }

    func hideProfileWindow(profileId: String) {
        registry.runtime(for: profileId)?.hideWindow(using: windowManager)
        objectWillChange.send()
    }

    func stopAllProfiles(flushPendingSettings: Bool = true) async {
        for runtime in registry.allRuntimes {
            if let profileId = runtime.context.profile.id {
                windowManager?.hideProfileWindow(profileId: profileId)
            }
            await runtime.stop(flushPendingSettings: flushPendingSettings)
        }
        registry.clear()
        objectWillChange.send()
    }
}
