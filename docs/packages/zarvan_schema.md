# zarvan_schema

**Runtime:** pure Dart · **Audience:** tool builders, agents · **Depends on:** nothing

Hand-written component schemas: for every registered component, its field
names, types, ranges, enum options and defaults. The `zarvan studio validate`
command and Studio read these to check levels without importing Flutter.

## What's inside

| Piece | What it does |
|---|---|
| `ComponentSchema`, `FieldSchema`, `FieldType` | The schema vocabulary. `zarvan_core` re-exports these three. |
| `core_schemas`, `flutter_schemas`, `platformer_schemas`, `idle_schemas` | One schema list per package that registers components. |
| `all_schemas` | The merged set, the one validators use. |
| `did_you_mean` | Suggests the nearest valid field or component name for a typo. |

## Why hand-written

The schemas are **data**. Each must match its component's `toJson` keys, and
drift tests in the engine packages fail when they diverge. See
[ADR 0001](../adr/0001-hand-written-component-schemas.md) and
[ADR 0004](../adr/0004-schemas-in-engine-schema.md).

## When you need it

You usually don't depend on it directly: `zarvan_core` and `zarvan_cli` pull it
in. Depend on it when building a tool that validates or edits level JSON
without the engine.

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_schema:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_schema
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_schema)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_schema/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_schema/)
- [All packages](../packages.md)
