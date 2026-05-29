# Chats Architecture

This document owns chat/message domain model and repository rules.

## Domain model rules

- `Chat` and `ChatMessage` are domain models and must stay integration-agnostic.
- Persisted chat models must not contain raw integration transport fields.
- Raw fields such as `rawDateTimeAndAuthor` and `rawTimeText` are forbidden in persisted domain models.
- Integration-specific parsing and cleanup belongs in the integration/parser layer before creating persisted models.

## ID format rules

- Chat/message ids must be source-prefixed at creation boundaries.
- Do not persist raw provider identity fragments as separate domain identity fields; keep identity in the already-prefixed chat/message ids.
- If an integration lacks a reliable chat id, the integration boundary must generate a safe stable id while preserving the visible chat title as-is.

## `handled` semantics

- `handled` represents domain/workflow state and belongs on `ChatMessage`.
- New crawled messages default to `handled = false`.
- Repository upsert behavior must preserve existing `handled` values when updating an existing message.

## Repository rules

- Chat/message repositories may include feature-specific persistence rules when they are true domain/application semantics.
- Do not move those rules into shared model-level merge helpers.
- Generic Firebase timestamp/cache/serialization behavior belongs in infrastructure, not in chat models.
