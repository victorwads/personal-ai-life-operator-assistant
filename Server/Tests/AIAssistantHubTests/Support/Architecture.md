# Test Support Architecture

This folder owns reusable helpers for the test target.

Keep the split simple:

- `TestFixtureLoader` only knows how to locate fixture files and return their raw text.
- `FixtureBackedTestCase` owns convenience methods for scenario-style tests so individual test files stay concise.
- Expectations should stay in the test code unless the expected value is itself an external artifact that must be preserved exactly.
- Prefer the high-level test conventions from `Tests/AIAssistantHubTests/Architecture.md` and keep this folder focused on helper implementation details.

Fixture convention:

- Put external inputs under `Tests/AIAssistantHubTests/Fixtures/`.
- Group fixtures by feature first, then by test topic.
- For scenario-driven parsing tests, prefer one scenario folder per test method.
- Put the raw variants directly in that scenario folder unless the scenario truly needs sub-groups of files.
- Keep fixture files raw and close to what the app/provider really receives. Prefer `.json`, `.sse`, or `.txt` based on the payload shape instead of forcing one extension.
- `FirestoreFixtureBuilder` is the single entry point for Firestore repository test setup. It should load fixtures, import them into an isolated profile scope, and clear them after the test.
- Firestore fixture files should stay generic at the collection level so future repository-backed collections can be added without creating a new importer class per entity.

Goal:

- test code should clearly show the in-memory expectation
- fixture files should clearly show the raw external inputs
- support helpers should reduce boilerplate without hiding the test flow
