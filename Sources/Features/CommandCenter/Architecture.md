# Command Center Architecture

This document owns Command Center workspace layout, routing, screen composition, and shared status badge rendering.

Runtime status rendering rules:

- Feature runtime status providers own status/action data.
- CommandCenter owns the shared compact visual rendering of header badges.
- Old hardcoded Runtime/Window/MCP header pills must not coexist with runtime status registry badges.
- Service state should appear as compact badges in the header, not duplicated large rows.

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
├── Issues -> Issues/IssuesScreen
├── Memories -> Memories/MemoriesScreen
├── Sensitive Data -> SensitiveData/SensitiveDataScreen
└── Client Voice -> ClientVoice/ClientVoiceScreen

WhatsApp Integration
├── Chats -> Chats/ChatsScreen
├── WebView -> WhatsAppCrawling/Integrations/WebView/Screens/WhatsAppWebViewScreen
├── Web YAML Debug -> WhatsAppCrawling/Integrations/WebView/Screens/WhatsAppWebYAMLDebugScreen
├── Native YAML Debug -> WhatsAppCrawling/Integrations/Native/Screens/WhatsAppNativeYAMLDebugScreen
└── Logs -> WhatsAppCrawling/Screens/WhatsAppLogsScreen

Server
├── Tools -> MCPServers/MCPToolsScreen
├── AI Connection -> AIConnection/AIConnectionScreen
└── Server Logs -> MCPServers/ServerLogsScreen

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

Command Center should receive explicit feature runtimes such as `SettingsFeature`, `MemoriesFeature`, and `WhatsAppCrawlingFeature` instead of loose repositories, services, or stores.

Feature screens rendered by Command Center should receive their owning feature runtime and read any feature-owned internals through that runtime.

Settings remains a separate feature. Later, each feature can declare profile-scoped settings sections, and the Settings feature should own rendering/composition into one unified settings UI while the shared settings substrate remains in `Sources/Shared/Settings`.
