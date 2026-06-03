import Foundation
import SwiftUI

@MainActor
public final class AppWindowManager: ObservableObject, ProfileWindowManaging {
    public static let rootWindowId = "root"
    public static let profilesHomeWindowId = "profiles_home"

    public let visibilityTracker: WindowVisibilityTracker
    private let dockVisibilityController: DockVisibilityController

    private var windowControllers: [String: AppWindowController] = [:]
    private var rootContentFactory: (() -> AnyView)?
    private var profilesHomeContentFactory: (() -> AnyView)?
    private weak var profilesController: ProfilesController?

    public init(
        visibilityTracker: WindowVisibilityTracker,
        dockVisibilityController: DockVisibilityController
    ) {
        self.visibilityTracker = visibilityTracker
        self.dockVisibilityController = dockVisibilityController
    }

    func configureRootWindow(contentFactory: @escaping () -> AnyView) {
        rootContentFactory = contentFactory
    }

    func configure(profilesController: ProfilesController) {
        self.profilesController = profilesController
        profilesHomeContentFactory = { [weak profilesController] in
            guard let profilesController else {
                return AnyView(EmptyView())
            }

            return AnyView(ProfilesHomeWindowHostView(profilesController: profilesController))
        }
    }

    public func installRootWindow(rootView: AnyView) {
        guard windowControllers[Self.rootWindowId] == nil else { return }
        windowControllers[Self.rootWindowId] = makeWindowController(
            request: AppWindowRequest(
                id: Self.rootWindowId,
                title: "AI Assistant Hub",
                rootView: rootView,
                size: CGSize(width: 980, height: 680)
            )
        )
    }

    public func showRootWindow(contentFactory: (() -> AnyView)? = nil) {
        let factory = contentFactory ?? rootContentFactory
        if windowControllers[Self.rootWindowId] == nil, let factory {
            installRootWindow(rootView: factory())
        }
        windowControllers[Self.rootWindowId]?.show()
    }

    public func hideRootWindow() {
        hideWindow(id: Self.rootWindowId)
    }

    public func showLoginWindow() {
        hideProfilesHomeWindow()
        showRootWindow()
    }

    public func installProfilesHomeWindow(rootView: AnyView) {
        guard windowControllers[Self.profilesHomeWindowId] == nil else { return }
        windowControllers[Self.profilesHomeWindowId] = makeWindowController(
            request: AppWindowRequest(
                id: Self.profilesHomeWindowId,
                title: "Profiles",
                rootView: rootView,
                size: CGSize(width: 980, height: 680)
            )
        )
    }

    public func showProfilesHomeWindow(contentFactory: (() -> AnyView)? = nil) {
        hideRootWindow()
        let factory = contentFactory ?? profilesHomeContentFactory
        if windowControllers[Self.profilesHomeWindowId] == nil, let factory {
            installProfilesHomeWindow(rootView: factory())
        }
        windowControllers[Self.profilesHomeWindowId]?.show()
    }

    public func hideProfilesHomeWindow() {
        hideWindow(id: Self.profilesHomeWindowId)
    }

    public func installProfileWindow(profileId: String, title: String, rootView: AnyView) {
        let windowId = profileWindowId(profileId: profileId)
        guard windowControllers[windowId] == nil else { return }
        windowControllers[windowId] = makeWindowController(
            request: AppWindowRequest(
                id: windowId,
                title: title,
                rootView: rootView
            )
        )
    }

    func showProfileWindow(profile: Profile) {
        guard let profileId = profile.id, !profileId.isEmpty else { return }
        let windowId = profileWindowId(profileId: profileId)
        if windowControllers[windowId] == nil {
            installProfileWindow(
                profileId: profileId,
                title: profile.name,
                rootView: AnyView(
                    ProfileWindowHostView(
                        profileId: profileId,
                        profilesController: profilesControllerOrEmpty()
                    )
                )
            )
        }
        windowControllers[windowId]?.show()
    }

    public func hideProfileWindow(profileId: String) {
        hideWindow(id: profileWindowId(profileId: profileId))
    }

    func showFeatureWindow(profileId: String, request: FeatureWindowRequest) {
        let windowId = featureWindowId(profileId: profileId, featureWindowId: request.id)
        showWindow(
            AppWindowRequest(
                id: windowId,
                title: request.title,
                rootView: request.rootView
            )
        )
    }

    public func isProfileWindowVisible(profileId: String) -> Bool {
        visibilityTracker.visibleWindowIds.contains(profileWindowId(profileId: profileId))
    }

    public var visibleWindowCount: Int {
        visibilityTracker.visibleWindowIds.count
    }

    public func hideAllWindows() {
        for controller in windowControllers.values {
            controller.hide()
        }
        syncDockVisibility()
    }

    public func clearProfileWindows() {
        removeWindows { $0.hasPrefix("profile_") }
        syncDockVisibility()
    }

    public func syncDockVisibility() {
        dockVisibilityController.setDockVisible(visibilityTracker.hasVisibleWindows)
    }

    private func profilesControllerOrEmpty() -> ProfilesController {
        guard let profilesController else {
            fatalError("AppWindowManager must be configured with ProfilesController before opening profile windows.")
        }

        return profilesController
    }

    private func makeWindowController(request: AppWindowRequest) -> AppWindowController {
        AppWindowController(
            request: request,
            visibilityTracker: visibilityTracker,
            onVisibilityChange: { [weak self] in self?.syncDockVisibility() }
        )
    }

    private func showWindow(_ request: AppWindowRequest) {
        if windowControllers[request.id] == nil {
            windowControllers[request.id] = makeWindowController(request: request)
        }

        windowControllers[request.id]?.show()
    }

    private func hideWindow(id: String) {
        windowControllers[id]?.hide()
    }

    private func removeWindows(matching shouldRemove: (String) -> Bool) {
        for (id, controller) in windowControllers where shouldRemove(id) {
            controller.hide()
        }

        windowControllers = windowControllers.filter { id, _ in
            !shouldRemove(id)
        }
    }

    private func profileWindowId(profileId: String) -> String {
        "profile_\(profileId)"
    }

    private func featureWindowId(profileId: String, featureWindowId: String) -> String {
        "\(profileWindowId(profileId: profileId))_feature_\(featureWindowId)"
    }
}
