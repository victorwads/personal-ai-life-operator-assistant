# Shared Settings Architecture

This folder owns the shared profile-runtime settings substrate used across features.

Shared Settings owns `SettingsStore`, `SettingsScope`, `SettingsContext`, `SettingsSectionRegistry`, `SettingsSectionProvider`, `SettingsSectionDefinition`, and the small support types used by multiple features to read settings or register settings sections.

`SettingsStore` is shared profile runtime state, not product-facing Settings feature UI and not external infrastructure.

`SettingsStore` is not owned by `SettingsFeature`. The shared profile runtime owns the store and passes it to features through `SettingsContext`.

Features may keep feature-specific typed wrappers over `SettingsStore`, but those wrappers stay inside the owning feature.

## Related Boundaries

- [Global architecture](../../../Docs/Architecture.md)
- [Shared](../Architecture.md)
- [Feature Runtime](../FeatureRuntime/Architecture.md)
- [Settings Feature](../../Features/Settings/Architecture.md)
