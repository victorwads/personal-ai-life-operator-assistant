# Shared UI Architecture

This folder owns the small shared SwiftUI foundation used by feature screens. It is the app's local UI design-system layer for reusable visual primitives.

Keep this layer lightweight:

- Prefer native SwiftUI and platform styles.
- Add reusable views only when more than one feature screen can reasonably use them.
- Do not introduce a broad design system, custom color palette, theme engine, or feature-specific logic here.
- Shared UI components must not import Firebase or feature infrastructure.
- Feature screens own their data loading, state, and actions.

Shared UI contains reusable visual primitives used by multiple features.
Feature screens should not duplicate card, badge, empty state, code block, or master-detail presentation patterns when an equivalent shared primitive already exists.
Feature-specific views may compose shared UI components, but they must not move feature logic into `Shared/UI`.
Do not create one-off local visual wrappers when an existing shared component matches the same role.
If a screen needs a new recurring visual pattern, add it to Shared UI first or document why the pattern is feature-specific.
New shared components should have a clear `DS*` name, a concise purpose, and a realistic example in `Previews.swift`.

Shared UI must not know feature models, repositories, Firebase, MCP runtime internals, or app services.

Preferred shared components:

- Use `DSFeatureHeader` for feature screen title/subtitle/action headers.
- Use `DSRefreshButton` for simple refresh actions.
- Use `DSCard` or `DSTitledSection` for cards and titled content sections.
- Use `DSBadge` for generic simple pills, groups, traits, and lightweight metadata.
- Use `DSRuntimeStatusBadge` for runtime/service status capsules with state dots, secondary status text, and optional start/stop action icons.
- Use `DSCodeBlock` for JSON, code, schema, payload, and result displays.
- Use `DSDebugObjectsInspector` as the shared debug helper for inspecting one or more named values, preserving raw strings and falling back to reflection for arbitrary objects. Use its tooltip presentation for compact inline triggers inside feature rows/cards, and its inline presentation when a dedicated debug/detail pane should show the inspector content directly.
- Use `DSListCardRow` for consistent list-like cards across feature indexes.
- Use `DSMessageBubbleRow` for chat-like conversation UIs and voice interaction histories.

The current shared primitives are intended for screens such as:

- MCP Tools Browser
- Chats
- Issues
- Memories
- Sensitive Data

Master-detail guidance:

- Screens with a left list and right detail pane should prefer `NavigationSplitView`.
- The left pane should own filtering, search, and selection.
- The right pane should render the selected item's detail state.
- Keep master-detail structure consistent with the MCP Tools Browser when a feature fits this pattern.
- Do not create a generic master-detail abstraction yet.
- Future Chats screens should prefer `NavigationSplitView` plus `DSMessageBubbleRow`.
- Future Client Voice screens should reuse `DSMessageBubbleRow`.

Command Center guidance:

- Command Center header service badges should use `DSRuntimeStatusBadge`.
- Native SwiftUI sidebar/list/menu rows do not need to be replaced by Shared UI components when platform styling already fits.

Preview rule:

- Every shared UI component in this folder must be represented in `Previews.swift`.
- When adding or changing a component, update `Previews.swift` with at least one realistic example.
- Keep previews useful as a visual catalog for Xcode, not as production screen composition.
