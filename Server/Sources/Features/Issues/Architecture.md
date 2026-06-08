# Issues Architecture

Issues are the operational and audit anchor for assistant work.

Future features such as Sensitive Data, Sent Messages, Client Voice, and WhatsApp actions may store an `issueId` to justify sensitive actions.

## Core model rules

- `Issue.finished` is a stored field to keep active issue queries simple in Firestore.
- Active issues are every issue where `finished == false`.
- Resolved and cancelled issues must set `finished == true`.
- `IssueStatus` values are `pending`, `suspended`, `resolved`, and `cancelled`.
- The UI may label `pending` as `Active`, but the persisted status stays `pending` for compatibility.
- `IssuePriority` is numeric (`1...5`) to keep priority handling stable across tools and persistence.
- Timeline items record lifecycle changes and issue updates using `issueId`, `kind`, and `description`.
- Manual lifecycle transitions append auditable timeline entries with `reason`, `changedAt`, `previousStatus`, and `suspendUntil` when applicable.

## Runtime and validation surface

- `IssuesFeature` owns a non-optional `FirestoreIssueRepository`.
- `IssuesFeature` also owns the issue timeline repository used by lifecycle and update actions.
- `IssuesFeature` also owns `IssueStatusTransitionService`, which is the UI-facing path for manual status correction.
- Cross-feature issue validation should go through `IssueReferenceValidating` and `IssuesFeature.validateIssueId(_:)`.
- Issue validation is internal Swift support for future actions; it is not exposed as a public MCP tool.
- MCP validation uses `IssuesFeature` lazily via provider-based lookup from `MCPServersFeature`, not direct repository injection.
- Issue reference validation for MCP treats missing, invalid, resolved, cancelled, and finished issues as inactive and blocks execution.
- AI-facing issue-reference validation failures should use standardized actionable messages instead of exposing repository internals.
- `create_issue` always starts pending.
- `update_issue` updates issue details and appends explicit timeline items.
- `suspend_issue`, `resolve_issue`, and `cancel_issue` are the lifecycle actions that mutate issue state and optionally append timeline entries.
- Manual issue management in the UI uses the status transition service so state changes and audit entries stay together.

## UI scope (current phase)

- The first Issues screen is intentionally list-only.
- It loads active issues and now shows per-row manual status actions plus lightweight operational cards.
- The detail screen surfaces the timeline history and the same manual status actions.
- Client Voice detail integration is still repository-pending, so Issue detail should render an empty state there until a concrete data source is wired.
- Issues owns construction of Issue detail secondary windows through a generic `FeatureWindowRequest`; the app/window layer only manages the resulting generic window.
