import Foundation

@MainActor
final class ProfileRuntime: ObservableObject {
    let context: ProfileContext
    private weak var windowManager: ProfileWindowManaging?

    @Published private(set) var state: ProfileRuntimeState = .stopped
    @Published private(set) var windowState: ProfileWindowState = .hidden

    private(set) var container: ProfileRuntimeContainer?

    init(context: ProfileContext, windowManager: ProfileWindowManaging? = nil) {
        self.context = context
        self.windowManager = windowManager
    }

    @discardableResult
    func ensureContainer() async throws -> ProfileRuntimeContainer {
        if let container {
            try await container.startSettings()
            return container
        }

        let container = try ProfileRuntimeContainer(context: context, windowManager: windowManager)
        try await container.startSettings()
        self.container = container
        return container
    }

    func startServices() async throws {
        guard state == .stopped || state == .failed else { return }
        state = .starting

        do {
            let container = try await ensureContainer()
            try await container.startServices()
            state = .running
        } catch {
            await container?.stopServices()
            state = .failed
            throw error
        }
    }

    func stopServices() async {
        guard state == .running || state == .starting else { return }
        state = .stopping

        await container?.stopServices()
        state = .stopped
    }

    func openWindow(using windowManager: ProfileWindowManaging?) async throws {
        self.windowManager = windowManager ?? self.windowManager
        try await ensureContainer()
        (windowManager ?? self.windowManager)?.showProfileWindow(profile: context.profile)
        windowState = .visible
    }

    func openIssueDetailWindow(
        issueId: String,
        using windowManager: ProfileWindowManaging?
    ) async throws {
        self.windowManager = windowManager ?? self.windowManager
        let container = try await ensureContainer()
        let issuesFeature = container.appFeatures.feature(IssuesFeature.self)
        let request = try await issuesFeature.makeIssueDetailWindowRequest(issueId: issueId)

        (windowManager ?? self.windowManager)?.showFeatureWindow(
            profileId: context.profileId,
            request: request
        )
    }

    func hideWindow(using windowManager: ProfileWindowManaging?) {
        self.windowManager = windowManager ?? self.windowManager
        guard let profileId = context.profile.id else { return }
        (windowManager ?? self.windowManager)?.hideProfileWindow(profileId: profileId)
        windowState = .hidden
    }

    func stop(flushPendingSettings: Bool = true) async {
        await stopServices()
        await container?.stop(flushPendingSettings: flushPendingSettings)
        container = nil
    }

    func setWindowState(_ newState: ProfileWindowState) {
        windowState = newState
    }
}
