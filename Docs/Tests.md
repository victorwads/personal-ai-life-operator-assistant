# Tests

This document describes the intended testing architecture for this repo and codifies the expected behavior around conversation access control (allow/deny).

## Layers

### Unit tests ("pure rules")

Goal: validate policy and contract behavior without external IO.

Examples:

- Conversation access policy semantics (`allowAllExceptDeny` vs `denyAllExceptAllow`)
- Tool response shape (keys, required fields, compatibility aliases like `chatId` vs `chat_id`)
- Deterministic formatting/normalization rules (search scoring, pruning nulls, etc.)

These tests should avoid heavy mocking. Prefer:

- in-memory domain objects (`ConversationSummary`, `Message`, `ChatState`)
- calling tool handlers directly (`SomeTool.handle(MCPToolCall, context:)`)

### Repository-backed tests (real repositories, controlled storage)

Goal: validate persistence and migrations using the real repository implementations, but with isolated storage.

Preferred storage strategy:

- use `UserDefaults(suiteName:)` with a random per-test suite name
- clear the persistent domain in `setUp`/factory helpers

We avoid fake repositories because they tend to drift from production behavior.

## Conversation Access Contract

### Modes

- `allowAllExceptDeny`:
  - chats are allowed by default
  - a chat is blocked only if its name is present in the deny list

- `denyAllExceptAllow`:
  - chats are blocked by default
  - a chat is allowed only if its name is present in the allow list

### Expectations

- MCP tools must not return blocked chats or messages for blocked chats.
  - This applies to list-like tools such as `list_chats`, `list_unread_chats`, `list_chats_by_search`, `list_recent_messages`, and the wait tools.
- Polling must not open blocked chats to fetch messages.
  - Blocking should prevent `openConversation` for that chat in the integration layer.
- UI can still present full conversation lists depending on the screen.
  - The operational rule is about what the assistant/runtime is allowed to act on (polling + MCP surface), not necessarily what the UI can display.

### Current Coverage

- Pure rule: `AppModel.isBlocked` semantics are covered in `Tests/Unit/ConversationAccessPolicyTests.swift`.
- Repository-backed: persistence is covered in `Tests/Unit/Repository/ConversationAccessRepositoryTests.swift`.
- Polling behavior: blocked chats are filtered before message loading in `Tests/Unit/WhatsAppPollingOrchestratorAccessTests.swift`.
