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
- Existing messages should not be upserted as full records.
- The only supported existing-message state transition is marking messages as handled.
- Message listing reads from Firestore local cache and returns the latest messages by repository `_createdAt`, using message `dateTime` only as a tie-breaker.

## MCP tool boundaries

- Chats currently owns read-only listing tools such as `list_chats`, `list_chat_messages`, and `list_unhandled_chats`.
- `send_message` does not belong to Chats. Outbound audit and tool ownership belong to SentMessages.
- `list_chats_by_search` stays deferred until repository-backed search exists.
- `wait_for_event` belongs to runtime/orchestration and is intentionally deferred until late-stage integration across Issues, Chats, SentMessages, SensitiveData, ClientVoice, and event queues.

## Future direction/ownership field

- `author` alone is not enough to determine message ownership.
- A future model revision should add message direction/ownership (`incoming`, `outgoing`, `unknown`) for UI alignment, auditing, and assistant send tracking.
- SentMessages/provider message IDs may later help reconcile outbound assistant messages when they are observed back from WhatsApp.

## Repository rules

- Chat/message repositories may include feature-specific persistence rules when they are true domain/application semantics.
- Do not move those rules into shared model-level merge helpers.
- Generic Firebase timestamp/cache/serialization behavior belongs in infrastructure, not in chat models.
- Chat list ordering uses `_updatedAt DESC` and `listOrder ASC`. `_updatedAt` brings recently changed chats first, and `listOrder` preserves WhatsApp visual order for chats updated in the same crawl cycle.

## Screen ownership

- `ChatsScreen` is a read/display surface over persisted chat and message data.
- `ChatsScreen` uses `NavigationSplitView` with a chat list sidebar and conversation detail pane.
- Conversation rendering must use Shared UI `DSMessageBubbleRow`.
- Message bubble content must support text, image, sticker, audio, and unknown states with clear labels/placeholders.
- `ChatsFeature` owns chat display/tooling dependencies for this domain and creates repositories in feature initialization.
- `WhatsAppCrawling` owns crawling/parsing/persisting chat data and must remain separate from chat UI concerns.
- Real send-message behavior and sent-message auditing flows are intentionally out of scope for this screen and belong to SentMessages plus WhatsAppCrawling.
