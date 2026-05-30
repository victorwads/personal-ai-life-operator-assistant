# MCP Servers Architecture

This document owns MCP server composition, tool registry boundaries, and the current tool surface index.

## Current tool surface

The registered tool list is assembled from concrete tool instances that conform to `MCPToolDefinition` and stored by `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.

Each concrete tool lives under `Sources/Features/**/MCP/`.
Those Swift files are the source of truth for tool names, schemas, descriptions, and execution behavior.
Tool grouping is a plain string owned by the feature that instantiates the tool.

## Tools Browser integration

The Tools Browser UI lives in `Sources/Features/ToolsBrowser/` and consumes MCP Servers through public `MCPServersFeature` APIs.

`MCPServersFeature` exposes:

- `listToolDefinitions()`
- `executeToolCall(_:)`

`executeToolCall(_:)` is backed by `Runtime/MCPToolExecutor.swift`, which is the official manual tool execution path.
Tool definitions are never executed directly from UI/ViewModel code.

The executor owns the centralized execution pipeline and is the insertion point for future guardrails such as schema validation, permissions, and audit logging.

The current tool groups are:

### Chats (read-only tools)

- `list_chats_by_search`
- `list_unhandled_chats`
- `list_chat_messages`
- `send_message`
- `wait_for_event`

### Client voice tools

- `speak_to_client`
- `ask_to_client`

### Memory tools

- `create_memory`
- `get_memory`
- `search_memories`
- `list_memories`
- `delete_memory`

### Sensitive data tools

- `save_sensitive_data`
- `get_sensitive_data`
- `search_sensitive_data`
- `list_sensitive_data`
- `update_sensitive_data`
- `delete_sensitive_data`

### Issue tools

- `create_issue`
- `update_issue`
- `get_issue`
- `list_active_issues`
- `resolve_issue`
- `cancel_issue`

### Utility tools

- `get_current_datetime`

## Ownership updates

- `get_current_datetime` is the only date/time utility owned by `MCPServersFeature`.
- `get_assistant_name` is owned and registered by `SentMessagesFeature`.
- `wait_for_event` is deferred runtime/orchestration work and is not registered by `ChatsFeature`.
- `send_message` remains a deferred transport placeholder; real sending stays channel-owned and will be added later.

When changing or documenting tool behavior, check the corresponding `*Tool.swift` implementation first.
