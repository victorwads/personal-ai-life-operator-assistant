# Architecture

This document explains the intended architecture for the assistant runtime and how the major pieces fit together.

This repo is in the middle of a rewrite-from-scratch, so some sections describe the target shape while the current codebase still contains scaffolding.

## File naming

File names should be local to their folder context. Type names can be explicit because Swift does not provide folder-based namespaces, but file names should not repeat the full folder hierarchy.

Swift target basenames still need to be unique. If a fully local name like `Wrapper.swift` would collide elsewhere in the same target, use the shortest local qualifier that preserves context, such as `WebViewWrapper.swift` or `NativeWrapper.swift`.

For example, prefer `Sources/Features/WhatsAppCrawling/Settings/Wrapper.swift` over `Sources/Features/WhatsAppCrawling/Settings/WhatsAppCrawlingSettingsWrapper.swift`.

## XcodeGen and build validation

This project uses XcodeGen. Treat `AIAssistantHub.xcodeproj` as generated build output.

- Never manually edit generated files under `*.xcodeproj`, `project.pbxproj`, `*.xcworkspace`, `xcuserdata`, or generated scheme files.
- Make project configuration changes in `project.yml`, source files, scripts, or resources.
- For validation, run the repo's check/build/restart script (currently `scripts/check_build_and_restart.sh`). Do not run `xcodebuild` manually.

## Current status (rewrite scaffold)

