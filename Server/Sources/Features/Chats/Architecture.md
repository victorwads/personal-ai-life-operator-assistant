# Chats Architecture

This document owns chat/message domain model and repository rules.

## Domain model rules

- `Chat` and `ChatMessage` are domain models and must stay integration-agnostic.
- Persisted chat models must not contain raw integration transport fields.
- Raw fields such as `rawDateTimeAndAuthor` and `rawTimeText` are forbidden in persisted domain models.
- Integration-specific parsing and cleanup belongs in the integration/parser layer before creating persisted models.
- `Chat.unhandledCount` is a cached count of messages with `handled == false`. The source of truth remains `ChatMessages`; the repository can recompute it via `updateUnhandledCount(chatId:count:)`, using Firestore count aggregation (not document reads).
- When new messages are inserted, the repository recomputes `Chat.unhandledCount` for affected chats. This avoids recalculating counts on every chat list read.
- `list_chats` exposes `unhandledCount`, and `list_unhandled_chats` uses cached `Chat.unhandledCount` to avoid scanning `ChatMessages` during listing. The source of truth remains `ChatMessage.handled`.
- Permission-aware unhandled listing must be centralized in the repository path so MCP/runtime callers do not need to remember a second `isChatAllowed` filter after requesting unhandled chats.
- Existing data may have missing or stale cached counts; the MCP tool `backfill_unhandled_counts` recomputes `Chat.unhandledCount` for all persisted chats by calling `updateUnhandledCount(chatId:count:)` per chat.

## ID format rules

- Chat/message ids must be source-prefixed at creation boundaries.
- Do not persist raw provider identity fragments as separate domain identity fields; keep identity in the already-prefixed chat/message ids.
- If an integration lacks a reliable chat id, the integration boundary must generate a safe stable id while preserving the visible chat title as-is.

## `handled` semantics

- `handled` represents domain/workflow state and belongs on `ChatMessage`.
- New crawled messages default to `handled = false`.
- Existing messages should not be upserted as full records.
- The only supported existing-message state transition is marking messages as handled.
- Message listing reads from Firestore local cache and orders messages by `_createdAt DESC`, then `listOrder DESC` so newest messages stay at the top.

## MCP tool boundaries

- Chats owns chat listing tools such as `list_chats`, `list_chat_messages`, and `list_unhandled_chats`, plus the explicit handled-marking tool `mark_chat_messages_as_handled`.
- `list_chat_messages` returns a read receipt token for the last returned message and does not mutate handled state.
- `send_message` does not belong to Chats. Outbound audit and tool ownership belong to SentMessages.
- `list_chats_by_search` performs a simple similarity search over `Chat.title` and `Chat.lastMessagePreview`; when no chats match, it returns a textual fallback with the latest 10 allowed chats showing only title and ID.
- `wait_for_event` belongs to runtime/orchestration and is intentionally deferred until late-stage integration across Issues, Chats, SentMessages, SensitiveData, ClientVoice, and event queues.

## Direction ownership field

- `ChatMessage.direction` (`sent`/`received`) is the source of truth for bubble alignment.
- Parser-level direction detection may use provider metadata when available; unknown direction defaults to `received`.
- SentMessages/provider message IDs may later help reconcile outbound assistant messages when they are observed back from WhatsApp.

## Repository rules

- Chat/message repositories may include feature-specific persistence rules when they are true domain/application semantics.
- Do not move those rules into shared model-level merge helpers.
- Generic Firebase timestamp/cache/serialization behavior belongs in infrastructure, not in chat models.
- Chat list ordering uses `lastDigestedAt DESC` and `listOrder ASC`. `lastDigestedAt` tracks when crawling actually persisted new chat/message content, while `_updatedAt` remains technical metadata for any write.

## Screen ownership

- `ChatsScreen` is a read/display surface over persisted chat and message data.
- `ChatsScreen` uses `NavigationSplitView` with a chat list sidebar and conversation detail pane.
- Conversation rendering must use Shared UI `DSMessageBubbleRow`.
- Message bubble content must support text, image, sticker, audio, and unknown states with clear labels/placeholders.
- `ChatsFeature` owns chat display/tooling dependencies for this domain and creates repositories in feature initialization.
- `WhatsAppCrawling` owns crawling/parsing/persisting chat data and must remain separate from chat UI concerns.
- Real send-message behavior and sent-message auditing flows are intentionally out of scope for this screen and belong to SentMessages plus WhatsAppCrawling.
