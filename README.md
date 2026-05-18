# AssistantMCPServer

Local macOS assistant runtime that combines a native SwiftUI app, Accessibility-driven control, an embedded MCP HTTP server, and LM Studio session supervision.

The project started as a local MCP server for WhatsApp Desktop.
It now behaves more like a local assistant runtime: it owns state, tools, orchestration, and the integration surfaces that the model uses to work.
The repo is evolving toward a `Personal Assistant Runtime` identity, with WhatsApp as the first major integration surface.

## What It Is

This is a native macOS assistant runtime, not just a server process. It:

- reads the WhatsApp Accessibility tree and WebView state
- keeps local persistent state for chats, memories, subjects, nicknames, and sensitive data
- exposes those capabilities through an MCP server on `http://localhost:8080/mcp`
- supervises LM Studio sessions and assistant lifecycle
- provides SwiftUI screens for logs, settings, debug views, and manual control

The long-form story lives in [Docs/History.md](./Docs/History.md).
The system layout lives in [Docs/Architecture.md](./Docs/Architecture.md).
The current capability summary lives in [Docs/Features.md](./Docs/Features.md).

## Current Focus

- WhatsApp discovery, reading, and sending
- client voice workflows
- memory and sensitive-data management
- subject tracking for operational work
- LM Studio session supervision
- runtime observability and debug tooling

The backlog is maintained in [Docs/Backlog.md](./Docs/Backlog.md).

## Build And Run

The canonical local workflow is:

```sh
./scripts/check_build_and_restart.sh
```

That script:

- sanitizes Swift file endings
- regenerates the Xcode project with `xcodegen`
- builds the Debug app
- closes old app instances
- opens the freshly built app

If you only want to regenerate the project file:

```sh
xcodegen generate
```

If you want to open the generated project in Xcode:

```sh
open AssistantMCPServer.xcodeproj
```

## MCP Client

The app shows a ready-to-copy client snippet in Settings.

Default shape:

```toml
[mcp_servers.assistant_whatsapp]
enabled = true
url = "http://localhost:8080/mcp"
```

If you change the port in the app settings, update the client URL to match.

## Accessibility

The app depends on macOS Accessibility permission to inspect and control WhatsApp Desktop.

If the UI says Accessibility is not trusted:

1. Open the app
2. Grant Accessibility permission in System Settings
3. Quit and relaunch the app
4. Refresh the chat list or debug tree

macOS grants permission to the exact app binary, so the identity may matter after rebuilds.

## Contributing

- Keep changes native and local-first.
- Prefer Accessibility semantics over screen coordinates.
- Keep MCP tool names stable once clients depend on them.
- Update the docs when the runtime architecture changes.
- Add backlog items before larger work so the plan stays visible.

## Repository Layout

- [Sources/](./Sources/) - app code, runtime, tools, integrations, repositories, and UI
- [scripts/](./scripts/) - build and maintenance scripts
- [Docs/Backlog.md](./Docs/Backlog.md) - running list of planned work and dependencies
- [Docs/History.md](./Docs/History.md) - narrative history of the project
- [Docs/Architecture.md](./Docs/Architecture.md) - current architecture and runtime model
- [Docs/Features.md](./Docs/Features.md) - feature summary and current capabilities

## Roadmap

The next major steps are:

- LM Studio control from inside the app
- post-tool humanization as a separate pass
- remote/mobile observability and control
- richer session supervision
- automated integration tests

These are tracked in the backlog and documented in the companion docs.