- MCP tool *definitions* exist under `Sources/Features/**/MCP/`, registered via `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.
- General MCP utility tools belong under `Sources/Features/MCPServers/Utilities/`. Feature-specific MCP tools belong under their owning feature folder.
- Many tools are not executed yet because the default `MCPToolHandler.handle(...)` returns `notImplemented` unless a tool implements `handle`.
- The operational system prompt lives at `Resources/Prompts/AssistantSystemPrompt.md`.
- WhatsApp crawling scaffolding lives under `Sources/Features/WhatsAppCrawling/` (with both native Accessibility and WebView-oriented modules).

## High-level model

The long-term target is a native macOS assistant runtime with three major responsibilities:

1. keep local state and workflow state
2. expose operational tools through MCP
3. supervise model sessions and WhatsApp integration

LM Studio (or another local inference host) remains the inference engine. The Swift app is the runtime, supervisor, and integration layer.

## Platform rationale (macOS + Swift)

This project is intentionally macOS-first.

- macOS provides strong on-device voice building blocks through public APIs (Text-to-Speech and Speech Recognition).
- Apple Silicon machines can run local LLMs via LM Studio with enough unified memory, without depending on a discrete GPU.
- The app can stay local-first: state, tools, and integrations run on the user's machine.

### Speech and Speech Recognition

The runtime can speak and listen using a few approaches:

- macOS system `say` command (uses the configured system voice)
- Swift speech APIs (high quality voices available through the public API surface)

There are tradeoffs. For Portuguese, some voices available via Swift APIs (for example, "Fernanda Enhanced") handle accents and punctuation well, while the system/Siri voice behavior can be inconsistent for some text shapes. The goal is to keep both paths available and pick the best experience per locale and device.

## Main runtime layers

### Swift app

The macOS app is the central process.

It owns:

- application state
- persistence
- UI
- Accessibility integration
- polling and orchestration
- MCP server lifecycle
- LM Studio session supervision

### WhatsApp integration

WhatsApp is intended to be integrated through local Accessibility and WebView surfaces.

The integration layer is responsible for:

- discovering chats
- reading chat state
- sending messages
- waiting for unread messages and prompts
- handling WhatsApp Web or desktop UI changes

### MCP server

The MCP tool surface is the main interface for the assistant model.

It exposes structured actions for:

- WhatsApp operations
- voice operations
- memory management
- sensitive data management
- issues and workflow state
- utility helpers

### LM Studio supervision

The app is expected to supervise LM Studio sessions instead of relying on a long manual chat session.

This means:

- launching and pausing assistant sessions
- observing streaming events
- recovering from stalls or invalid tool behavior
- rebuilding context when necessary
- separating operational reasoning from social rendering

## Assistant lifecycle

The assistant is intended to run as a local operational loop coordinated between the model host (for example, LM Studio) and the macOS app.

At a high level:

1. the macOS app starts and exposes an MCP tool transport layer
2. the model host loads a model and starts a stateful session
3. the operational prompt is loaded from `Resources/Prompts/AssistantSystemPrompt.md`
4. the model connects to the app through MCP tools
5. the model enters a continuous workflow of reading state, waiting for events, deciding what to do, and calling tools
6. the Swift runtime persists the results and serves the next observable state back to the model

Note: this repo does not currently ship the older `plugins/lmstudio/` prompt variants from the v1 project. The prompt file above is the source of truth for the rewrite scaffold.

## Operational cycle

Once the assistant is running, the prompt guides it through a loop similar to this:

1. check current date and runtime context
2. review memories and standing preferences when relevant
3. inspect active issues and pending work
4. wait for new events or unread messages
5. read recent messages for the specific chat or event
6. update issues, memories, or sensitive-data references when needed
7. decide whether to reply, ask the client, speak to the client, or wait
8. persist the outcome so the next cycle starts from a coherent state

The important architectural point is that the model does not own durable state by itself. The Swift app owns the durable state, and the prompt teaches the model how to interact with that state through tools.

## Subjects lifecycle

In the v2 rewrite, the current abstraction is `issues` (finite threads of work with a beginning/middle/end), as reflected by the MCP tools under `Sources/Features/Issues/`.

The assistant can:

- create an issue when a new thread of work appears
- update it as more information arrives
- attach external references such as chat IDs, future Gmail threads, or calendar IDs
- resolve or cancel it when the work is done
- list active issues to recover operational context after waiting or restarting

This is one of the ways the runtime avoids relying only on the LM Studio chat context.

## Multi-profile motivation

Multi-profile support exists because the runtime can host more than one assistant on the same Mac.

In practice:

- the local model instance can stay loaded in memory
- WhatsApp polling and state sync are usually the main background cost
- different people receive messages at different times, so inference load tends not to spike constantly

This enables hosting assistants for family members (for example: partner, mother) on a single machine, while exposing a UI (and future mobile UI) so those users can manage memories, issues, and state without local access to LM Studio.

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
│       │   ├── AppRootWindowController
│       │   └── AppRootView
│       ├── creates/keeps the profiles home window
│       └── creates/keeps one physical window per profile
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
    │       ├── creates AppRootWindowController if needed
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

Do not reopen login/root windows with `NSApp.mainWindow`. That is fragile after a window has been closed/ordered out and bypasses the window visibility tracker.

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

### Settings Architecture

Settings are profile-scoped runtime state. Each active `ProfileRuntime` owns exactly one live `SettingsStore` for its profile through `ProfileRuntimeContainer`. A runtime may be active for UI/settings while its service lifecycle state is `stopped`.

The Firestore shape is fixed:

```text
AccountProfiles/{profileId}/Settings/{scopeName}
```

Each settings scope is one Firestore document. Each document stores key/value fields directly:

```text
AccountProfiles/{profileId}/Settings/whatsappCrawling
AccountProfiles/{profileId}/Settings/whatsappWebView
AccountProfiles/{profileId}/Settings/aiConnection
AccountProfiles/{profileId}/Settings/mcpServer
AccountProfiles/{profileId}/Settings/commandCenter
AccountProfiles/{profileId}/Settings/app
```

Firestore collection names must be PascalCase in this repo (for example `AccountProfiles`, `Settings`, `Chats`, `Messages`). Document IDs and setting scope names may remain lowerCamelCase when they represent keys/scopes (for example `whatsappCrawling`, `whatsappWebView`, `aiConnection`).

The intended runtime ownership is:

```text
ProfileRuntimeContainer
├── SettingsStore / ProfileSettings
│   ├── profileId
│   ├── scopesByName[name: SettingsScope]
│   ├── startListening()
│   ├── stopListening()
│   ├── scope(name)
│   ├── value(scope, key)
│   ├── setValue(scope, key, value)
│   └── deleteValue(scope, key)
│
└── ProfileRuntimeServiceRegistry
    ├── WhatsApp WebView service
    ├── WhatsApp Crawling/Polling service boundary
    ├── AI Connection service boundary
    └── MCP Server service boundary

└── ProfileRuntimeStatusRegistry
    ├── WhatsApp status provider
    ├── AI Connection status provider
    └── MCP Server status provider
