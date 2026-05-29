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

A local inference host remains the inference engine (LM Studio is one option). The Swift app is the runtime, supervisor, and integration layer.

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

## Multi-profile motivation

Multi-profile support exists because the runtime can host more than one assistant on the same Mac.

In practice:

- the local model instance can stay loaded in memory
- WhatsApp polling and state sync are usually the main background cost
- different people receive messages at different times, so inference load tends not to spike constantly

This enables hosting assistants for family members (for example: partner, mother) on a single machine, while exposing a UI (and future mobile UI) so those users can manage memories, issues, and state without local access to LM Studio.

## Local architecture documents

Feature- and infrastructure-specific architecture rules live close to the code they govern:

- [Sources/App/Architecture.md](../Sources/App/Architecture.md)
- [Sources/Infrastructure/Firebase/Architecture.md](../Sources/Infrastructure/Firebase/Architecture.md)
- [Sources/Features/AIConnection/Architecture.md](../Sources/Features/AIConnection/Architecture.md)
- [Sources/Features/Settings/Architecture.md](../Sources/Features/Settings/Architecture.md)
- [Sources/Features/Profiles/Architecture.md](../Sources/Features/Profiles/Architecture.md)
- [Sources/Features/CommandCenter/Architecture.md](../Sources/Features/CommandCenter/Architecture.md)
- [Sources/Features/Issues/Architecture.md](../Sources/Features/Issues/Architecture.md)
- [Sources/Features/MCPServers/Architecture.md](../Sources/Features/MCPServers/Architecture.md)
- [Sources/Features/WhatsAppCrawling/Architecture.md](../Sources/Features/WhatsAppCrawling/Architecture.md)
- [Sources/Features/Chats/Architecture.md](../Sources/Features/Chats/Architecture.md)

Keep this file as the global index and move detailed rules into the nearest local `Architecture.md` instead of replacing them with short summaries.

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

## Separation of concerns

The architecture now separates these conceptual concerns:

- runtime supervision
- MCP-facing actions
- WhatsApp integration
- social/humanization rendering
- persistence
- observability

That separation is important because the assistant now needs to behave differently depending on whether it is reasoning, speaking, replying, or only rendering a human-friendly message.
## Future shape

Likely next steps in the architecture are:

- a separate humanization pass after reasoning
- mobile/remote observability
- more formal session recovery
- stronger test orchestration around model and integration flows
