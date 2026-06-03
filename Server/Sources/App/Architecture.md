# App Architecture

This document owns application shell composition, boot order, windows, Dock visibility, and tray/menu bar integration.

## Target application composition

This section is the target architecture for the macOS shell, authentication, profiles, runtimes, windows, Dock visibility, and tray/menu bar integration.

The most important dependency rule is:

```text
ProfilesController must not receive TrayIconController.
```

Profiles are a domain/runtime feature. The tray is an application shell surface. If profiles directly call the tray, the dependency points in the wrong direction:

```text
ProfilesController -> TrayIconController
```

That would make the profiles feature know that the app happens to have a macOS status item/menu bar UI. The correct direction is:

```text
TrayIconController observes ProfilesController
```

or:

```text
AppCoordinator connects ProfilesController and TrayIconController
```

The intended flow is:

```text
ProfilesController changes
AppCoordinator observes the change, or TrayIconController observes the published state
TrayIconController rebuilds the menu
```

In short:

```text
ProfilesController publishes state.
TrayIconController rebuilds menu from that published state.
ProfilesController never calls TrayIconController directly.
```

### Boot order and ownership tree

The application should be composed in this order:

```text
AIAssistantHubApp
├── creates first: TrayIconController
│   ├── starts without depending on Firebase/Auth/Profile
│   ├── shows a minimal initial menu
│   │   ├── Starting...
│   │   └── Quit
│   │
│   └── later receives references, or is connected by the coordinator, to observe:
│       ├── AuthStateController
│       ├── ProfilesController
│       ├── AppWindowManager
│       └── AppQuitController / AppLifecycleController
│
├── creates: FirebaseBootstrap
│   ├── FirebaseApp.configure()
│   └── validates Firebase configuration
│
├── creates: AuthenticationBootstrap
│   ├── FirebaseAuthRepository
│   └── AuthStateController
│       ├── receives FirebaseAuthRepository
│       ├── publishes authState
│       │   ├── loading
│       │   ├── unauthenticated
│       │   ├── authenticated
│       │   └── failed
│       └── publishes currentSession
│
├── creates: WindowSystemBootstrap
│   ├── DockVisibilityController
│   │   └── controls the Dock icon
│   │       ├── .regular when at least one window is visible
│   │       └── .accessory when no windows are visible
│   │
│   ├── WindowVisibilityTracker
│   │   ├── receives or coordinates with DockVisibilityController
│   │   ├── observes visible windows
│   │   └── publishes visibility changes
│   │
│   └── AppWindowManager
│       ├── receives WindowVisibilityTracker
│       ├── creates/keeps the login/root window when needed
│       │   ├── AppWindowController(root)
│       │   └── AppRootView
│       ├── creates/keeps the profiles home window
│       │   └── AppWindowController(profiles_home)
│       └── creates/keeps one physical window per profile/feature id
│
├── creates: ProfilesBootstrap
│   ├── FirestoreProfileRepository
│   │   └── root collection: profiles
│   │
│   └── ProfilesController
│       ├── receives ProfileRepository
│       ├── receives ProfileRuntimeFactory
│       ├── receives ProfileWindowManaging
│       │   └── protocol implemented by AppWindowManager
│       │
│       ├── state:
│       │   ├── allProfiles[]
│       │   ├── profileRuntimes[profileId: ProfileRuntime]
│       │   ├── profileDisplayStates[]
│       │   ├── loading
│       │   └── error
│       │
│       ├── data operations:
│       │   ├── loadProfiles()
│       │   ├── createProfile()
│       │   ├── renameProfile(profileId, name)
│       │   ├── deleteProfile(profileId)
│       │   └── toggleAutoStart(profileId)
│       │
│       ├── semantic shortcuts:
│       │   ├── startProfile(profileId)
│       │   │   └── finds/creates ProfileRuntime and calls runtime.startServices()
│       │   │
│       │   ├── stopProfile(profileId)
│       │   │   └── finds ProfileRuntime and calls runtime.stopServices()
│       │   │
│       │   ├── openProfileWindow(profileId)
│       │   │   └── finds ProfileRuntime and calls runtime.openWindow()
│       │   │
│       │   └── hideProfileWindow(profileId)
│       │       └── finds ProfileRuntime and calls runtime.hideWindow()
│       │
│       └── publishes changes for UI/tray
│
├── creates: AppCoordinator / thin AppModel
│   ├── receives AuthStateController
│   ├── receives TrayIconController
│   ├── receives ProfilesController
│   ├── receives AppWindowManager
│   └── only connects flows
│       ├── when auth changes to authenticated
│       │   ├── ProfilesController.loadProfiles()
│       │   ├── AppWindowManager.showProfilesHomeWindow()
│       │   ├── ProfilesController.startAutoStartProfiles()
│       │   └── TrayIconController.rebuildMenu()
│       │
│       ├── when auth changes to unauthenticated
│       │   ├── ProfilesController.stopAllRunningProfiles()
│       │   ├── AppWindowManager.hideAllProfileWindows()
│       │   ├── AppWindowManager.showLoginWindow()
│       │   └── TrayIconController.rebuildMenu()
│       │
│       └── when profiles/runtime/window state changes
│           └── TrayIconController.rebuildMenu()
│
└── configures: AppRootView factory
    ├── AppWindowManager owns the physical root window
    ├── AppRootView receives AuthStateController through environment
    ├── AppRootView receives ProfilesController through environment
    └── AppRootView decides only which screen is visible
        ├── authState == loading
        │   └── AuthenticationRootView
        │       └── Loading
        │
        ├── authState == unauthenticated / failed
        │   └── AuthenticationRootView
        │       └── LoginScreen
        │           └── GoogleSignInButtonView
        │               └── AuthStateController.signInWithGoogle()
        │
        └── authState == authenticated
            └── ProfilesHomeScreen
                ├── receives ProfilesController
                ├── lists allProfiles[]
                └── for each Profile
                    └── ProfileRowView
                        ├── ProfileStatusBadgeView
                        └── ProfileActionsView
                            ├── Start
                            │   └── ProfilesController.startProfile(profileId)
                            ├── Stop
                            │   └── ProfilesController.stopProfile(profileId)
                            ├── Open Window
                            │   └── ProfilesController.openProfileWindow(profileId)
                            ├── Hide Window
                            │   └── ProfilesController.hideProfileWindow(profileId)
                            └── Auto Start
                                └── ProfilesController.toggleAutoStart(profileId)
```