```

`SettingsStore` is the only settings layer that talks to Firebase. It loads scope documents, listens to Firebase changes, updates the existing in-memory scope objects, exposes simple accessors to features, and saves key/value changes back to Firebase.

`SettingsStore` has an explicit async lifecycle. `ProfileRuntimeContainer` must start the store before starting any runtime services that read settings.

Startup:

- load all existing scopes once from Firebase
- apply them to the live in-memory scopes
- then start the Firebase listener for future changes

`SettingsStore` is a live in-memory store. Reads and writes are synchronous:

- wrappers read values from memory synchronously
- wrappers write values to memory synchronously (UI updates immediately)
- `SettingsStore` persists changes to Firebase in the background (typically debounced per scope)

### Profile runtime subservices

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

Runtime status rendering rules:

- Feature runtime status providers own status/action data.
- CommandCenter owns the shared compact visual rendering of header badges.
- Old hardcoded Runtime/Window/MCP header pills must not coexist with runtime status registry badges.
- Service state should appear as compact badges in the header, not duplicated large rows.

Repository methods remain async because they are the persistence boundary. Wrappers must not call `loadScope(...)` for normal setting reads and must not `await` setting writes.

Shutdown:

- stop the Firebase listener
- flush any pending debounced saves so recent UI changes are not lost

Remote snapshot protection:

- if a scope is locally dirty (pending save), the listener should not overwrite the in-memory scope with a potentially stale remote snapshot

`SettingsStore` is intentionally dumb: it stores only `String` values. It does not know feature types, and it does not own typed parsing, validation, or conversion. Feature settings wrappers own parsing, formatting, defaults, and validation.

`SettingsStore` and `SettingsScope` should be reference types. Swift structs are value types and are copied; they are fine for short-lived snapshots or default definitions, but they must not be treated as the live runtime source of truth. Features may keep a reference to a `SettingsScope` because the Settings feature updates that same object when Firebase changes.

The Settings feature owns settings screen composition through a small registry:

```text
SettingsSectionRegistry
├── SettingsSectionProvider
└── SettingsSectionDefinition
    ├── scopeName
    ├── title
    └── makeView
