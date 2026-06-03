# Shared Architecture

Shared contains reusable app-level code that is not owned by one feature.

Shared is not a dumping ground. Shared code should be generic, small, and broadly useful across feature boundaries.

Shared must not own domain state, repositories, runtime services, Firebase SDK types, profile lifecycle, Command Center routing, or app shell bootstrapping.

`Shared/FeatureRuntime` contains app-internal feature composition contracts. See [FeatureRuntime/Architecture.md](FeatureRuntime/Architecture.md).

`Shared/Settings` contains the shared settings runtime substrate, including `SettingsStore`, `SettingsContext`, and settings section registration types used across features. See [Settings/Architecture.md](Settings/Architecture.md).

Shared code must remain generic and must not own feature business logic.

Shared UI components may depend on SwiftUI. They should contain only generic presentation helpers reused by multiple features. Feature-specific UI stays inside the owning feature.

## Related Boundaries

- [Features](../Features/Architecture.md)
- [Infrastructure](../Infrastructure/Architecture.md)
- [Global architecture](../../../Docs/Architecture.md)
