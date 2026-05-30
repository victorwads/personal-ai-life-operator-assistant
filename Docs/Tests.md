# Tests

This document describes the intended testing architecture for this repo.

Note: the rewrite scaffold currently has minimal test coverage. Prefer keeping this document aspirational but consistent with the current codebase (avoid referencing files/types that do not exist in this repo yet).

## Layers

### Unit tests ("pure rules")

Goal: validate policy and contract behavior without external IO.

Examples:

- Tool response shape (keys, required fields, compatibility aliases like `chatId` vs `chat_id`)
- Deterministic formatting/normalization rules (search scoring, pruning nulls, etc.)

These tests should avoid heavy mocking. Prefer:

- in-memory domain objects (for example: `Chat`, `ChatMessage`, `Issue`, `Memory`)
- calling tool handlers directly (`SomeTool.handle(MCPToolCall, context:)`)

### Repository-backed tests (real repositories, controlled storage)

Goal: validate persistence and migrations using the real repository implementations, but with isolated storage.

Preferred storage strategy:

- use `UserDefaults(suiteName:)` with a random per-test suite name
- clear the persistent domain in `setUp`/factory helpers

We avoid fake repositories because they tend to drift from production behavior.

## Current coverage (today)

- Basic normalization behavior is covered by `Tests/AIAssistantHubTests/AIAssistantHubTests.swift` (example: `ChatIdGenerator`).

As more wiring lands (repositories, tool execution, storage), expand coverage following the layers above.
