# Memories Architecture

Memories are profile-scoped durable assistant context. They are intentionally simple so the assistant has one clear place for permanent facts and standing preferences.

## Model

`Memory` contains only:

- `id`
- `key`
- `value`

The model is data-only. It must not contain repository, upsert, merge, Firebase audit metadata, or persistence behavior. Do not add `kind`, `title`, `createdAt`, `updatedAt`, or `deletedAt` to the model.

## Persistence

`FirestoreMemoryRepository` extends `FirestoreRepository<Memory>` and stores records under the profile-scoped `Memories` collection.

No custom persistence behavior exists yet. Generic CRUD from `FirestoreRepository` is enough for now. Firebase SDK types and metadata remain behind Infrastructure-owned repository abstractions.

## Surfaces

MCP tools are the assistant-facing API for creating and deleting memories.

The Command Center Memories screen is the user-facing UI. It renders the current profile's memories with shared UI components and does not own persistence rules.
