import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let authController: AuthStateController
    let coordinator: AuthenticatedAppCoordinator
    let profilesController: ProfilesController
    let windowManager: AppWindowManager
    let dockVisibilityController: DockVisibilityController
    let trayIconController: TrayIconController

    private(set) var isPreparedForTermination = false
    private var terminationPreparationTask: Task<Void, Never>?

    init(authController: AuthStateController, trayIconController: TrayIconController) {
        self.authController = authController

        let visibilityTracker = WindowVisibilityTracker()
        let dockVisibilityController = DockVisibilityController()
        let windowManager = AppWindowManager(
            visibilityTracker: visibilityTracker,
            dockVisibilityController: dockVisibilityController
        )

        self.windowManager = windowManager
        self.dockVisibilityController = dockVisibilityController
        self.trayIconController = trayIconController
        let profilesController = ProfilesController(
            profileRepository: FirestoreProfileRepository(),
            windowManager: windowManager
        )
        windowManager.configure(profilesController: profilesController)

        self.profilesController = profilesController
        self.coordinator = AuthenticatedAppCoordinator(profilesController: profilesController)

        windowManager.configureRootWindow { [weak authController, weak self] in
            guard let authController, let self else {
                return AnyView(EmptyView())
            }

            return AnyView(
                AppRootView()
                    .environmentObject(authController)
                    .environmentObject(self)
                    .environmentObject(self.coordinator)
            )
        }

        coordinator.onProfilesChanged = { [weak self] _ in
            Task { @MainActor in
                self?.rebuildTrayMenu()
            }
        }

        rebuildTrayMenu()
    }

    func startAuthenticatedShell(session: AuthSession) {
        coordinator.start(session: session)
        windowManager.showProfilesHomeWindow()
        rebuildTrayMenu()
    }

    func stopAuthenticatedShell() async {
        await coordinator.stop()
        windowManager.hideProfilesHomeWindow()
        windowManager.clearProfileWindows()
        rebuildTrayMenu()
    }

    func rebuildTrayMenu() {
        let snapshot = TrayMenuBuilder.Snapshot(
            profiles: coordinator.profileDisplayStates,
            phase: trayPhase
        )

        trayIconController.updateMenu(
            snapshot: snapshot,
            actions: TrayMenuBuilder.Actions(
                openProfiles: { [weak self] in
                    self?.openDefaultWindowForCurrentState()
                },
                clearFirestoreCacheAndQuit: { [weak self] in
                    Task { @MainActor in
                        await self?.clearFirestoreCacheAndQuitFromTray()
                    }
                },
                signOut: { [weak self] in
                    Task { @MainActor in
                        await self?.signOutFromTray()
                    }
                },
                quit: { [weak self] in
                    Task { @MainActor in
                        await self?.quitFromTray()
                    }
                }
            ),
            profileActions: { [weak self] displayState in
                TrayMenuProfileItemBuilder.Actions(
                    start: { [weak self] _ in
                        Task { @MainActor in
                            if let profileId = displayState.profile.id {
                                await self?.profilesController.startProfile(profileId: profileId)
                            }
                            self?.rebuildTrayMenu()
                        }
                    },
                    stop: { [weak self] _ in
                        Task { @MainActor in
                            if let profileId = displayState.profile.id {
                                await self?.profilesController.stopProfile(profileId: profileId)
                            }
                            self?.rebuildTrayMenu()
                        }
                    },
                    showWindow: { [weak self] _ in
                        Task { @MainActor in
                            if let profileId = displayState.profile.id {
                                await self?.profilesController.openProfileWindow(profileId: profileId)
                            }
                            self?.rebuildTrayMenu()
                        }
                    },
                    hideWindow: { [weak self] _ in
                        Task { @MainActor in
                            if let profileId = displayState.profile.id {
                                self?.profilesController.hideProfileWindow(profileId: profileId)
                            }
                            self?.rebuildTrayMenu()
                        }
                    },
                    toggleAutoStart: { [weak self] _ in
                        if let profileId = displayState.profile.id {
                            self?.profilesController.toggleAutoStart(profileId: profileId, enabled: !displayState.profile.autoStart)
                        }
                        self?.rebuildTrayMenu()
                    }
                )
            }
        )
    }

    private func signOutFromTray() async {
        await stopAuthenticatedShell()
        await authController.signOut()
        windowManager.showLoginWindow()
        rebuildTrayMenu()
    }

    private func quitFromTray() async {
        await prepareForTermination()
        NSApp.terminate(nil)
    }

    private func clearFirestoreCacheAndQuitFromTray() async {
        await coordinator.stop(flushPendingSettings: false)
        windowManager.hideProfilesHomeWindow()
        windowManager.clearProfileWindows()
        windowManager.hideAllWindows()
        isPreparedForTermination = true

        do {
            try await FirestoreCacheResetCoordinator.clearActivePersistence()
        } catch {
            print("Failed to clear local data cache before quit: \(error.localizedDescription)")
        }

        NSApp.terminate(nil)
    }

    func prepareForTermination() async {
        if isPreparedForTermination {
            return
        }

        if let terminationPreparationTask {
            await terminationPreparationTask.value
            return
        }

        let task = Task { @MainActor in
            await profilesController.stopAllRunningProfiles()
            windowManager.hideAllWindows()
            isPreparedForTermination = true
        }

        terminationPreparationTask = task
        await task.value
    }

    func openDefaultWindowForCurrentState() {
        if coordinator.isAuthenticated {
            windowManager.showProfilesHomeWindow()
        } else {
            windowManager.showLoginWindow()
        }
    }

    private var trayPhase: TrayMenuBuilder.Snapshot.Phase {
        switch authController.state {
        case .loading:
            return .booting
        case .unauthenticated:
            return .unauthenticated
        case .authenticated:
            return .authenticated
        case .failed(let message):
            return .failed(message: message)
        }
    }
}
