---
title: Agent hub
description: Entry points, permission boundaries and verified control loops for agents working with ZARVAN.
---

# Agent hub

Choose the role before choosing an API. A repository coding agent, a game-content operator and a runtime NPC have different permissions and interfaces.

| Role | Start here | Contract |
|---|---|---|
| Coding agent modifying the engine | [Repository AGENTS.md](../AGENTS.md) | Public Dart exports, source, tests and package manifests |
| Project author/operator | [Tutorial 6](tutorials/06-agent-api.md) | Operation registry over MCP, REST, JSON-RPC or CLI |
| External strategy player | [Tutorial 3](tutorials/03-agent-driven-game.md) | Filtered observations and validated orders |
| Trusted runtime behavior | [Runtime agent API](concepts/agent-api.md) | `Behavior.decide(WorldView, EntityId)` returns an `Action` |

## Discover the contract

Before invoking a tool, call `engine.capabilities` to discover restrictions and registry version, `engine.operations` to enumerate available operations, and `engine.operation` with `{"name":"level.list"}` (or the operation you need) to obtain its input schema, errors and examples. Use `engine.docs` for available Markdown documentation.

```bash
zarvan engine capabilities --json
zarvan engine operations --json
zarvan engine operation level.list --json
```

See [operations](reference/operations.md), [components](reference/components.md), [events](reference/events.md), and [transports](reference/transports.md). Published discovery resources: [llms.txt](https://meetarash.ir/zarvan/llms.txt) (index) and [llms-full.txt](https://meetarash.ir/zarvan/llms-full.txt) (complete technical Markdown). See [API reference](api-reference.md) for public Dart libraries.

## Observe, validate, act, observe again

1. Inspect project or world state before editing.
2. Validate content with `level.validate`, `level.lint` or `project.problems`; inspect the returned result, not only the transport status.
3. Preview project writes where supported; destructive operations require confirmation. For `world.patch`, pass `dryRun: true` to validate and `strict: true` when applying.
4. Inspect the resulting diff, warnings and state. Undo journalled file edits if necessary; in-memory world operations are not file undo entries.

In trusted Dart code, use the actual behavior signature:

```dart
import 'package:zarvan_core/zarvan_core.dart';

class IdleBehavior implements Behavior {
  @override
  Action decide(WorldView view, EntityId self) {
    return const NoOpAction();
  }
}
```

Register the behavior in a `BehaviorRegistry`, attach `AIState` to an entity and install `AISystem`. The system calls `decide` and applies each action immediately. See the [custom behavior recipe](examples/custom-behavior.md).

## Permission and safety boundaries

- `--read-only` protects against operations classified as file writes or destructive operations; some operations classified as reads change session or sandbox-world state. Use an explicit server allowlist when observation must not change that state. Legacy CLI commands do not all use the registry policy; do not treat the CLI flag as a filesystem sandbox.
- `WorldView` is a cooperative interface, not a security sandbox: it exposes the underlying world and may return mutable component objects. Never execute arbitrary untrusted Dart as an NPC.
- Filter observations for external strategy agents before sending them. Fog-aware order validation does not make a full world snapshot private.
- The API can perform file edits; use least privilege, previews, validation and confirmation. Never expose the bearer token to an untrusted agent.
- Use public exports, fixed simulation steps and seeded randomness. Verify changes with tests.

For a linear workflow, see [For AI agents](guides/for-ai-agents.md).