```

Each settings registration is a complete feature declaration: it names the settings scope, gives the section title, and supplies the view that renders the section body. The Settings feature owns the outer rendering, while feature-owned settings views render only the internal controls. The Settings screen renders registered sections in registration order; it does not become a giant hardcoded screen for every feature. Parent features can decide how to render subfeature settings conditionally because they understand their own subfeatures.

The source-of-truth rule is:

```text
Firebase = persisted source of truth
SettingsStore = live in-memory source of truth for the running profile
Feature settings wrappers = typed convenience only
```

Features must not create their own settings repositories. Features must not create feature-specific settings services just to load, cache, observe, or persist settings. Features must not copy settings into long-lived private variables and keep them stale. This project intentionally avoids service-per-feature settings boilerplate.

Feature-specific settings wrappers are allowed when they are typed convenience layers over the shared live `SettingsStore`. Prefer names like:

```text
WhatsAppCrawlingSettingsWrapper
ChatsSettingsWrapper
AIConnectionSettingsWrapper
```

Avoid names like:

```text
WhatsAppCrawlingSettingsService
WhatsAppCrawlingSettingsRepository
```

A feature settings wrapper may:

- keep a reference to the shared profile `SettingsStore`
- define scope names
- define key names
- define default values
- expose typed computed properties (Swift-style API)
- create or ensure generated technical values such as WebView session identifiers

A feature settings wrapper must not:

- create its own Firebase repository
- listen to Firebase directly
- keep long-lived copied setting values
- cache loaded settings as independent state
- become a second source of truth
- duplicate `SettingsStore` behavior

The wrapper can be instantiated inside `ProfileRuntimeContainer` and passed to that feature's runtime service. This is acceptable because it is only a typed wrapper over the live store, not an independently stateful service.

For simple settings features, prefer keeping the implementation small and local:

- `Wrapper.swift` (scope name, private keys, inline defaults, typed computed properties)
- `View.swift` (feature-owned inner controls only)
- `SectionProvider.swift` (registers the feature's settings scope/title/view)

Only split into additional `Keys.swift` / `Defaults.swift` files when the feature is large enough to justify it.

Correct feature usage:

```text
let scope = settings.scope("whatsappWebView")
read scope.string("url") when needed
read scope.string("enableWebInspector") when needed (then interpret it in the wrapper)
```

Correct typed wrapper usage:

```text
WhatsAppCrawlingSettingsWrapper receives SettingsStore
pollingIntervalSeconds reads settings.scope("whatsappCrawling").string("pollingIntervalSeconds")
pollingIntervalSeconds writes settings.setValue(scope:key:value:)
```

Incorrect feature usage:

```text
load settings once
store url/userAgent/interval in a feature service forever
listen to Firebase directly
duplicate SettingsRepository behavior
```

Feature settings declarations may exist later, but they are UI/schema declarations only. A feature can declare a scope name, section title, setting rows, default values, and validation rules. Persistence, observation, loading, saving, and live runtime state remain owned by the Settings feature.

The future Settings screen will concatenate settings sections declared by features. It will not turn those declarations into feature-owned repositories or long-lived cached services.

The Settings route inside CommandCenter renders the active profile runtime's `SettingsSectionRegistry`. CommandCenter does not own settings definitions; it only renders the registry supplied by the profile runtime container.

### WhatsApp Crawling Settings

WhatsApp Crawling registers one parent settings section with Settings. That section renders `WhatsAppCrawlingSettingsView`. The Settings feature does not register WebView and Native as independent top-level sections for now.

WhatsApp Crawling reads parent settings through `WhatsAppCrawlingSettingsWrapper`, which wraps the shared `SettingsStore` owned by its `ProfileRuntimeContainer`. It must not own a separate settings persistence service, Firebase listener, repository, or cache.

WhatsApp Crawling may define:

- scope names
- key names
- defaults
- a `WhatsAppCrawlingSettingsWrapper` with typed getters/setters that read and write through `SettingsStore`
- a feature-owned `WhatsAppCrawlingSettingsView`
- one `WhatsAppCrawlingSettingsSectionProvider`

General WhatsApp Crawling settings live in:

```text
AccountProfiles/{profileId}/Settings/whatsappCrawling
```

`whatsappCrawling` owns active integration, polling interval, access policy, and auto start. It does not own WebView-specific settings.

WebView integration settings live under `Sources/Features/WhatsAppCrawling/Integrations/WebView/Settings/` and persist in:

```text
AccountProfiles/{profileId}/Settings/whatsappWebView
```

`whatsappWebView` owns URL, user agent, zoom, viewport size, Web Inspector flag, and the stable profile-specific WebView data store identifier. The identifier is a generated technical setting; `WhatsAppWebViewSettingsWrapper` creates it once if missing and persists it through `SettingsStore`.

WhatsApp WebView can capture User-Agent from the default browser through a temporary localhost server. The capture server binds only to `127.0.0.1`, uses a random port and random token path, reads the incoming HTTP `User-Agent` header, returns a small close-page HTML, and stops immediately after handling capture flow completion. Captured User-Agent values are stored in the `whatsappWebView` settings scope.

An empty `whatsappWebView.userAgent` means no manual/captured value is currently stored. The user can manually refresh User-Agent from WebView settings, and optional auto-refresh can recapture after a configured day interval.

When WebView startup needs User-Agent capture (missing value or expired auto-refresh window), startup may block until capture returns. `BrowserUserAgentCaptureService` should resume as soon as a valid `User-Agent` header is received on the tokenized localhost URL; listener cleanup and browser tab/window close are best-effort and must not delay WebView startup.

Settings memory updates are synchronous in `SettingsStore`; Firebase persistence can happen later and must not block `WKWebView` creation/load after capture.

WebView integration injects a small global JavaScript bridge at document end through `WKUserScript` when the `WKWebView` is created. The bridge lives at `window.AssistantMCP` and currently exposes two generic functions:

- `extractTree(spec)` performs selector-driven DOM extraction for `web` and `flows` specs and returns clean JSON (`null`, object, array, string, number, boolean) without artificial wrappers such as `found/type/children`.
- `executeShortcut(shortcut)` dispatches global keyboard events (`keydown`/`keyup`) and is the foundation for YAML-defined shortcuts.

The bridge is generic and shared by both future Web debug screens and crawling orchestration.

Selector YAML files for WhatsApp Web live under `Resources/Selectors/Web`. The Web YAML Debug screen loads the bundled YAML, builds a generic extraction spec from `web`/`flows`, and executes it against the profile-owned `WKWebView` through `window.AssistantMCP.extractTree(spec)`.

Current debug output is intentionally the raw formatted JSON result. A recursive red/green visual tree may come later. Extraction output intentionally mirrors the YAML shape and avoids artificial metadata wrappers like `found/type/children`.

All of these settings are stored as strings in `SettingsStore`. The wrappers convert them to and from enums, integers, doubles, and booleans as needed. If parsing fails, the wrapper returns the feature default.

Native integration settings live under `Sources/Features/WhatsAppCrawling/Integrations/Native/Settings/` and persist in:

```text
AccountProfiles/{profileId}/Settings/whatsappNative
```

Native settings are intentionally minimal until the Accessibility runtime needs concrete configuration.

`WhatsAppCrawlingSettingsView` renders the parent settings first. It then renders integration-specific subsettings based on `activeIntegration`:

```text
activeIntegration == webView
└── WhatsAppWebViewSettingsView

