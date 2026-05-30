# Issues Architecture

Issues are the operational and audit anchor for assistant work.

Future features such as Sensitive Data, Sent Messages, Client Voice, and WhatsApp actions may store an `issueId` to justify sensitive actions.

## Core model rules

- `Issue.finished` is a stored field to keep active issue queries simple in Firestore.
- Active issues are every issue where `finished == false`.
- Resolved and cancelled issues must set `finished == true`.
- `IssueStatus` values are `pending`, `suspended`, `resolved`, and `cancelled`.
- `IssuePriority` is numeric (`1...5`) to keep priority handling stable across tools and persistence.
- Timeline items record lifecycle changes and issue updates using `issueId`, `kind`, and `description`.

## Runtime and validation surface

- `IssuesFeature` owns a non-optional `FirestoreIssueRepository`.
- `IssuesFeature` also owns the issue timeline repository used by lifecycle and update actions.
- Cross-feature issue validation should go through `IssuesFeature.validateIssueId(_:)` and repository validation methods.
- Issue validation is internal Swift support for future actions; it is not exposed as a public MCP tool.
- `create_issue` always starts pending.
- `update_issue` updates issue details and appends explicit timeline items.
- `suspend_issue`, `resolve_issue`, and `cancel_issue` are the lifecycle actions that mutate issue state and optionally append timeline entries.

## UI scope (current phase)

- The first Issues screen is intentionally list-only.
- It loads active issues and shows lightweight operational cards.
- Rich history, timeline, and dashboard experiences are intentionally deferred.
