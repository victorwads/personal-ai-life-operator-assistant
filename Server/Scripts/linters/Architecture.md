# Linters architecture

## Ownership

Linters live under `Scripts/linters/` and are orchestrated by `Scripts/lint.sh`.

- Linters are allowed to be extended when the project architecture needs a new guardrail.
- Linters must not be weakened, removed, or bypassed.

## Human build gate

Whenever a linter is added or a lint rule changes, build validation must be triggered by a human (not by automation).

Rationale:

- Linter changes are powerful and easy to abuse; requiring human intervention forces review.
- Builds can be expensive and can mask rule changes that should be scrutinized first.

Practical rule:

- Update/extend linters as needed.
- Run `Scripts/lint.sh`.
- A human reviews the linter changes and then runs `Scripts/check_build_and_restart.sh`.