activeIntegration == nativeAccessibility
└── WhatsAppNativeSettingsView
```

When WhatsApp Crawling needs a setting inside a service action, polling cycle, parser, or future orchestration step, it should read through the relevant wrapper, `SettingsStore`, or a live `SettingsScope` at that moment. Short-lived local snapshots inside a single operation are acceptable. Long-lived copied settings are not.

Examples:

- Good: each future polling cycle reads `pollingIntervalSeconds` before sleeping.
- Good: the wrapper reads `settings.scope("whatsappCrawling").string("pollingIntervalSeconds")` and converts it to `Int`.
- Good: the WebView service reads `url` and `userAgent` from `WhatsAppWebViewSettingsWrapper` when starting.
- Good: future setting changes are reflected by observing `SettingsStore` and restarting or reconfiguring runtime services.
- Bad: a `WhatsAppCrawlingSettingsService` loads `pollingIntervalSeconds` once and stores it forever.
- Bad: each WhatsApp integration creates its own Firebase listener.

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
│           │   └── CommandCenterScreen(profile, runtimeState, windowState)
│           │       ├── CommandCenterSidebar
│           │       │   └── CommandCenterMenuRegistry.sections()
│           │       └── CommandCenterContentView(selectedRoute)
│           │           └── CommandCenterScreenRegistry.screen(for: selectedRoute)
│           │               ├── MyProfileScreen
│           │               ├── IssuesPlaceholderScreen
│           │               ├── MemoriesPlaceholderScreen
│           │               ├── SensitiveDataPlaceholderScreen
│           │               ├── ClientVoicePlaceholderScreen
│           │               ├── ChatsPlaceholderScreen
│           │               ├── WhatsApp*PlaceholderScreen
│           │               ├── MCPServers*PlaceholderScreen
│           │               └── SettingsScreen
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

Start Profile controls service startup only. It starts the profile runtime container if needed, reads profile-scoped settings, and starts only subservices with their own autoStart enabled. It does not need to open the profile window.

Stop Profile controls service shutdown only. It stops all running subservices for that profile and does not necessarily close or hide the window. Hiding or closing the profile window only changes `ProfileWindowState`; it does not stop subservices.

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

### Command Center workspace

`CommandCenter` is the main visual workspace for one profile. It may be open while profile services are stopped. It is not the profile registry/list screen, and it does not own profile lifecycle, repositories, MCP startup, WhatsApp runtime startup, AI connection startup, or AppKit window creation.

The profile window composition is:

```text
AppWindowManager.showProfileWindow(profile)
└── ProfileWindowController
    └── ProfileWindowHostView(profileId, profilesController)
        ├── looks up Profile by profileId
        ├── reads runtime/window display state from ProfilesController
        └── CommandCenterScreen(profile, runtimeState, windowState)
            ├── owns selected CommandCenterRoute
            ├── renders CommandCenterSidebar
            │   └── sections/items from CommandCenterMenuRegistry
            ├── optionally renders CommandCenterHeaderView
            └── renders CommandCenterContentView
                └── CommandCenterScreenRegistry maps the route to the owning feature screen
```

Command Center owns:

- workspace layout
- sidebar sections and menu item rendering
- selected route state
- route-to-screen composition

Command Center does not own:

- feature content implementation
- profile persistence
- profile runtime lifecycle
- MCP server creation or service startup
- WhatsApp runtime creation
- AI provider execution
- settings persistence
- AppKit window management

The initial menu registry is static and intentionally small:

```text
My Data
├── My Profile -> Profiles/MyProfileScreen
├── Issues -> Issues/IssuesPlaceholderScreen
├── Memories -> Memories/MemoriesPlaceholderScreen
├── Sensitive Data -> SensitiveData/SensitiveDataPlaceholderScreen
└── Client Voice -> ClientVoice/ClientVoicePlaceholderScreen

