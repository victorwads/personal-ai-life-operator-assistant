# Tests

This document describes the intended testing architecture for this repo.

Note: the rewrite scaffold currently has minimal test coverage. Prefer keeping this document aspirational but consistent with the current codebase. Avoid referencing files or types that do not exist in this repo.

## Layers

### Unit tests ("pure rules")

Goal: validate policy and contract behavior without external IO.

Examples:

- Tool response shape with keys, required fields, and compatibility aliases such as `chatId` vs `chat_id`
- Deterministic formatting and normalization rules such as search scoring and pruning nulls

These tests should avoid heavy mocking. Prefer:

- in-memory domain objects such as `Chat`, `ChatMessage`, `Issue`, and `Memory`
- calling tool handlers directly such as `SomeTool.handle(MCPToolCall, context:)`

### Repository-backed tests (real repositories, controlled storage)

Goal: validate persistence and migrations using the real repository implementations, but with isolated storage.

Preferred storage strategy:

- use `UserDefaults(suiteName:)` with a random per-test suite name
- clear the persistent domain in setup and factory helpers

We avoid fake repositories because they tend to drift from production behavior.

## Current coverage (today)

- Basic normalization behavior is covered by `Server/Tests/AIAssistantHubTests/AIAssistantHubTests.swift`.

As more wiring lands for repositories, tool execution, and storage, expand coverage following the layers above.
