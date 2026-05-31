# Features Architecture

Features are product and domain capabilities. A feature may own models, repositories, MCP tools, screens, settings sections, runtime services, and feature-specific architecture docs.

Feature code must not import Firebase SDK modules or other external SDKs directly. Use Infrastructure abstractions for persistence, auth providers, HTTP clients, filesystem access, OS adapters, and other external technology boundaries.

Feature UI may use generic presentation helpers from Shared. Feature-specific UI stays inside the owning feature.

Feature code must not depend on App shell concerns such as AppKit windows, tray ownership, Dock policy, app bootstrapping, or generated project configuration.

Each feature folder should expose its root entrypoint as `<FeatureName>Feature.swift`, and the concrete feature class should be named `<FeatureName>Feature`.

Concrete feature classes inherit from `FeatureRuntime`; they should not include `Runtime` in the class name.

`Sources/Features/AppFeatures.swift` owns the list of connected app features.

Feature screens should receive their owning feature runtime explicitly rather than loose repositories, services, or stores pulled from `ProfileRuntimeContainer`.

If a feature has specific rules, document them in `Sources/Features/<FeatureName>/Architecture.md`.
Current local feature docs include [Sent Messages](SentMessages/Architecture.md) for cross-channel outbound audit ownership and [Sensitive Data](SensitiveData/Architecture.md) for protected-value access rules.

## Related Boundaries

- [Infrastructure](../Infrastructure/Architecture.md)
- [Shared](../Shared/Architecture.md)
- [Global architecture](../../Docs/Architecture.md)
