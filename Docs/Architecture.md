# Architecture

This document explains the intended architecture for the assistant runtime and how the major pieces fit together.

This repo is in the middle of a rewrite-from-scratch, so some sections describe the target shape while the current codebase still contains scaffolding.

## Current status (rewrite scaffold)

- MCP tool *definitions* exist under `Sources/Features/**/MCP/`, registered via `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.
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
3. inspect active subjects and pending work
4. wait for new events or unread messages
5. read recent messages for the specific chat or event
6. update subjects, memories, nicknames, or sensitive-data references when needed
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

This enables hosting assistants for family members (for example: partner, mother) on a single machine, while exposing a UI (and future mobile UI) so those users can manage memories, subjects, and state without local access to LM Studio.

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
│       │   ├── runningProfiles[profileId: ProfileRuntime]
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
│       │   │   └── finds/creates ProfileRuntime and calls runtime.start()
│       │   │
│       │   ├── stopProfile(profileId)
│       │   │   └── finds ProfileRuntime and calls runtime.stop()
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
├── if runtime already exists in runningProfiles[profileId]
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
    ├── runningProfiles[profileId] = runtime
    └── runtime.start()
```

The controller-level methods are intentionally allowed and useful:

```text
ProfilesController.startProfile(profileId)
└── runtime.start()

ProfilesController.stopProfile(profileId)
└── runtime.stop()

ProfilesController.openProfileWindow(profileId)
└── runtime.openWindow()

ProfilesController.hideProfileWindow(profileId)
└── runtime.hideWindow()
```

These are semantic shortcuts for UI and tray surfaces. They should perform lookup and delegation. The real per-profile behavior belongs to `ProfileRuntime`.

### Profile window lifecycle

The intended `openWindow` flow inside a runtime is:

```text
ProfileRuntime.openWindow()
├── ensures runtime is running
├── calls windowManaging.showProfileWindow(profile)
│   └── AppWindowManager.showProfileWindow(profile)
│       ├── if window already exists in profileWindows[profileId]
│       │   └── makeKeyAndOrderFront()
│       │
│       └── if window does not exist
│           ├── creates ProfileWindowController(profileId)
│           ├── creates ProfileWindowHostView(profileId)
│           │   └── ProfileWindowScreen(profileId)
│           ├── stores it in profileWindows[profileId]
│           ├── shows window
│           └── WindowVisibilityTracker.windowDidShow(profileId)
│               └── DockVisibilityController.refresh()
│
└── runtime.windowState = visible
```

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
ProfileRuntime.stop()
├── hideWindow()
├── stops future tasks
├── stops future MCP server
├── stops future WhatsApp runtime
├── cancels future assistant loop
├── runtime.state = stopped
└── ProfilesController removes it from runningProfiles or keeps it as stopped
```

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
ProfileWindowScreen is only visual content.
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
- subjects
- nicknames
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
