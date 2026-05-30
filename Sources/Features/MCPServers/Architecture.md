# MCP Servers Architecture

This document owns MCP server composition, tool registry boundaries, and the current tool surface index.

## Current tool surface

The registered tool list is assembled from concrete tool instances that conform to `MCPToolDefinition` and stored by `Sources/Features/MCPServers/Registry/MCPToolRegistry.swift`.

Each concrete tool lives under `Sources/Features/**/MCP/`.
Those Swift files are the source of truth for tool names, schemas, descriptions, and execution behavior.
Tool grouping is a plain string owned by the feature that instantiates the tool.

The current tool groups are:

### Chats (WhatsApp tools)

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

- `get_assistant_name`
- `get_current_date`

When changing or documenting tool behavior, check the corresponding `*Tool.swift` implementation first.
