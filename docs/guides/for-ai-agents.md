# For AI agents

Use this guide if you are building an agent that reads, changes or plays a ZARVAN world. If you are modifying the engine repository itself, read [AGENTS.md](../../AGENTS.md) instead.

## Choose a role

| Role | Observes | Acts through |
|---|---|---|
| Trusted runtime NPC | `WorldView` | `Behavior.decide(view, self)`, returning an `Action` |
| External strategy player | A team-filtered observation | Validated orders |
| Author/operator | Project files, schemas, sandbox-world snapshots | Operation registry (MCP, CLI, REST or JSON-RPC) |

The runtime Dart interface is cooperative, not process isolation. A custom behavior can access mutable state; never execute arbitrary untrusted Dart as a behavior. See [runtime agent API](../concepts/agent-api.md).

## Discover before calling

1. Call `engine.capabilities` to check availability and restrictions.
2. Call `engine.operations` to enumerate visible operations.
3. Call `engine.operation` with `{"name":"level.list"}` (or the desired operation) to obtain its exact input schema, errors and examples.
4. Call `engine.docs` for available Markdown pages or read the [published index](https://meetarash.ir/zarvan/llms.txt) or [full technical Markdown](https://meetarash.ir/zarvan/llms-full.txt).

Use the [operations reference](../reference/operations.md), [component shapes](../reference/components.md), [events](../reference/events.md) and [transport quick start](../reference/transports.md).

## Validate before applying

Dart patches use a two-step pattern:

```dart
final problems = world.checkPatch(patch);
if (problems.isEmpty) {
  world.applyPatch(patch, strict: true);
}
```

The `world.patch` registry operation separately accepts `dryRun: true` to return problems without applying a patch. Inspect both the result envelope and validation data. Use `strict: true` for actual application.

For project content, inspect `project.problems`, `level.validate` or `level.lint`; preview file writes and inspect the resulting diff. Destructive edits require a confirmation token. Journalled file writes can be undone; sandbox-world changes are not file undo entries.

## Rules and limits

- Treat `--read-only` as a restriction on operation kinds, not immutable simulation state. Some read-classified operations change session or in-memory worlds. Restrict the server allowlist if observation must be side-effect free. Legacy CLI commands do not all use the registry policy.
- Treat full snapshots as privileged: filter them before sharing with an external player. Order validation does not prevent information leaks.
- Use `world.random` and fixed timesteps for deterministic simulation.
- Register components before expecting them to appear in serialization. See [FAQ](../faq.md#my-component-isnt-saved-or-loaded).
- Do not guess missing parameters, enum values, imports or result shapes. Inspect live schemas and public exports.

Continue with [agent hub](../agents.md), [external strategy player tutorial](../tutorials/03-agent-driven-game.md) or [operator tutorial](../tutorials/06-agent-api.md).
