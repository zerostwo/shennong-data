# MCP tools

Run the installed R-native stdio server with:

```sh
Rscript -e 'ShennongData::sn_mcp_serve()'
```

Environment:

| Variable | Default | Meaning |
| --- | --- | --- |
| `SHENNONG_URL` | `http://127.0.0.1:18081` | Shennong OS/gateway base URL |
| `SHENNONG_TOKEN` | unset | optional bearer token |
| `SHENNONG_PROJECT_ID` | unset | optional canonical governed Project UUID; aliases/slugs are rejected |
| `SHENNONG_DATA_MCP_MAX_ROWS` | `1000` | per-feature row ceiling, never above 1000 |

All six tools are read-only:

| Tool | Use | Bound |
| --- | --- | --- |
| `check_compatibility` | negotiate and report API features | no data values |
| `list_resources` | permission-filtered discovery | metadata only |
| `inspect_resource` | inspect semantics/readiness/provenance | one Resource |
| `resolve_features` | map identifiers within a Resource | at most 20 features |
| `plan_query` | validate and estimate without values | at most 20 features, 1000 rows each |
| `fetch_data` | execute a bounded long/wide query | at most 20 features, 1000 rows each |

Use this order: `check_compatibility` → `list_resources` → `inspect_resource` → `resolve_features` → `plan_query` → `fetch_data`.

If `check_compatibility` reports that the server requires Project scope, stop
before `list_resources`/inspection and set `SHENNONG_PROJECT_ID` to the intended
canonical UUID. A projectless public catalog is discovery-only on that gateway.

The server uses MCP protocol revision `2025-11-25` and supports compatible earlier revisions. Stdio messages are newline-delimited JSON-RPC. Standard output contains MCP messages only; credentials come from the parent environment.

Production clients should point `SHENNONG_URL` at the Shennong OS/gateway and
use a user PAT. Never configure a DB admin key.
