# AI Connection Architecture

This folder owns AI provider configuration, provider clients, and the app-side streaming foundation for model execution.

## Ownership

`AIConnection` owns:

- provider settings stored under the `aiConnection` settings scope
- provider-specific client adapters
- provider-neutral stream event models
- provider-neutral request/response models
- app-side services that call AI providers directly
- feature-local bridges that adapt AI tool calling to existing runtime APIs

`AIConnection` does not require the MCP HTTP server.
Provider calls happen directly from the app through provider HTTP APIs.

## MCP boundary

`MCPServersFeature` still owns:

- tool registry composition
- tool definition lookup
- tool validation
- official tool execution through `executeToolCall(_:)`

`AIConnection` may consume that existing execution API through a feature-local bridge, but it must not reimplement registry or validation behavior and must not change `MCPServersFeature` just to enable AI provider calls.

## First provider implementation

The first provider adapter is OpenAI-compatible chat completions streaming.
That single adapter is intended to cover providers such as:

- OpenRouter via `https://.../api/v1/chat/completions`
- LM Studio via `http://localhost:1234/v1/chat/completions`
- other OpenAI-compatible chat completions providers

The provider kind currently changes defaults such as base URL and labeling, while the streaming transport implementation remains the same.

## Intentional non-goals for this phase

This foundation intentionally does not implement:

- Anthropic
- non-streaming provider requests
- OpenAI Responses API
- provider-managed stateful sessions
- Command Center AI execution UI
- the full internal tool loop

Streaming is the only supported execution mode in this phase.

## Cache mode

`AIConnection` stores cache preference metadata in settings, but OpenAI-compatible chat completions cache behavior depends on the upstream provider.
This feature must not promise stateful cache support for all providers.
Provider-specific cache headers or routing behavior should stay as follow-up work inside this feature when needed.

## Known follow-ups

- Move provider API keys to Keychain before production/non-local usage.
- Normalize base URLs that already include `/chat/completions`.
- Implement the real agent tool loop: stream model output, execute tool calls through MCPServers, append tool results, and continue.
- Decide whether tool calls should be emitted/executed before `[DONE]` when providers stream complete tool-call arguments early.
- Consider moving `AIJSONValue` to `Shared` if JSON bridging becomes needed outside AIConnection.
