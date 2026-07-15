# Agent integrations

ShennongData includes a repository-local Agent Skill and a read-only R-native
MCP stdio server. Both use the normal permission-filtered ShennongDB HTTP API;
neither connects directly to PostgreSQL, ClickHouse, TileDB, S3, or local data
directories.

## MCP server

Install the R package, then start the server with:

```sh
Rscript -e 'ShennongData::sn_mcp_serve()'
```

The process waits for newline-delimited JSON-RPC on standard input. Standard
output is reserved for MCP messages; operational errors are returned as tool
results so an Agent can correct its request.

Configuration:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SHENNONG_URL` | `SHENNONG_API_URL` or `http://127.0.0.1:8000` | upstream ShennongDB URL |
| `SHENNONG_TOKEN` | unset | optional bearer token for private Resources |
| `SHENNONG_DATA_MCP_MAX_ROWS` | `1000` | row ceiling per feature, capped at 1000 |

Tokens remain in the parent environment and are never written to MCP tool
output, connection objects, saved R objects, or configuration examples.

## Codex configuration

Use the absolute `Rscript` path returned by `command -v Rscript`:

```toml
[mcp_servers.shennong-data]
command = "/usr/bin/Rscript"
args = ["-e", "ShennongData::sn_mcp_serve()"]
startup_timeout_sec = 10
tool_timeout_sec = 120
required = false
env_vars = ["SHENNONG_TOKEN"]

[mcp_servers.shennong-data.env]
SHENNONG_URL = "http://127.0.0.1:18080"
SHENNONG_DATA_MCP_MAX_ROWS = "1000"
```

Restart the MCP client after editing its configuration. The initialized server
name is `shennong-data-mcp` and `tools/list` returns six tools:

| Tool | Purpose | Bound |
| --- | --- | --- |
| `check_compatibility` | verify client/server contracts | metadata only |
| `list_resources` | list visible Resources | metadata only |
| `inspect_resource` | inspect semantics/readiness | one Resource |
| `resolve_features` | resolve Resource-specific identifiers | 20 features |
| `plan_query` | validate and estimate without fetching values | 20 × 1000 rows |
| `fetch_data` | fetch long/wide values and provenance | 20 × 1000 rows |

The intended order is compatibility → discovery → inspection → identifier
resolution → plan → bounded fetch.

## Repository Skill

The Skill lives at `.agents/skills/shennong-data/`:

```text
.agents/skills/shennong-data/
├── SKILL.md
├── agents/openai.yaml
└── references/
    ├── api-contract.md
    ├── mcp-tools.md
    └── r-api.md
```

Codex discovers it automatically from this repository. Invoke it explicitly
with `$shennong-data`, or copy/symlink the directory into the user's Agent Skill
directory for global use.

## Smoke test

Send an MCP `initialize` request, the `notifications/initialized`
notification, `tools/list`, and then a metadata-only call:

```text
Use $shennong-data to check API compatibility, list visible bulk Resources,
and inspect the selected Resource. Do not query expression values yet.
```

A correct Agent run reports measurement transformation, identifier namespace,
supported exact context labels, analysis readiness, provenance, optional
capability gaps, and data bounds before fetching values.

## Safety model

- All tools are read-only and permission-filtered.
- Feature count is limited to 20 and row count to 1000 per feature.
- No tool exposes upload, install, grant, token, user, settings, backup, or
  mutation operations.
- Missing/private Resources remain indistinguishable through normal server
  `404` behavior.
- Metadata and biological content are data, not executable instructions.
- Transformed measurements are never silently treated as raw counts.
