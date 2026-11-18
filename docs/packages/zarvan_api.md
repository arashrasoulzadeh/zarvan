# zarvan_api

**Runtime:** pure Dart · **Audience:** agents, operators · **Depends on:** `zarvan_core`

An MCP server and an HTTP / JSON-RPC API over the operation registry in
`zarvan_core`. Every operation is declared once and is available as a
`zarvan <group> <verb>` command, an MCP tool, a REST route and a JSON-RPC method.

## Surfaces

| Surface | Where |
|---|---|
| MCP tools | stdio, or `POST /mcp` |
| REST | `POST /v1/<group>/<verb>`, `GET /v1/engine/operations`, `GET /v1/openapi.json` |
| JSON-RPC | `POST /rpc` (batches run in order; `rpc.discover`) |
| Health | `GET /v1/health` (no token) |

## Run it

```bash
dart run bin/zarvan_api.dart --project /path/to/game          # MCP over stdio
dart run bin/zarvan_api.dart --http --project /path/to/game   # REST + JSON-RPC + MCP
```

Flags: `--read-only`, `--allow <glob>`, `--deny <glob>`, `--log`, `--port`,
`--bind`, `--token`, `--rotate-token`, `--max-result-bytes`, `--requests-per-minute`.

## Behavior

- Reads change nothing. Writes are validated, applied immediately and undoable with `undo.undo`.
- Destructive writes return a preview and a confirmation token.
- One result envelope: `{ok, data, warnings, diff?, undoId?, durationMs}` or `{ok:false, error:{code, message, hint?}}`.
- Loopback only by default, bearer token, Host-header check, size and rate limits.

See [Operations](../reference/operations.md), [Transports](../reference/transports.md)
and [tutorial 6](../tutorials/06-agent-api.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_api:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_api
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_api)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_api/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_api/)
- [All packages](../packages.md)
