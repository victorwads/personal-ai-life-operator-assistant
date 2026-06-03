# Sent Messages Architecture

Sent Messages are the cross-channel audit history for outbound assistant communication.

This feature stores communication the assistant sends or attempts to send, independent from transport.

## Ownership

- Sent Messages own outbound assistant audit history and the `send_message` MCP tool.
- Sent Messages do not belong to WhatsAppCrawling because outbound audit history is not WhatsApp-specific.
- Sent Messages do not belong to Sensitive Data or My Data because this is operational action history, not user-owned secret data.
- Channel-specific features own transport behavior; Sent Messages own outbound audit records and tool-level audit orchestration.
- Sent Messages owns outbound assistant identity settings: assistant name, message prefix/postfix, and message header/footer.

## Model

`SentMessage` is a data-only domain model with:

- `id`
- `issueId`
- `chatId`
- `chatTitle`
- `messages`
- `status`
- `chatMessageIds`
- `errorMessage`
- `sentAt`

Do not add repository behavior, merge/upsert behavior, or Firebase audit metadata fields to this model.

`SentMessageStatus` supports:

- `pending`
- `sent`
- `failed`
- `partiallySent`

## Persistence

`FirestoreSentMessageRepository` extends `FirestoreRepository<SentMessage>` and stores records under the profile-scoped `SentMessages` collection.

Feature-specific queries may filter by `issueId` and `chatId`.

## Runtime and integrations

`SentMessagesFeature` owns a non-optional `FirestoreSentMessageRepository`, outbound assistant settings, and `send_message`.

External send actions should eventually validate `issueId` through `IssuesFeature` before recording and sending.

This feature is transport-agnostic. `send_message` now composes outbound content, records pending audit, calls channel-specific send APIs, and records the resulting status.

## Planned integrations

Future integrations include:

- WhatsApp outbound `send_message`
- Client Voice `speak_to_client`
- Client Voice `ask_to_client`
- future email outbound actions

## Outbound formatting rules

SentMessages settings define how outbound text is composed:

```text
<header as its own message>
<prefix><message 1><postfix>
<prefix><message 2><postfix>
<footer as its own message>
```

- Include only non-empty values.
- Header is inserted as its own first outbound message when non-empty.
- Footer is inserted as its own last outbound message when non-empty.
- Prefix/postfix are applied around each individual message text.
- Avoid extra blank lines when header/footer are empty.
- Final formatting behavior should stay centralized in SentMessages.

Future `send_message`, `speak_to_client`, and `ask_to_client` should compose outbound communication through these settings.

## Send transport flow

`send_message` now runs this flow:

1. require `issueId`
2. validate the active issue through the shared MCP validator pipeline
3. apply SentMessages outbound identity settings
4. create a SentMessage audit record with `.pending`
5. call channel-specific transport
6. store observed chat message IDs when available
7. update SentMessage status to `.sent`, `.partiallySent`, or `.failed`
8. later reconcile observed source messages as assistant/outgoing

For WhatsApp specifically, SentMessages calls WhatsAppCrawling to send and observe outbound messages while WhatsAppCrawling remains the owner of transport-specific Web interaction.

## Known follow-ups

- Resolve and persist `chatTitle` from Chats when available.
- Decide whether failed `send_message` executions should expose the persisted `SentMessage` audit id back to the caller.
- Move nested `messages[]` item validation into centralized MCP validators when schema `items` validation is implemented.
- Add migration/backfill handling if older SentMessages documents still use `targetKind`, `targetId`, `targetTitle`, or `providerMessageIds`.
