# Infrastructure Architecture

Infrastructure owns external technology boundaries.

Examples include Firebase, auth providers, HTTP clients, filesystem access, Keychain, OS adapters, and SDK-specific integration code.

Infrastructure may import external SDKs. Features should not import external SDKs directly; they should use simple repositories, services, or clients exposed by Infrastructure.

Infrastructure should not own feature UI, Command Center routing, product workflows, or feature-specific screen composition.

Firebase-specific rules live in [Firebase architecture](Firebase/Architecture.md).

## Related Boundaries

- [Features](../Features/Architecture.md)
- [Shared](../Shared/Architecture.md)
- [Global architecture](../../../Docs/Architecture.md)
