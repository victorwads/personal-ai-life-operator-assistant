# Tests Architecture

This folder owns the unit-test suite for `AIAssistantHub`.

Organize tests by feature:

- `Features/<FeatureName>/...` contains the test files for that feature.
- `Support/` contains reusable test helpers only.
- `Fixtures/` contains raw external-style inputs used by tests.

Fixture rules:

- Keep expected in-memory values in the test code when possible.
- Put only raw external payloads in fixture files.
- For one scenario with multiple equivalent raw inputs, create one test method and one fixture folder for that scenario.
- Store the scenario inputs directly inside that scenario folder. Do not add an extra `inputs/` layer unless a test truly needs multiple categories of files.

Test style:

- One scenario should map to one test method.
- If a scenario has multiple input variations, loop only over that scenario's fixtures inside the method.
- Avoid one test method iterating over many unrelated scenarios, because failures become harder to read in Xcode.