### Window and Dock invariant

All physical app windows must be owned by `AppWindowManager`.

This includes:

- the root/login window
- the profiles home window
- every profile-specific window

The SwiftUI `App` entry point must not keep an unmanaged main content window for login or profiles. If a window is visible but does not report to `WindowVisibilityTracker`, the Dock icon can disappear while a real window exists, or a closed login window can become impossible to reopen from the tray.

The invariant is:

```text
Any physical window show/hide
└── WindowVisibilityTracker updates visibleWindowIds
    └── DockVisibilityController sets activation policy
        ├── .regular when visibleWindowIds is not empty
        └── .accessory when visibleWindowIds is empty
```

The root/login flow is:

```text
AppLifecycleController.applicationDidFinishLaunching()
└── AppModel.openDefaultWindowForCurrentState()
    ├── if auth is loading / unauthenticated / failed
    │   └── AppWindowManager.showLoginWindow()
    │       ├── creates AppWindowController(root) if needed
    │       ├── hosts AppRootView
    │       ├── shows the window
    │       └── marks root visible in WindowVisibilityTracker
    │
    └── if authenticated
        └── AppWindowManager.showProfilesHomeWindow()
```

The tray reopen flow is:

```text
Tray menu action
└── AppModel.openDefaultWindowForCurrentState()
    ├── unauthenticated / failed / loading -> AppWindowManager.showLoginWindow()
    └── authenticated -> AppWindowManager.showProfilesHomeWindow()
```

### Window controller registry

`AppWindowManager` owns every physical app window through a generic registry keyed by window id.

- `AppWindowController` is the only AppKit controller used for root, profiles home, profile, and feature windows.
- `AppWindowRequest` provides the window id, title, size, and hosted root view.
- `AppWindowManager` stores controllers in a `[String: AppWindowController]` registry instead of feature-specific controller properties.
- Feature windows remain feature-owned at the view layer through `FeatureWindowRequest`; the app layer manages only generic window requests and ids.
- `AppWindowManager` must not grow feature-specific APIs such as `showIssueDetailWindow`.

Do not reopen login/root windows with `NSApp.mainWindow`. That is fragile after a window has been closed/ordered out and bypasses the window visibility tracker.

### Tray architecture

The tray is a shell-level UI projection. It reads snapshots and invokes semantic actions. It does not own profile data, authentication, windows, or runtimes.

```text
TrayIconController
├── created first
├── later receives, observes, or is connected by AppCoordinator to:
│   ├── AuthStateController
│   ├── ProfilesController
│   ├── AppWindowManager
│   └── AppQuit action
│
└── rebuildMenu()
    └── TrayMenuBuilder.build(...)
        ├── reads auth state
        ├── reads profilesController.profileDisplayStates
        └── creates menu
            ├── if booting
            │   ├── Starting...
            │   └── Quit
            │
            ├── if unauthenticated
            │   ├── Open Login Window
            │   │   └── AppWindowManager.showLoginWindow()
            │   └── Quit
            │
            └── if authenticated
                ├── Open Profiles Window
                │   └── AppWindowManager.showProfilesHomeWindow()
                │
                ├── Profiles
                │   └── ForEach profileDisplayStates
                │       └── TrayMenuProfileItemBuilder
                │           ├── Status
                │           ├── Auto Start
                │           │   └── ProfilesController.toggleAutoStart(profileId)
                │           ├── Start
                │           │   └── ProfilesController.startProfile(profileId)
                │           ├── Stop
                │           │   └── ProfilesController.stopProfile(profileId)
                │           ├── Open Window
                │           │   └── ProfilesController.openProfileWindow(profileId)
                │           ├── Hide Window
                │           │   └── ProfilesController.hideProfileWindow(profileId)
                │           └── Diagnostics
                │               ├── profileId
                │               └── mcpPort
                │
                ├── Sign Out
                │   └── AppCoordinator.signOut()
                │       ├── ProfilesController.stopAllRunningProfiles()
                │       ├── AppWindowManager.hideAllProfileWindows()
                │       ├── AuthStateController.signOut()
                │       └── TrayIconController.rebuildMenu()
                │
                └── Quit
                    └── AppLifecycleController.quit()
                        ├── ProfilesController.stopAllRunningProfiles()
                        └── NSApp.terminate()
```

### Architectural decision summary

The defended architecture is:

```text
TrayIconController does not belong to Profiles.
ProfilesController does not receive TrayIconController.
TrayIconController observes or is connected to ProfilesController.
ProfilesController knows profile runtimes.
ProfileRuntime knows its own window through ProfileWindowManaging.
AppWindowManager creates physical windows.
ProfileWindowHostView hosts CommandCenterScreen for a running profile.
CommandCenter owns workspace routing and layout, not runtime lifecycle.
Feature-owned screens render CommandCenter route content.
AppRootView only switches Login/ProfileHome according to auth.
```
