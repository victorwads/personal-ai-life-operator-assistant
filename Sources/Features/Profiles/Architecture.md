# Profiles Architecture

This document owns profile registry, runtime lifecycle, profile-scoped service registration, and profile window lifecycle rules.

### Profile runtime creation

The profile window is not born directly from the tray, and it is not born directly from the row view. UI surfaces ask the profiles controller for a semantic action by `profileId`; the controller finds or creates the runtime; the runtime delegates physical window creation to a window-management protocol.

The intended start flow is:

```text
ProfilesController.startProfile(profileId)
├── finds Profile in allProfiles[]
├── if runtime already exists in profileRuntimes[profileId]
│   └── returns existing runtime
│
└── if runtime does not exist
    ├── ProfileRuntimeFactory.make(profile)
    │   └── creates ProfileRuntime
    │       ├── receives ProfileContext
    │       │   ├── profileId
    │       │   ├── profile
    │       │   ├── FirebaseProfileScope
    │       │   └── mcpPort
    │       │
    │       ├── receives ProfileWindowManaging
    │       │   └── protocol implemented by AppWindowManager
    │       │
    │       └── creates ProfileRuntimeContainer
    │           ├── placeholder now
    │           └── future:
    │               ├── repositories scoped by profile
    │               ├── MCP server on the profile port
    │               ├── WhatsApp runtime
    │               ├── assistant loop
    │               ├── settings observer
    │               └── logs/debug
    │
    ├── profileRuntimes[profileId] = runtime
    └── runtime.startServices()
        ├── ensures ProfileRuntimeContainer exists
        ├── starts SettingsStore so service autoStart settings can be read
        ├── starts passive feature observation
        └── starts only subservices whose autoStart setting is enabled
```

The controller-level methods are intentionally allowed and useful:

```text
ProfilesController.startProfile(profileId)
└── runtime.startServices()

ProfilesController.stopProfile(profileId)
└── runtime.stopServices()

ProfilesController.openProfileWindow(profileId)
└── runtime.openWindow()

ProfilesController.hideProfileWindow(profileId)
└── runtime.hideWindow()
```

These are semantic shortcuts for UI and tray surfaces. They should perform lookup and delegation. The real per-profile behavior belongs to `ProfileRuntime`.

### Profile runtime subservices

`ProfileRuntimeContainer` owns shared profile-scoped registries and creates `AppFeatures`. Each connected feature exposes its root entrypoint as `<FeatureName>Feature.swift`, and `AppFeatures` owns the list of connected `FeatureRuntime` entries.

`ProfileRuntimeContainer` must not manually list feature classes or instantiate feature-specific settings wrappers, repositories, services, MCP providers, or status providers directly. Those internals live in the owning feature runtime.

`ProfileRuntimeContainer` should expose features through strict typed lookup only. It should not expose loose feature internals such as repositories, log stores, or service instances as compatibility properties.

`ProfileRuntimeContainer` owns profile-scoped subservices through `ProfileRuntimeServiceRegistry`. A subservice has a stable id, title, state, `start()`, and `stop()`. The registry is intentionally small: it stores service instances, supports lookup by id, can start selected services, and can stop all services.

Subservices are controlled independently from the profile window. Creating or ensuring the runtime container may register service instances for later use, but it must not start WhatsApp WebView, crawling/polling, AI connection, MCP server, or any other service just because the CommandCenter window opens.

`autoStart` is per service, not one vague profile runtime switch. Profile Start starts only services whose own settings enable autoStart. Profile Stop calls the registry to stop all running subservices for that profile. Later UI and badges should read service states from this registry instead of inferring service health from `ProfileRuntimeState`.

WhatsApp WebView and WhatsApp Crawling/Polling are separate services:

- WhatsApp WebView owns the profile's in-memory `WKWebView` and may run while polling is stopped.
- WhatsApp Crawling/Polling periodically reads or interacts with WhatsApp and can be paused or stopped independently.
- Future crawling, send-message, and refresh flows should pause or stop polling without destroying the WebView unless the WebView service itself is stopped.

The `WKWebView` belongs to the profile runtime service. CommandCenter routes must render the service-owned view and must not create a second `WKWebView` for the same profile. If the WebView service is stopped, no view exists; if the service starts, it creates the view; if the service stops, it destroys the view.

