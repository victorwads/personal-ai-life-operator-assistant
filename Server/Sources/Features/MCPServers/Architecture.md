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

## Validation pipeline

`MCPToolExecutor` is the only official tool execution path for:

- Tools Browser manual execution
- future AI Connection tool-calling execution
- future tests/integration flows that execute tool calls

Execution flow:

1. Resolve tool definition from `MCPToolRegistry`.
2. Build `MCPToolValidationContext`.
3. Run all validators from `Validation/` (`MCPToolCallValidator`) before execution (concurrently).
4. Aggregate all validation failures from all validators.
5. Sort errors deterministically (validator registration order, then fieldPath, validatorName, message, suggestedAction).
6. If any validation errors exist, block execution and return all of them together.
7. If all validators pass, execute the tool definition.

Rules:

- Validators are registered in order, but validation work may run concurrently.
- Any validation error blocks tool execution.
- Validation failures are aggregated and returned together (no short-circuit on first error).
- Validation errors retain debug metadata (`toolName`, `validatorName`, `fieldPath`) for logs/diagnostics.
- All `MCPToolValidationError` fields are required: `message`, `suggestedAction`, `fieldPath`, `validatorName`, `toolName`.
- AI-facing validation output exposes only `message` and `suggestedAction`.
- Use `fieldPath: "$"` for root-level/call-level validation errors; use direct paths like `issueId`, `messages[0]`, or `arguments` for field-specific errors.
- Validators must always provide a non-empty `suggestedAction` that tells the AI how to fix the tool call.
- `MCPToolExecutor.execute(_:)` should remain small; validation orchestration belongs in private helper methods.
- Tool definitions should not duplicate shared, generic validation concerns.
- `MCPServersFeature` currently registers `MCPIssueIdValidator` as a shared pre-execution validator.

Registered validator order:

1. `MCPRequiredFieldsValidator`
2. `MCPUnknownFieldsValidator`
3. `MCPArgumentTypeValidator`
4. `MCPEnumValidator`
5. `MCPIssueIdValidator`

### Schema-based validators

- `MCPRequiredFieldsValidator` reads required fields from each tool schema and rejects missing or `null` required values.
- `MCPUnknownFieldsValidator` rejects arguments that are not declared in the schema properties.
- `MCPArgumentTypeValidator` validates present argument types against schema property `type` values.
- `MCPEnumValidator` validates string enum fields declared directly in each property schema under `inputSchema.properties.<field>.enum`.
- Validators aggregate all validation errors before tool execution is blocked.
- `fieldPath: "$"` indicates a root-level validation error, such as malformed tool schema metadata.
- Shared validators centralize generic checks so tools can eventually stop duplicating generic parsing guards.
- `inputSchema` is the single source of truth for required-field/type/unknown-field/enum validation.
- Tool implementations should not duplicate generic required/type/unknown/enum/issueId validation already owned by validators.
- Tool implementations still own feature/domain validation (state transitions, repository/domain existence checks, permission/security rules, and domain-specific semantics).
- Reusable MCP extraction/schema helpers belong in `Sources/Features/MCPServers/Support/`.
- Feature MCP support files should stay focused on feature-specific payload mapping and domain helper logic.

### `MCPIssueIdValidator`

- Validates only the exact `issueId` argument key (not aliases such as `issue_id`).
- Runs before tool execution and blocks execution when validation fails.
- Allows calls with no `issueId` argument to proceed unchanged.
- Requires `issueId` to be a non-empty string.
- Resolves `IssuesFeature` lazily through a provider closure only when `issueId` is present.
- Uses `IssuesFeature` validation APIs and never reaches repositories through `MCPServerContext`.
- Returns standardized actionable validation errors for missing/invalid/inactive issue references.
- Treats missing, invalid, resolved, cancelled, and finished issues as invalid/inactive for tool execution.

The current tool groups are:

### Chats (read-only tools)

- `list_chats`
- `list_chats_by_search`
- `list_unhandled_chats`
- `list_chat_messages`
- `wait_for_event`

### Sent Messages tools

- `send_message`

### Client voice tools

- `speak_to_client`
- `ask_to_client`

### Memory tools

- `create_memory`
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
- `send_message` is owned and registered by `SentMessagesFeature`.
- `wait_for_event` is deferred runtime/orchestration work and is not registered by `ChatsFeature`.
- `send_message` is owned and registered by `SentMessagesFeature`, executed through the shared MCP validator pipeline, and backed by SentMessages audit plus WhatsAppCrawling transport.

Current `send_message` execution flow:

```text
send_message
→ MCP validators
→ SentMessages formatting
→ SentMessages pending audit
→ WhatsAppCrawling transport send
→ observed chat message ids
→ SentMessages final status update
→ MCP result payload
```

When changing or documenting tool behavior, check the corresponding `*Tool.swift` implementation first.
