# MCP Servers Architecture

This document owns MCP server composition, tool registry boundaries, and the current tool surface index.

## Current tool surface

The registered tool list is assembled from concrete tool instances that conform to `MCPToolDefinition` and stored by `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.

Each concrete tool lives under `Sources/Features/**/MCP/`.
Those Swift files are the source of truth for tool names, schemas, descriptions, and execution behavior.
Tool grouping is a plain string owned by the feature that instantiates the tool.

## Tools Browser

`Sources/Features/MCPServers/Screens/MCPToolsScreen.swift` is a developer/debug UI for inspecting and manually executing registered MCP tool instances.
Command Center passes the active profile runtime's `MCPToolRegistry` into the screen, so the browser reflects the profile-scoped tools that features registered at runtime.

The browser works with existing `any MCPToolDefinition` instances from `MCPToolRegistry.allDefinitions()`.
It may display metadata, input schemas, examples, argument drafts, payload previews, and execution results, but it must not instantiate tools, repositories, providers, handlers, or MCP server transports.
Manual execution calls the selected tool's `execute(_:context:)` method directly with an `MCPToolCall` and a minimal `MCPServerContext`; it does not make a real MCP server request.

The browser should reuse shared visual primitives from `Sources/Shared/UI/` for repeated presentation patterns such as cards, badges, and code blocks.
Do not rebuild local MCP-only versions of these generic visual helpers unless the feature has a clear presentation need that cannot be satisfied by the shared primitive.
Its master-detail structure should remain based on `NavigationSplitView`, with the left pane owning search, filtering, and selection while the right pane renders selected tool details.

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
