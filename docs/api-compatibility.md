# ShennongDB API compatibility

Audit date: 2026-07-15

`ShennongData` 0.2.0 is compatible with the current ShennongDB v1 source
checkout at `/home/duansq/dev/services/shennong-db` (`0.5.2`, commit
`047c7bd`) for its public read/data-access surface.

## Contract matrix

| Client concern | R client endpoint | Current server route | Status |
| --- | --- | --- | --- |
| API identity | `GET /version` | `/version` | compatible in source; runtime gateway fallback required |
| Gateway identity fallback | `GET /api/v1/public-config` | `/api/v1/public-config` | compatible |
| Capabilities | `GET /api/v1/capabilities` | `/api/v1/capabilities` | compatible |
| Resource catalog | `GET /.well-known/shennong-agent.json` | same | compatible |
| Resource inspection | `GET /api/v1/agent/resources/{id}` | same | compatible |
| Axis IDs | `GET /api/v1/agent/resources/{id}/axes/{axis}` | same | compatible, capability-gated |
| Observation metadata | `GET /api/v1/agent/resources/{id}/metadata` | same | compatible, capability-gated |
| Gene resolution | `GET /api/v1/genes/resolve` | same | compatible |
| One-feature query | `POST /api/v1/query` | same | compatible |
| Batch query | `POST /api/v1/query/batch` | same | compatible, 1–100 server features |
| JSONL stream | `POST /api/v1/query/stream` | same | compatible |
| Arrow stream | requested through query stream | server returns `501` | correctly reported unavailable |
| Artifact download | `GET /api/v1/resources/{id}/artifacts/{artifact_id}/download` | same | compatible |

The request models match the current Rust types:

- single query: `resource`, `operation`, optional `feature`, `context`,
  `embedding`, `version`, and `options`;
- batch/stream query: `resource`, `operation`, `features`, `context`, `version`,
  and `options`;
- feature: `{ "type": "gene", "name": "..." }`.

Successful API payloads use the `{"data": ...}` envelope. Errors use
`error`, `code`, `message`, and `request_id`; `ShennongData` preserves HTTP
status, code, message, and optional details in `shennong_api_error`.

## Current running instance

The local public instance at `http://127.0.0.1:18080` reports ShennongDB
`0.5.2`. On the audit date:

- `/health`, `/healthz`, `/api/v1/capabilities`, the Agent manifest, Resource
  inspection, and gene resolution returned `200`;
- `/version` returned `404` at the Next.js gateway even though the current Rust
  server source defines the route;
- `/api/v1/public-config` returned API `v1` and service version `0.5.2`.

The client therefore treats only `404`/`405` from `/version` as a gateway
compatibility case and negotiates through `/api/v1/public-config`. Other
version errors remain fatal. This keeps strict API-v1 validation without
requiring a deployment rebuild.

## Verification

Fixtures in `inst/extdata/contract-fixtures/` freeze representative v1
responses for server version, capabilities, Resource inspection, identifier
resolution, and expression queries. Unit tests additionally cover gateway
fallback, structured errors, cursor paging, batch/axis capability gates, and
MCP bounds.

For a live instance, run:

```r
library(ShennongData)
con <- sn_connect("http://127.0.0.1:18080")
sn_api_compatibility(con)
sn_resources(con)
x <- sn_load_data("toil", connection = con)
sn_resolve_features(x, "YTHDF2", strict = TRUE)
```
