# MCP Workflow — ADO Docs Server Setup

## What the MCP server provides

The `ado-docs` MCP server indexes the prepped Azure DevOps REST API corpus and
exposes four tools to Claude Code:

| Tool | Purpose |
|------|---------|
| `ado_docs.endpoint` | Exact-match route+method lookup with ranking boost |
| `ado_docs.search` | Keyword search with optional `service_area` / `api_version` filters |
| `ado_docs.pack` | Returns paste-ready Markdown context within a char budget |
| `ado_docs.catalog` | Full endpoint table for a given service area |

---

## Step 1 — Enable MCP for Claude Code

### Option A — Global config (recommended for solo dev)

```bash
# If ~/.claude/mcp.json does not exist yet:
cp /home/n8/dev/Lua/ADO_Lua_SDK/.claude/mcp.json.example ~/.claude/mcp.json

# If ~/.claude/mcp.json already exists, merge the "ado-docs" server entry into
# the existing "mcpServers" object. Do not overwrite other entries.
```

The snippet to merge in:
```json
"ado-docs": {
  "command": "/home/n8/dev/Python/doc-indexer/.venv/bin/python",
  "args": ["-m", "ado_docs_mcp.server", "--corpus-dir", "/home/n8/dev/Python/doc-indexer/docs_prepped"]
}
```

### Option B — Project-local config

Place the file at `.claude/mcp.json` inside this repo (same content as
`.claude/mcp.json.example`). Claude Code will pick it up automatically when
your working directory is the repo root.

---

## Step 2 — Verify tools are visible

After setting up the config, start a new Claude Code session and confirm the
tools are available:

```
# Ask Claude Code to list available MCP tools, or run a quick test:
ado_docs.search(query="list projects")
```

Expected: Claude reports a result set from the indexed corpus, not an error.

If the server fails to start, check:
1. The venv Python path exists: `/home/n8/dev/Python/doc-indexer/.venv/bin/python`
2. The corpus dir is populated: `/home/n8/dev/Python/doc-indexer/docs_prepped`
3. The module is importable: `cd /home/n8/dev/Python/doc-indexer && .venv/bin/python -m ado_docs_mcp.server --help`

---

## Step 3 — First endpoint implementation checklist

Use this as a quick sanity check before writing any code:

- [ ] `ado_docs.endpoint` called — confirmed method + route
- [ ] `ado_docs.pack` called — full param/header/response schema in context
- [ ] Target file identified: `lua/ado/api/<domain>.lua`
- [ ] Function signature follows: `function M:fn(params, opts)`
- [ ] `client:request()` is the only outbound call
- [ ] Return shape matches success/error spec in `claude.md`
- [ ] Test file created/updated: `tests/<domain>_spec.lua`
- [ ] Mock transport used (no live HTTP in unit tests)
- [ ] Tests pass: `busted tests/`

---

## Corpus management

The prepped corpus lives at `/home/n8/dev/Python/doc-indexer/docs_prepped`.
If the ADO API docs are updated, re-run the doc-indexer pipeline in that repo
to refresh the corpus, then restart the MCP server (restart Claude Code session).
