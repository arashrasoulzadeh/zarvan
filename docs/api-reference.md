# API reference

The authoritative reference is the **doc comments in the source** — every
public class, field and function has one that explains *why*, not just what.
Browse them three ways.

## 1. Generated API docs (HTML)

| Package | Docs |
|---|---|
| `zarvan_core` | [zarvan_core API](https://meetarash.ir/zarvan/api/zarvan_core/) |
| `zarvan_schema` | [zarvan_schema API](https://meetarash.ir/zarvan/api/zarvan_schema/) |
| `zarvan_flutter` | [zarvan_flutter API](https://meetarash.ir/zarvan/api/zarvan_flutter/) |
| `zarvan_platformer` | [zarvan_platformer API](https://meetarash.ir/zarvan/api/zarvan_platformer/) |
| `zarvan_strategy` | [zarvan_strategy API](https://meetarash.ir/zarvan/api/zarvan_strategy/) |
| `zarvan_idle` | [zarvan_idle API](https://meetarash.ir/zarvan/api/zarvan_idle/) |
| `zarvan_quiz` | [zarvan_quiz API](https://meetarash.ir/zarvan/api/zarvan_quiz/) |
| `zarvan_ads` | [zarvan_ads API](https://meetarash.ir/zarvan/api/zarvan_ads/) |
| `zarvan_eye` | [zarvan_eye API](https://meetarash.ir/zarvan/api/zarvan_eye/) |
| `zarvan_api` | [zarvan_api API](https://meetarash.ir/zarvan/api/zarvan_api/) |
| `zarvan_cli` | [zarvan_cli API](https://meetarash.ir/zarvan/api/zarvan_cli/) |

These are rebuilt from `main` by the docs workflow. To build one locally:

```bash
cd packages/zarvan_flutter      # or any package
flutter pub get
dart doc .                      # → doc/api/index.html
```

## 2. Package READMEs

Use the [package overview](packages.md) to find every package's README and public API. Studio is a desktop application, not an imported library. Selected READMEs:
[zarvan_core](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_core/README.md) ·
[zarvan_flutter](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_flutter/README.md) ·
[zarvan_platformer](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_platformer/README.md) ·
[zarvan_strategy](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_strategy/README.md) ·
[zarvan_cli](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_cli/README.md)

## 3. Lookup tables in this site

- [Component reference](reference/components.md) — every component's JSON shape (generated).
- [Events](reference/events.md) · [Cheat sheet](reference/cheatsheet.md) · [CLI](reference/cli.md) · [Glossary](reference/glossary.md)

## Stability

All packages are `0.x`: breaking changes happen. Once a package reaches 1.0,
only what its top-level library exports (`zarvan_core.dart`, …) is covered by
semver; anything under `lib/src/` is internal. See the project README's
"API stability" section.
