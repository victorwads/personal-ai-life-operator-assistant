# Design System Preview App Architecture

This folder owns the runnable preview catalog for `Server/Sources/Shared/UI`.

For the production Shared UI component rules, see [../Architecture.md](../Architecture.md).

The preview app exists so shared design-system components can be inspected in a dedicated macOS target without booting the main app runtime, Firebase setup, feature services, or MCP infrastructure. It is a visual catalog for Shared UI, not a test suite and not a feature surface.

## Target Boundaries

`AIAssistantHubDesignSystemPreview` is a standalone macOS application target defined in `Server/project.yml`.

- The target includes `Sources/Shared/UI` so it can render the shared UI components and the preview app files.
- The main `AIAssistantHub` target excludes `Shared/UI/PreviewApp/**` so preview-only entry points, fake data, and catalog pages cannot compile into the production app.
- The preview app has its own `@main` in `DesignSystemPreviewApp.swift`.
- Do not add a preview-app test target. Shared UI behavior belongs in focused tests on the production component when needed; this app is for visual review.

## Navigation Model

`DesignSystemPreviewRootView` owns the app shell:

- Sidebar navigation uses `NavigationSplitView`.
- Routes are grouped by category.
- The detail area renders the selected route destination.

`DesignSystemPreviewRoute` is the route registry. Each route defines:

- stable `id`
- visible `title`
- sidebar `category`
- SF Symbol `systemImage`
- destination preview page

Add new catalog entries by adding a route case, assigning its category and icon, and returning its page from `destination`.

## Page Organization

Preview pages live under `Pages/` and are grouped by the same categories shown in the sidebar:

- `Foundations/` for primitive controls and small status elements
- `Layout/` for headers, cards, containers, and section patterns
- `DataDisplay/` for rows, code blocks, and debug inspectors
- `Messaging/` for conversation-oriented components
- `Forms/` for editable input components

Keep each page focused on one shared UI family. Avoid rebuilding a giant scroll-only catalog file; the preview app should stay easy to scan and easy to extend.

When a preview page needs page-specific helpers, fake controllers, or sample state, place those files next to the page in a page folder. For example, `Pages/Forms/AudioTranscriptionInputPreviewPage/` owns the audio transcription page, its fake controller, and the case wrapper used only by that page.

## Shared Support

`Support/` is for preview helpers that are useful across multiple pages:

- `PreviewSection` provides consistent titled preview groups.
- `PreviewBounds` constrains page content width consistently.
- `SampleDebugItems` centralizes generic debug sample values.

Do not put component-specific fake data in `Support/` just because it is preview-only. If the helper is only meaningful for one page, keep it beside that page.

## Component Relationship

Production components remain outside `PreviewApp`.

For multi-file components, keep production files together in their component folder under Shared UI. For example, `Forms/DSAudioTranscriptionInput/` owns the public transcription input type, its mode/config/status/segment types, and its controller protocol.

Preview files can depend on production Shared UI components, but production Shared UI components must not depend on preview app files, fake controllers, preview routes, or sample objects.

## Preview Page Expectations

Each page should:

- use `PreviewSection` for grouped examples
- include realistic states instead of placeholder-only samples
- keep confirmed/editable UI separate from fake or live preview state when the component API does that
- avoid feature models, repositories, Firebase imports, MCP runtime types, or app services
- stay small enough that adding a component does not require editing unrelated page content

Use SwiftUI previews inside page files only as local conveniences. The runnable app target is the source of truth for browsing the full catalog.
