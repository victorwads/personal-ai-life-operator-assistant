# Firebase Architecture

This document owns Firebase repository boundaries and persistence metadata rules.

## Responsibility boundaries

- `FirestoreRepository` owns Firestore serialization/deserialization details.
- Firebase SDK imports are allowed only under `Sources/Infrastructure`.
- Realtime Database SDK imports, generic RTDB repositories/clients, and emulator bootstrap also live under `Sources/Infrastructure`.
- Feature code must use infrastructure repositories/services and must not import Firebase SDK modules directly.
- Domain models must stay clean and focused on domain/application behavior.
- Domain models must not embed Firebase audit metadata or Firestore transport details by default.
- Feature repositories should stay thin wrappers over `FirestoreRepository`.
- Feature repositories should not expose Firebase SDK types in their stored properties, initializers, method signatures, or protocol contracts.
- Feature-specific Realtime Database repositories belong in the owning feature and should compose Infrastructure RTDB clients instead of importing Firebase SDKs directly.

## Metadata injection

- Repository writes may inject technical metadata such as `createdAt`, `updatedAt`, and `deletedAt`.
- Technical metadata belongs to repository/persistence behavior, not model structs.
- Normal saves should not require every domain model to define audit properties.
- Soft delete behavior should set `deletedAt` only when delete is requested; normal documents do not need a null deleted field.

## Read behavior

- Repository methods remain async because persistence is the boundary.
- Repositories may support cache-only reads when runtime responsiveness matters.
- Cache-only reads must treat normal cache misses as "not found" instead of aborting higher-level workflows.

## Firestore local cache

- Firebase startup enables Firestore local persistence/cache in Infrastructure.
- Startup explicitly keeps Firestore on `PersistentCacheSettings` so local-first behavior is clear at bootstrap.
- Startup enables persistent cache index auto-creation when supported by the SDK.
- Local persistent cache indexes improve cache/offline filtered query behavior over already cached data.
- Local cache indexes do not replace remote Firestore composite indexes required for server/default reads.
- User-facing flows should not rely on cache-only reads unless empty or incomplete cache results are acceptable.
- Realtime Database emulator configuration is applied in `FirebaseAppConfigurator` before the first RTDB reference is used.

## Merge/upsert rules

- Model structs must not own merge/upsert persistence behavior.
- Do not place persistence merge logic inside model protocols or model types.
- Do not add model-level persistence merge helpers for upsert-like behavior.
- Repository-specific rules that are true domain/application behavior belong in the feature repository.

## Thin feature repository style

Feature repositories should usually define only:

- entity name
- collection path
- model type
- read source

They should not duplicate generic timestamp, serialization, cache, or Firestore write behavior.
They should depend on Infrastructure-owned abstractions such as `FirestoreRepository` rather than `Firestore`, `DocumentReference`, `QuerySnapshot`, `FieldValue`, or other Firebase SDK types.
