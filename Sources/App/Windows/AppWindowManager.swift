import Foundation
import SwiftUI

@MainActor
public final class AppWindowManager: ObservableObject, ProfileWindowManaging {
    public static let rootWindowId = "root"
    public static let profilesHomeWindowId = "profiles_home"

    public let visibilityTracker: WindowVisibilityTracker
    private let dockVisibilityController: DockVisibilityController

    private var rootWindowController: AppRootWindowController?
    private var rootContentFactory: (() -> AnyView)?
    private var profilesHomeWindowController: ProfilesHomeWindowController?
    private var profileWindowControllers: [String: ProfileWindowController] = [:]
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
        guard rootWindowController == nil else { return }
        rootWindowController = AppRootWindowController(
            windowId: Self.rootWindowId,
            rootView: rootView,
            visibilityTracker: visibilityTracker,
            onVisibilityChange: { [weak self] in self?.syncDockVisibility() }
        )
    }

    public func showRootWindow(contentFactory: (() -> AnyView)? = nil) {
        let factory = contentFactory ?? rootContentFactory
        if rootWindowController == nil, let factory {
            installRootWindow(rootView: factory())
        }
        rootWindowController?.show()
    }

    public func hideRootWindow() {
        rootWindowController?.hide()
    }

    public func showLoginWindow() {
        hideProfilesHomeWindow()
        showRootWindow()
    }

    public func installProfilesHomeWindow(rootView: AnyView) {
        guard profilesHomeWindowController == nil else { return }
        profilesHomeWindowController = ProfilesHomeWindowController(
            windowId: Self.profilesHomeWindowId,
            rootView: rootView,
            visibilityTracker: visibilityTracker,
            onVisibilityChange: { [weak self] in self?.syncDockVisibility() }
        )
    }

    public func showProfilesHomeWindow(contentFactory: (() -> AnyView)? = nil) {
        hideRootWindow()
        let factory = contentFactory ?? profilesHomeContentFactory
        if profilesHomeWindowController == nil, let factory {
            installProfilesHomeWindow(rootView: factory())
        }
        profilesHomeWindowController?.show()
    }

    public func hideProfilesHomeWindow() {
        profilesHomeWindowController?.hide()
    }

    public func installProfileWindow(profileId: String, title: String, rootView: AnyView) {
        guard profileWindowControllers[profileId] == nil else { return }
        let windowId = "profile_\(profileId)"
        profileWindowControllers[profileId] = ProfileWindowController(
            windowId: windowId,
            title: title,
            rootView: rootView,
            visibilityTracker: visibilityTracker,
            onVisibilityChange: { [weak self] in self?.syncDockVisibility() }
        )
    }

    func showProfileWindow(profile: Profile) {
        guard let profileId = profile.id, !profileId.isEmpty else { return }
        if profileWindowControllers[profileId] == nil {
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
        profileWindowControllers[profileId]?.show()
    }

    public func hideProfileWindow(profileId: String) {
        profileWindowControllers[profileId]?.hide()
    }

    public func isProfileWindowVisible(profileId: String) -> Bool {
        visibilityTracker.visibleWindowIds.contains("profile_\(profileId)")
    }

    public var visibleWindowCount: Int {
        visibilityTracker.visibleWindowIds.count
    }

    public func hideAllWindows() {
        rootWindowController?.hide()
        profilesHomeWindowController?.hide()
        for controller in profileWindowControllers.values {
            controller.hide()
        }
        syncDockVisibility()
    }

    public func clearProfileWindows() {
        for controller in profileWindowControllers.values {
            controller.hide()
        }
        profileWindowControllers.removeAll()
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
}
