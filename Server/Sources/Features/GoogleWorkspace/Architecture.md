# Google Workspace Architecture

This folder owns Google Workspace settings, OAuth credentials flow, token lifecycle, direct Google API clients, feature screens, and MCP tools.

## Responsibilities

`GoogleWorkspace` is responsible for:
- Settings: storing Client ID, Client Secret, and redirect port inside `SettingsStore`.
- OAuth Flow: implementing the authorization code flow, spawning a local socket listener on redirectPort, receiving the callback code, exchanging it for access and refresh tokens, and writing credentials to settings.
- Token Store: loading and persisting tokens, managing access token expiration, and refreshing expired tokens automatically using the refresh token.
- API Services:
  - `GmailService`: retrieves recent inbox messages and maps metadata headers (From, To, Subject, Date).
  - `GoogleCalendarService`: lists upcoming events from the user's primary calendar.
  - `GoogleContactsService`: queries and local-searches contacts from the People API connections endpoint.
- MCP Tools:
  - `list_gmail_emails`
  - `list_calendar_events`
  - `search_google_contacts`
  - `google_workspace_auth_status`

## OAuth Redirect Server

The `GoogleOAuthLocalRedirectServer` spawns a temporary `NWListener` from Apple's Network framework.
- It binds to loopback interface `127.0.0.1` and the user-specified `redirectPort`.
- It accepts a connection, parses the query string for `code` and `state`, validates that the state matches the generated state, returns a lightweight HTTP response page, and immediately shuts down.
- A timeout task (default 60 seconds) ensures the listener stops even if the user cancels or closes their browser.

## Clean API Client and Refresh Logic

The `GoogleWorkspaceHTTPClient` wraps standard `URLSession` data tasks:
- Injects `Authorization: Bearer <token>` automatically.
- Sanitizes logs by redacting client secrets, authorization codes, and token strings.
- Intercepts HTTP 401 response and triggers a token refresh attempt. If refresh succeeds, the client retries the failed API call once.
- Returns clear, readable errors for common failure cases (missing configuration, invalid auth code, token expired, etc.).
