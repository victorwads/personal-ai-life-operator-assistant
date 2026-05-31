# Personal AI Life Operator

**Not an assistant. Your Personal AI Life Operator.**

A local-first SwiftUI macOS runtime for building a personal AI operator with durable memory, MCP tools, WhatsApp integration, task tracking, profile-aware state, and native desktop automation.

> Current V2 runtime lives under [Server/](./Server/).

## Status

This repository is in active transition and active development.

- The imported V2 runtime currently lives in [Server/](./Server/).
- The root of the repository still contains legacy workspace structure from the older project shape.
- The V2 is the main product direction and the clearest expression of the current architecture.

## Quick start

```sh
cd Server
./Scripts/check_build_and_restart.sh
```

If the app opens but cannot inspect or control WhatsApp, grant macOS Accessibility permission and relaunch it.

## Requirements

- macOS
- Xcode
- XcodeGen
- Swift toolchain compatible with the project
- Firebase configuration when working on Firebase-backed flows
- macOS Accessibility permission for WhatsApp automation flows
- Optional: a local or compatible AI provider such as LM Studio or an OpenAI-compatible API endpoint

## Build and run

The canonical local workflow for the V2 runtime is:

```sh
cd Server
./Scripts/check_build_and_restart.sh
```

That script is the expected developer entry point for the app lifecycle. It is the safest default because the repo treats generated Xcode project files as build output.

Notes:

- V2 currently uses capitalized `Scripts/`
- project configuration changes should go through `project.yml`, source files, scripts, or resources
- generated `.xcodeproj` content should not be edited manually

## Tech stack

- Swift
- SwiftUI
- macOS Accessibility APIs
- WebView integration
- MCP server and tool surface
- Firebase / Firestore
- XcodeGen
- local-first runtime architecture
- OpenAI-compatible and local model-provider integration

## What it does today

Based on the imported V2 runtime under [Server/](./Server/), the current codebase is centered around:

- profile-aware runtime architecture
- MCP tools and MCP server integration
- WhatsApp crawling, reading, and message sending
- issues and operational workflow tracking
- memories and sensitive-data handling
- settings and profile state
- tools browser and debug surfaces
- logs, runtime observability, and support tooling
- client voice and transcription-related evolution paths

## Architecture summary

The runtime is macOS-first and intentionally local-first.

High-level responsibilities:

1. keep local workflow and memory state
2. expose structured actions through MCP
3. supervise model sessions and app-side integrations

In practice, the Swift app owns persistence, orchestration, UI, Accessibility integration, and tool execution. A local or compatible model host connects to those capabilities instead of trying to own durable state by itself.

## Project layout

- [Server/](./Server/) - the V2 macOS runtime and primary codebase
- [Server/Sources/](./Server/Sources/) - app, features, infrastructure, and shared UI/runtime code
- [Server/Resources/](./Server/Resources/) - prompts, selectors, plist/config resources, and assets
- [Server/Scripts/](./Server/Scripts/) - build and lint helpers for the V2 runtime
- [Server/Docs/](./Server/Docs/) - architecture, tests, and integration notes
- [Apps/](./Apps/) - companion app workspace content
- [Web/](./Web/) - web-side workspace content

## Why "Life Operator"

`Personal AI` makes it clear that this is your own AI layer.

`Life Operator` is the distinction that matters: this project is not trying to be another Siri, Alexa, or thin chat UI. It is meant to operate across ongoing human workflows such as:

- reading and organizing conversations
- tracking pending work and commitments
- maintaining memories and context
- asking follow-up questions when needed
- helping with voice-driven capture and action

That is why the project is positioned as a personal AI operator, not just an assistant.

## Key docs

Start here if you want to understand or extend the system:

- [Server/AGENTS.md](./Server/AGENTS.md) - working rules for agents and contributors
- [Server/Docs/Architecture.md](./Server/Docs/Architecture.md) - global architecture and runtime model
- [Server/Docs/Tests.md](./Server/Docs/Tests.md) - intended testing strategy
- [Server/Docs/WhisperBackendIntegration.md](./Server/Docs/WhisperBackendIntegration.md) - planned local transcription backend integration
- [Server/Sources/Shared/UI/Architecture.md](./Server/Sources/Shared/UI/Architecture.md) - shared UI design guidance

## Keywords

Personal AI, AI Life Operator, Life Operator, AI Operator, local-first AI, local AI, agentic AI, AI agent, LLM agent, tool calling, MCP server, Swift, SwiftUI, macOS, WhatsApp automation, Accessibility API, memory management, task management, personal automation, privacy-first AI, on-device AI.
