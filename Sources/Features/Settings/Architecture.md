# Settings Architecture

This document owns profile-scoped settings state, wrappers, and settings UI composition rules.

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
