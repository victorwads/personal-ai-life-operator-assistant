# Sensitive Data Architecture

Sensitive Data stores profile-scoped protected values for the assistant runtime.
It is not a general memory system and should only hold values that require a more restricted access path than normal memories.

## MCP access rules

- `get_sensitive_data` is the only Sensitive Data MCP tool that may return the actual stored value.
- `list_sensitive_data` and `search_sensitive_data` must return safe metadata only and must never return the protected value.
- Every Sensitive Data MCP tool requires `issueId` and `reason` through its input schema.
- Shared MCP validation already owns required-field, unknown-field, type, enum, and active-`issueId` validation.
- Sensitive Data tools should keep domain/security behavior local and avoid duplicating shared validator logic.

## Audit and deletion rules

- `issueId` is validated centrally by `MCPIssueIdValidator`.
- `reason` explains why the assistant needs to access or change the protected value.
- Every `save`, `get`, `list`, `search`, `update`, and `delete` action must create a `SensitiveDataUsage` audit entry.
- Delete is soft delete and must preserve prior audit history.
- Deleted items must not appear in normal `get`, `list`, or `search` results.
- Usage audit history is preserved even when the corresponding sensitive value is later deleted.
