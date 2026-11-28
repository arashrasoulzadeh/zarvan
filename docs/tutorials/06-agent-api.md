# 6 · Drive the engine from an AI agent (MCP, REST, CLI)

Everything the studio and the CLI can do to a project is also an **operation** an agent can call: build a level, validate
it, step the world, undo a mistake. One registry, four doors:

| Door | Use it for |
|---|---|
| `zarvan <group> <verb>` | scripts, CI, humans in a terminal |
| MCP tools (`zarvan_api`, stdio or HTTP) | Claude Desktop, Claude Code and other MCP clients |
| REST `POST /v1/<group>/<verb>` | your own services |
| JSON-RPC `POST /rpc` | batches, typed clients |

The full list, with every parameter, is the generated [operations reference](../reference/operations.md).

## 1. Start the server

From a checkout of the engine repo:

```bash
cd packages/zarvan_api
dart run bin/zarvan_api.dart --project /path/to/your/game
```

That speaks MCP over stdio, which is what MCP clients launch. To use it from Claude Desktop add it to the client's MCP
server list:

```json
{
  "mcpServers": {
    "game-engine": {
      "command": "dart",
      "args": ["run", "/path/to/engine/packages/zarvan_api/bin/zarvan_api.dart", "--project", "/path/to/your/game"]
    }
  }
}
```

Useful server flags: `--read-only` (blocks non-read operation kinds, not in-memory world changes), `--deny 'release.*'`, `--allow 'level.*'`.

## 2. What an agent does

Start with `engine.capabilities`, `engine.operations`, and `engine.operation` to discover exact schemas and permissions. Keep a single MCP/HTTP server process for stateful world operations; separate CLI invocations do not share in-memory worlds.

A typical session, as tool calls:

1. `project.info`, `schema.components` - what is here, what can an entity hold?
2. `level.create`, `level.add_entity`, `level.move_entity`, `level.paint_tile` - build.
3. `level.validate` / `level.lint` with `playable: true` / `project.problems` - check it. Fix what they report.
4. `world.build` then `world.step` and `world.query` - run the level headlessly and look at the result. Nothing is written.
5. `undo.undo` - take back the last change. Journalled file edits are recorded in `.studio/undo/` (the last 100).

Removing things (`level.remove_entity`, `graph.remove_node`, ...) is **destructive**: the first call returns a preview and
a `confirmation` token, the second call with that token applies it. Tokens are tied to the server process and expire
after five minutes.

## 3. The same thing from a shell

```bash
zarvan level add-entity assets/levels/forest.json --name coin --components position
zarvan level lint assets/levels/forest.json --playable
zarvan undo undo
zarvan --read-only level list --json     # the exact result envelope
```

Registry-backed commands take `--json` (print the envelope), `--stdin` or `--args '{...}'` (parameters as JSON), and file writes take
`--dry-run` to preview. The `world.patch` operation instead takes `dryRun: true` in its JSON parameters.

## 4. Over HTTP

```bash
dart run bin/zarvan_api.dart --http --project /path/to/your/game
TOKEN=$(cat /path/to/your/game/.studio/api-token)
curl -H "Authorization: Bearer $TOKEN" -X POST localhost:7421/v1/level/list
curl -H "Authorization: Bearer $TOKEN" localhost:7421/v1/openapi.json
```

The server listens on localhost by default, needs the token for everything except `GET /v1/health`, limits request and result
sizes and rate, and logs each call (no arguments, no results) to `.studio/api-requests.jsonl`. Send an
`Idempotency-Key` header with a write to make retries safe. Configuration can live in `zarvan_api.yaml` in the project.


## 5. A complete sandbox-world workflow

Run these commands in Bash with `curl` and `jq` installed, after starting
the HTTP server above and setting `TOKEN`. This example creates only an
in-memory world. Use the same server process for every call.

```bash
set -euo pipefail

api() {
  curl -fsS -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -X POST "http://127.0.0.1:7421/v1/$1" -d "$2"
}

built=$(api world/build '{"json":{"entities":[{"name":"probe","components":{"position":{"x":0,"y":0},"velocity":{"x":1,"y":0}}}]},"systems":["movement"]}')
world_id=$(jq -er 'select(.ok).data.worldId' <<< "$built")
entity_id=$(jq -er '.data.named.probe' <<< "$built")

patch=$(jq -n --arg w "$world_id" --argjson id "$entity_id" \
  '{worldId:$w,strict:true,dryRun:true,patch:{entities:[{id:$id,components:{position:{x:10,y:20}}}]}}')

# Validate the proposal without mutating state.
api world/patch "$patch" | jq -e '.ok and .data.ok'

# Apply the same checked patch and inspect the resulting component.
api world/patch "$(jq '.dryRun = false' <<< "$patch")" | jq -e '.ok and .data.applied'
query=$(jq -n --arg w "$world_id" '{worldId:$w,component:"position"}')
api world/query "$query" | jq '.data'

# Release the in-memory world.
api world/discard "$(jq -n --arg w "$world_id" '{worldId:$w}')" | jq -e '.ok'
```

The position query should include the probe at `x: 10, y: 20`. The world is
not a running Flutter game; only the headless systems chosen at build time
are installed. These world operations do not write project content, so they
are allowed even on a read-only server unless the allow/deny policy excludes
them. Inspect both outer `ok` and inner validation results before applying.

## What an agent cannot do

Operations that need the Flutter SDK (`project.create`, `project.upgrade`, `release.build`) exist as CLI commands only
(`zarvan create`, `upgrade`, `build-release`); `engine.capabilities` lists them as unsupported.