WhatsApp Integration
├── Chats -> Chats/ChatsPlaceholderScreen
├── WebView -> WhatsAppCrawling/Integrations/WebView/Screens/WhatsAppWebViewScreen
├── Web YAML Debug -> WhatsAppCrawling/Integrations/WebView/Screens/WhatsAppWebYAMLDebugScreen
├── Native YAML Debug -> WhatsAppCrawling/Integrations/Native/Screens/WhatsAppNativeYAMLDebugPlaceholderScreen
└── Logs -> WhatsAppCrawling/WhatsAppLogsPlaceholderScreen

Server
├── Tools -> MCPServers/MCPToolsPlaceholderScreen
├── AI Connection -> AIConnection/AIConnectionPlaceholderScreen
└── Server Logs -> MCPServers/ServerLogsPlaceholderScreen

Settings
└── Settings -> Settings/SettingsScreen
```

The registry already has placeholder fields for developer-mode visibility and future visibility rules. The WhatsApp WebView route should eventually be visible only when the active integration is WhatsApp Web or when developer/debug mode allows it. YAML debug routes should probably become developer-mode only once the app has a developer-mode setting.

The current first route is `myProfile`. It renders `MyProfileScreen` from the Profiles feature and preserves the profile/runtime/window diagnostics that used to live in `ProfileWindowScreen`:

- profile name
- profile ID
- MCP port
- runtime state
- window state

`ProfileWindowScreen` may remain as a temporary compatibility wrapper around `MyProfileScreen`, but it is no longer the primary profile window content.

Future runtime dependency injection should flow from `ProfileRuntimeContainer` into the profile window/Command Center context. That container is expected to hold profile context, profile-scoped repositories, MCP server runtime, WhatsApp runtime, assistant loop, settings observer, logs/debug services, and AI connection/runtime services. Command Center should receive only the context needed to render the selected workspace screen; it should not construct those dependencies itself.

Settings remains a separate feature. Later, each feature can declare profile-scoped settings sections, and the Settings feature should own persistence plus rendering/composition into one unified settings UI. Features should not create independent settings repositories.

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

## Current tool surface

The registered tool list is assembled from `MCPToolProvider`s and registered via `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.

Each concrete tool definition lives under `Sources/Features/**/MCP/`.
Those Swift files are the source of truth for tool names, schemas, and descriptions.

The current tool groups are:

### Chats (WhatsApp tools)

- `list_chats_by_search`
- `list_unhandled_chats`
- `list_chat_messages`
- `send_message`
- `wait_for_event`

### Client voice tools

- `speak_to_client`
- `ask_to_client`

### Memory tools

- `create_memory`
- `get_memory`
- `search_memories`
- `list_memories`
- `delete_memory`

### Sensitive data tools

- `save_sensitive_data`
- `get_sensitive_data`
- `search_sensitive_data`
- `list_sensitive_data`
- `update_sensitive_data`
- `delete_sensitive_data`

### Issue tools

- `create_issue`
- `update_issue`
- `get_issue`
- `list_active_issues`
- `resolve_issue`
- `cancel_issue`

### Utility tools

- `get_assistant_name`
- `get_current_date`

When changing or documenting tool behavior, check the corresponding `*Tool.swift` implementation first.

## State model

The runtime keeps a local model of the assistant world:

- chats and chat history
- pending events and waits
- voice events
- memories
- sensitive data
- issues
- server logs and debug artifacts

That local state is what MCP serves, rather than re-parsing everything from scratch on every request.

## Polling and sync

At a high level, the runtime loop looks like this:

1. poll the WhatsApp integration surface
2. parse chat and message changes
3. update local repositories
4. refresh pending events and voice state
5. expose the resulting state through MCP

This is what makes the system feel more like a runtime than a thin server.

## Separation of concerns

The architecture now separates these conceptual concerns:

- runtime supervision
- MCP-facing actions
- WhatsApp integration
- social/humanization rendering
- persistence
- observability

That separation is important because the assistant now needs to behave differently depending on whether it is reasoning, speaking, replying, or only rendering a human-friendly message.

## LM Studio event stream

When the app talks to the model host using a streaming API, it can observe events such as:

- chat lifecycle events
- model loading events
- prompt processing events
- reasoning deltas
- tool call boundaries
- message deltas
- errors
- final response completion

That event stream is useful both for supervision and for future UI surfaces that show what the model is doing in real time.
This is planned work in the rewrite scaffold (the UI surfaces and supervision wiring are not fully implemented yet).

## Future shape

Likely next steps in the architecture are:

- a separate humanization pass after reasoning
- mobile/remote observability
- more formal session recovery
- stronger test orchestration around model and integration flows
