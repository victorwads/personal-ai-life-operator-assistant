# Firebase Architecture

This document owns Firebase repository boundaries and persistence metadata rules.

## Responsibility boundaries

- `FirebaseRepository` owns Firestore serialization/deserialization details.
- Domain models must stay clean and focused on domain/application behavior.
- Domain models must not embed Firebase audit metadata or Firestore transport details by default.
- Feature repositories should stay thin wrappers over `FirebaseRepository`.

## Metadata injection

- Repository writes may inject technical metadata such as `createdAt`, `updatedAt`, and `deletedAt`.
- Technical metadata belongs to repository/persistence behavior, not model structs.
- Normal saves should not require every domain model to define audit properties.
- Soft delete behavior should set `deletedAt` only when delete is requested; normal documents do not need a null deleted field.

## Read behavior

- Repository methods remain async because persistence is the boundary.
- Repositories may support cache-only reads when runtime responsiveness matters.
- Cache-only reads must treat normal cache misses as "not found" instead of aborting higher-level workflows.

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
