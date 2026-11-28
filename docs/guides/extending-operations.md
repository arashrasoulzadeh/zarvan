# Extend the operation registry

**Audience:** engine contributors. The registry is the common contract for agent discovery, CLI, MCP, REST and JSON-RPC.

## Locate the correct layer

- Operation declarations: `packages/zarvan_core/lib/src/ops/groups/`.
- Registry assembly: [all_operations.dart](../../packages/zarvan_core/lib/src/ops/all_operations.dart).
- Parameter and result types: [param.dart](../../packages/zarvan_core/lib/src/ops/param.dart), [result.dart](../../packages/zarvan_core/lib/src/ops/result.dart).
- Transport adapters: `zarvan_api` and `zarvan_cli`.

## Example: a pure read

This is an illustrative operation declaration, not an installed ZARVAN operation. Add it only if the feature is needed.

```dart
Operation(
  name: 'example.echo',
  summary: 'Return the supplied text unchanged.',
  description: 'Returns the supplied text without changing state.',
  kind: OperationKind.read,
  scope: OperationScope.pure,
  idempotent: true,
  params: const [
    Param('text', ParamType.string,
      required: true, description: 'Text to return unchanged.'),
  ],
  handler: (ctx, args) => OpOutcome.data({'text': args['text']}),
  examples: const [
    Example('Echo text', {'text': 'hello'}, expect: {'text': 'hello'}),
  ],
)
```

Import `package:zarvan_core/zarvan_core_ops.dart` when using public operation types. When adding a built-in operation inside core, follow the sibling source imports and register it in the appropriate group.

## Contract checklist

Choose the operation kind according to actual effects. A read-classified operation may still mutate an in-memory session; disclose those effects and never use this classification to bypass file-write policy. Project content writes should return an `OpOutcome.proposal` with a `Proposal` of `FileChange` records for the safety pipeline. Do not write project content directly from the handler. Destructive edits require preview and confirmation.

Describe every parameter, default, unit and constraint. Return stable error codes with useful paths and hints. Keep secrets out of examples, logs and outputs. Add examples, tests for invalid input and permissions, and output schema where practical.

## Validate and regenerate

```bash
(cd packages/zarvan_core && dart analyze --fatal-infos && dart test)
(cd packages/zarvan_api && dart run tool/gen_api_docs.dart > ../../docs/reference/operations.md)
(cd packages/zarvan_api && dart run tool/gen_api_docs.dart --transports > ../../docs/reference/transports.md)
(cd packages/zarvan_core && dart run tool/gen_bundled_docs.dart)
(cd packages/zarvan_api && dart test)
mkdocs build --strict
```

Verify the operation is discoverable via `engine.operation`, that its declared example works and that applicable transports return the same envelope. See [documentation conventions](../contributing-docs.md).
