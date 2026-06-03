# WhatsApp Crawling Architecture

This document owns WhatsApp Crawling settings, WebView integration, selector YAML, extraction bridge, and interactive element rules.

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

Web YAML Debug currently provides both a raw formatted JSON view and a recursive red/green tree view. Extraction output intentionally mirrors the YAML shape and avoids artificial metadata wrappers like `found/type/children`.

YAML nodes may mark element selectors as interactive with `interactive: true`. Interactive nodes return minimal element handles in extraction results: `{ "$element": true, "id": "..." }`.

Interactive handles are valid only for the latest `extractTree` snapshot. The JavaScript bridge keeps an internal DOM element registry and rebuilds it on each extraction call.

Swift-side interaction uses `WebViewElementInteractor`, which calls `window.AssistantMCP.interactWithElement(id, action, payload)` for actions like click/focus/type/pressEnter. The debug tree can show action buttons for interactive handles.

Extraction JSON remains clean; it does not include debug metadata beyond explicit interactive element handles.

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

## Polling and sync

At a high level, the runtime loop looks like this:

1. poll the WhatsApp integration surface
2. parse chat and message changes
3. update local repositories
4. refresh pending events and voice state
5. expose the resulting state through MCP

When parsing the WhatsApp chat list, crawling stores the visual list order as `Chat.listOrder`. This value represents the order observed in the WhatsApp chat list during crawling. It is not yet used for sorting in this change.

This is what makes the system feel more like a runtime than a thin server.

### Startup warm cycles

When `WhatsAppCrawlingPollingService` starts from a stopped state, the first few completed polling cycles force crawling of all visible chats, ignoring the normal refresh skip rules (`stateHash`, unread count, or existing chat presence).

This is intended to warm WhatsApp Web state: during early startup, opening a chat may initially show an incomplete set of visible/recent messages. Forcing multiple early cycles reduces the risk of persisting an incomplete message list from a single early pass.

After the warm cycle window (currently 5 completed cycles), the crawler returns to the normal refresh rules (`stateHash` change, unread count, or new chat).

## Ownership boundary

- WhatsAppCrawling owns transport-specific WhatsApp Web interaction, crawling, parsing, and persisted chat/message observation.
- SentMessages owns outbound audit history, assistant outbound identity settings, and the `send_message` MCP tool.
- Chats owns persisted chat/message data plus read/listing tools.
- WhatsAppCrawling now owns the real WebView transport-specific send behavior and outbound message observation.
- SentMessages will call WhatsAppCrawling to send and observe outbound messages, while WhatsAppCrawling continues to own only the transport-specific interaction and observation behavior.

## Public send contract

WhatsAppCrawling exposes a feature-level message sending contract for future outbound transport:

- `WhatsAppMessageSending`
- `WhatsAppMessageSendRequest`
- `WhatsAppMessageSendResult`
- `WhatsAppMessageSendReceipt`
- `WhatsAppMessageSendingError`

`WhatsAppCrawlingFeature.messageSender` is the entrypoint SentMessages should depend on for outbound WhatsApp transport.

Current runtime behavior is:

- sending pauses crawling, but does not tear down or pause the underlying WebView
- sending remains transport-specific to WhatsAppCrawling
- one request may send multiple messages to the same chat
- after send actions complete, WhatsAppCrawling waits until the messages appear in the active chat view
- successful observation returns the observed chat message ids in `WhatsAppMessageSendReceipt`
- crawling resumes afterward, including when sending fails
- if some messages are not observed, the send API returns a partial result with missing receipt ids instead of inventing ids
- SentMessages owns outbound audit/status records; WhatsAppCrawling only sends and observes