Embedded and detached hosting must move the same service-owned `WKWebView` between containers. Embedded CommandCenter hosting should attach the existing view to its SwiftUI/AppKit bridge. Future detached windows should host that same instance temporarily and return it to the embedded route when the detached window closes.

Current detach behavior rules:

- The WhatsApp WebView service owns exactly one `WKWebView`.
- CommandCenter and detached windows only host the service-owned `WKWebView`; they never create a second one.
- Detach moves that same `WKWebView` instance to a separate window without reload.
- Closing the detached window reattaches to embedded mode without stopping the service.
- Stopping the WebView service destroys the `WKWebView` and closes any detached host window.
- While detached, CommandCenter hides the WebView sidebar route.

Current service autoStart settings:

- `whatsappWebView.autoStart`
- `whatsappCrawling.autoStart`
- `aiConnection.autoStart`
- `mcpServer.autoStart`

### Profile runtime status/actions

`ProfileRuntimeStatusRegistry` is the service status/action counterpart to `SettingsSectionRegistry`. Owning features register profile-runtime-scoped status providers, and the profile UI renders the resulting status items. Profiles and CommandCenter should not hardcode every service's internal rules.

A status item is intentionally small: id, title, state label, optional detail, optional action title, and optional async action. Actions are contextual start/stop controls for now; restart, open/show, and diagnostics can be added later without changing the profile UI rendering model.

CommandCenter may render status items while services are stopped. Opening the profile window may ensure service instances and status providers exist for display, but it must not start the underlying services.

### Profile window lifecycle

The intended `openWindow` flow inside a runtime is:

```text
ProfileRuntime.openWindow()
├── ensures ProfileRuntimeContainer exists for UI/settings
├── calls windowManaging.showProfileWindow(profile)
│   └── AppWindowManager.showProfileWindow(profile)
│       ├── if window already exists in profileWindows[profileId]
│       │   └── makeKeyAndOrderFront()
│       │
│       └── if window does not exist
│           ├── creates ProfileWindowController(profileId)
│           ├── creates ProfileWindowHostView(profileId)
│           │   └── CommandCenterScreen(profile, runtimeState, windowState, container)
│           │       ├── CommandCenterSidebar
│           │       │   └── CommandCenterMenuRegistry.sections()
│           │       └── CommandCenterScreenRegistry.screen(for: selectedRoute, container)
│           │           ├── MyProfileScreen
│           │           ├── IssuesScreen
│           │           ├── MemoriesScreen
│           │           ├── SensitiveDataScreen
│           │           ├── ClientVoiceScreen
│           │           ├── ChatsScreen
│           │           ├── WhatsApp*Screen
│           │           ├── MCPServers*Screen
│           │           └── SettingsScreen
│           ├── stores it in profileWindows[profileId]
│           ├── shows window
│           └── WindowVisibilityTracker.windowDidShow(profileId)
│               └── DockVisibilityController.refresh()
│
└── runtime.windowState = visible
```

Opening a profile window is independent from starting profile services. It must not start WhatsApp WebView rendering, crawling/polling, AI connection services, MCP servers, or other service runtimes. The CommandCenter may render while `ProfileRuntimeState` is `stopped`; it receives profile context and settings registries from the ensured container.

The intended `hideWindow` flow is:

```text
ProfileRuntime.hideWindow()
├── calls windowManaging.hideProfileWindow(profileId)
│   └── AppWindowManager.hideProfileWindow(profileId)
│       ├── finds ProfileWindowController
│       ├── orderOut / hide
│       └── WindowVisibilityTracker.windowDidHide(profileId)
│           └── DockVisibilityController.refresh()
│
└── runtime.windowState = hidden
```

The intended `stop` flow is:

```text
ProfileRuntime.stopServices()
├── asks ProfileRuntimeServiceRegistry to stop all services
│   ├── stops future MCP server
│   ├── stops future WhatsApp runtime
│   ├── stops future AI connection
│   └── cancels future assistant loop
├── runtime.state = stopped
└── keeps ProfileWindowState unchanged
```

Start Profile controls service startup only. It starts the profile runtime container if needed, reads profile-scoped settings, starts passive feature observation, and starts only subservices with their own autoStart enabled. It does not need to open the profile window.

Stop Profile controls service shutdown only. It stops all running subservices for that profile and does not necessarily close or hide the window. Hiding or closing the profile window only changes `ProfileWindowState`; it does not stop subservices.
