# Shared UI Architecture

This folder owns the small shared SwiftUI foundation used by feature screens.

Keep this layer lightweight:

- Prefer native SwiftUI and platform styles.
- Add reusable views only when more than one feature screen can reasonably use them.
- Do not introduce a broad design system, custom color palette, theme engine, or feature-specific logic here.
- Shared UI components must not import Firebase or feature infrastructure.
- Feature screens own their data loading, state, and actions.

Preview rule:

- Every shared UI component in this folder must be represented in `Previews.swift`.
- When adding or changing a component, update `Previews.swift` with at least one realistic example.
- Keep previews useful as a visual catalog for Xcode, not as production screen composition.
