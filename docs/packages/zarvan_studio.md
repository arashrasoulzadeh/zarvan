# zarvan_studio

**Runtime:** Flutter desktop · **Audience:** game makers · **Depends on:** engine packages

The visual Studio for editing levels and content. It is an application, not a
library: it is not added as a dependency.

## What's inside (`lib/src/`)

| Area | What it does |
|---|---|
| `level`, `palette`, `inspector` | Level editor, entity palette and property inspector. |
| `graph` | Node-graph editing for behavior trees and dialogue. |
| `animation`, `textures`, `assets` | Animation and asset tooling. |
| `preview`, `playtest` | Embedded preview and the separate-process play-test ([ADR 0003](../adr/0003-play-test-as-separate-process.md), [ADR 0005](../adr/0005-embedded-preview.md)). |
| `validation`, `diff`, `code`, `lsp` | Validation against `zarvan_schema`, diffs, code view and language-server support. |
| `project`, `prefs`, `plugins`, `bootstrap` | Project handling, preferences and plugins. |

Studio edits through the same undoable command model as the API
([ADR 0002](../adr/0002-command-model-in-engine-core.md)), so what you do by
hand and what an agent does produce identical diffs.

See the [Studio user guide](../studio/user-guide.md) and
[Build your first level](../studio/first-level.md).

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_studio)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_studio/CHANGELOG.md)

- [All packages](../packages.md)
