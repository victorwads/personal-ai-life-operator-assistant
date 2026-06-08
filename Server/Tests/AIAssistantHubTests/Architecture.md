# Tests Architecture

This folder owns the unit-test suite for `AIAssistantHub`.

Organize tests by feature:

- `Features/<FeatureName>/...` contains the test files for that feature.
- `Support/` contains reusable test helpers only.
- `Fixtures/` contains raw external-style inputs used by tests.

Fixture rules:
 
- Keep expected in-memory values in the test code when possible.
- Put only raw external payloads in fixture files.
- Fixture JSON files must not contain empty collections (e.g. `"Chats": []`). Only define the collections that actually seed data.
- For one scenario with multiple equivalent raw inputs, create one test method and one fixture folder for that scenario.
- Store the scenario inputs directly inside that scenario folder. Do not add an extra `inputs/` layer unless a test truly needs multiple categories of files.

Test style:

- One scenario should map to one test method.
- If a scenario has multiple input variations, loop only over that scenario's fixtures inside the method.
- Avoid one test method iterating over many unrelated scenarios, because failures become harder to read in Xcode.

# Firestore Integration Testing

Before running repository tests, start the Firestore test emulator from the repo root:

```sh
firebase emulators:start --project tests --config firebase.tests.json
```

1. Repository integration tests use the Firestore Emulator.
2. Tests use `FirebaseProfileScope.testScope()`.
3. Fixtures are inserted directly into Firestore.
4. Fixtures never use repositories.
5. Fixture insertion order is randomized.
6. Tests must never rely on insertion order.
7. Collection names must match production names.
8. Every fixture document must contain `_createdAt`.
9. Repository tests validate real Firestore behavior.
10. Repository CRUD fakes are forbidden.
11. Repository spies are forbidden in tests when a real Firestore repository exists. Use Firestore emulator integration tests instead. Small non-repository test doubles are allowed only for external side effects such as speech, webview, process execution, or presence if no emulator-backed repository exists yet.

# Parallel Test Execution

1. All tests must support parallel execution.
2. All tests must support random execution order.
3. Tests must never depend on execution order.
4. Tests must never depend on shared Firebase profile ids.
5. Tests must never depend on shared Firestore collections.
6. Tests must never depend on state created by another test.
7. Every Firestore integration test must use `FirebaseProfileScope.testScope()`.
8. Test failures caused by execution order are considered bugs.
9. Firestore Emulator tests must avoid unlimited workers to prevent stalls under too many concurrent connections. Local execution scripts should default to 2 workers.
10. If running from Xcode UI causes emulator stalls, use the validation script (`check_build_and_restart.sh`) because it enforces the worker count.
