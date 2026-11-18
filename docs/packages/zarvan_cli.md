# zarvan_cli

**Runtime:** pure Dart · **Audience:** game makers, agents · **Depends on:** `zarvan_core`

The `zarvan` command. Besides scaffolding, every registry operation is also a
command (the 1:1 rule), so anything an agent can call over MCP you can run in a shell.

## Install

```bash
dart pub global activate --source git https://github.com/arashrasoulzadeh/zarvan.git --git-path packages/zarvan_cli
```

## Commands

| Command | What it does |
|---|---|
| `zarvan create <name>` | New game from a template: `default_game` (platformer), `topdown_game`, `strategy_game`, `idle_game`. Options `--template`, `--org`, `--output-dir`, `--ref`. |
| `zarvan upgrade --ref main` | Updates a generated game's engine version. |
| `zarvan lint <file>` | Validates a level against the content DSL. `--render` rasterizes the tile map; `--playable` flood-fills from spawn to find unreachable entities. |
| `zarvan pack-assets` | Packs images into a sprite sheet and region manifest (MaxRects), with `--scales` resolution tiers. |
| `zarvan build-release` | Release build and manifest. |
| `zarvan studio …` | Level, asset, diff and edit commands. |
| `zarvan idle validate` / `simulate` | Idle definition checks and balance simulation. |
| `zarvan quiz …` | Quiz bank validation, generation and simulation. |

Full list: [CLI reference](../reference/cli.md) and [Operations](../reference/operations.md).

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_cli)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_cli/CHANGELOG.md)

- [All packages](../packages.md)
