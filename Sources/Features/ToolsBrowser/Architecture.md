# Tools Browser Architecture

Tools Browser is a developer/debug feature for browsing registered MCP tools and executing calls manually.

## Ownership boundary

- Tools Browser owns only the UI, view model, and local presentation models for tool browsing/testing.
- MCP Servers owns tool registration, executor pipeline, and concrete tool execution.

## Execution rule

Tools Browser must not call `tool.execute(...)` directly.

Manual execution must follow this flow:

1. Tools Browser creates an `MCPToolCall`.
2. Tools Browser calls `MCPServersFeature.executeToolCall(_:)`.
3. `MCPServersFeature` routes to `MCPToolExecutor`.
4. `MCPToolExecutor` resolves the tool from `MCPToolRegistry` and executes it.

This keeps manual testing, UI-driven execution, and future AI/LLM-driven execution on the same pipeline.

## Future guardrails

`MCPToolExecutor` is the insertion point for shared validators and guardrails (schema checks, permissions, audit logging) before invoking tool implementations.
