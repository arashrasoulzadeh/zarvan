# Repository guide for AI coding agents

ZARVAN is a Dart 2D game engine with a Flutter application shell. This file is for agents modifying the engine repository, not agents playing a game or editing a game project.

## Start here

| Task | Read first |
|---|---|
| Understand the engine and package boundaries | [Architecture](ARCHITECTURE.md), [package map](docs/packages.md) |
| Modify the engine | [Engineering conventions](CLAUDE.md), [local setup and validation](CONTRIBUTING.md) |
| Use the public Dart API | [Developer guide](docs/guides/for-developers.md), [API reference](docs/api-reference.md) |
| Drive a game or author content via tools | [Agent hub](docs/agents.md), [operations](docs/reference/operations.md), [transports](docs/reference/transports.md) |
| Add documentation | [Documentation conventions](docs/contributing-docs.md) |
| Understand planned versus shipped work | [TODO](TODO.md), [changelog](CHANGELOG.md), [ADRs](docs/adr/) |

## Non-negotiable rules

- Keep the engine 2D; do not introduce another game engine. Keep simulation independent of Flutter. Preserve the package dependency DAG; consult package manifests for exact dependencies.
- Keep ignored local sample games (`test_game/`, `examples/`) out of commits.
- Preserve self-referencing Git dependencies in manifests and use local `pubspec_overrides.yaml` for monorepo work. Check actual refs, not historical prose.
- Import public package libraries; `lib/src/` is implementation detail for consumers.
- Register serializable components, provide JSON conversion and schema definitions where appropriate, and test registration and behavior.
- Preserve deterministic simulation: fixed timestep, seeded randomness, explicit system ordering. Do not introduce wall-clock reads into simulation rules.
- Follow the public API documentation and testing requirements in CLAUDE.md. Preserve unrelated changes and do not work through TODO.md unless asked.
- Do not commit or push without authorization; report checks actually run and any that could not be completed.

## Workflow

1. Read the relevant package README, public exports, implementation and nearby tests. Source and manifests take precedence over stale prose.
2. Identify affected packages and downstream dependents. Make the smallest change that satisfies the task.
3. Add a regression or behavior test for code changes. Update docs and generated references in the same change when applicable.
4. Run affected package tests and analysis (see CONTRIBUTING.md); for docs run `mkdocs build --strict`. Verify examples against actual signatures.
5. Report changed files, validation results, limitations and any unresolved work.

For an external agent using MCP, begin with `engine.capabilities`, `engine.operations` and `engine.operation`. Use the live registry rather than inventing arguments. Runtime Dart behaviors are trusted code, not a security sandbox; see [agent API](docs/concepts/agent-api.md).
