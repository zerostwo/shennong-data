# Shennong OS/ShennongDB API compatibility

Audit date: 2026-07-26

`ShennongData` 0.2.0.9000 targets the ShennongDB `1.0.0` API-v1 read/data
contract through the user-facing Shennong OS/gateway. An explicit URL can
still target a compatible public/direct DB endpoint.

## Contract matrix

| Client concern | R client endpoint | Required OS/DB route | Client status |
| --- | --- | --- | --- |
| API identity | `GET /version` | `/version` | implemented |
| Gateway identity fallback | `GET /api/v1/public-config` | `/api/v1/public-config` | implemented for `404`/`405` |
| Capabilities | `GET /api/v1/capabilities` | `/api/v1/capabilities` | compatible |
| Resource catalog | `GET /.well-known/shennong-agent.json` | same | compatible |
| Resource inspection | `GET /api/v1/agent/resources/{id}` | same | compatible |
| Axis IDs | `GET /api/v1/agent/resources/{id}/axes/{axis}` | same | compatible, capability-gated |
| Observation metadata | `GET /api/v1/agent/resources/{id}/metadata` | same | compatible, capability-gated |
| Gene resolution | `GET /api/v1/genes/resolve` | same | compatible |
| One-feature query | `POST /api/v1/query` | same | compatible |
| Batch query | `POST /api/v1/query/batch` | same | compatible, 1–100 server features |
| JSONL stream | `POST /api/v1/query/stream` | same | compatible |
| Arrow stream | requested through query stream | capability-gated | unavailable unless advertised |
| Artifact download | `GET /api/v1/resources/{id}/artifacts/{artifact_id}/download` | same | compatible |

For governed production use, connect to the Shennong OS/gateway rather than a
DB administrative endpoint. `sn_connect(project_id = ...)` sends
`X-Shennong-Project-Id` on authenticated same-origin calls and includes
`project_id` in query/batch/stream bodies as a compatibility bridge. The OS
authorizes the Project and strips the body field before forwarding to a DB
deployment that does not yet accept it. With `project_id = NULL`, public/direct
DB behavior remains unchanged unless the server advertises
`project_scope_required = true`. That capability means projectless access
stops at public Resource discovery and is not sufficient for inspection,
resolution, querying, or Artifact download. `sn_api_compatibility()` reports
such a connection as incompatible and tells the caller to reconnect with a
Project UUID. Servers that omit the field or advertise it as false retain the
existing public/direct DB behavior. Non-`NULL` Project scope is UUID-only and
is normalized to lowercase canonical `8-4-4-4-12` form; aliases or slugs fail
before network access.

The request models match the current Rust types:

- single query: `resource`, `operation`, optional `feature`, `context`,
  `embedding`, `version`, and `options`;
- batch/stream query: `resource`, `operation`, `features`, `context`, `version`,
  and `options`;
- feature: `{ "type": "gene", "name": "..." }`.

Successful API payloads use the `{"data": ...}` envelope. Errors use
`error`, `code`, `message`, and `request_id`; `ShennongData` preserves HTTP
status, code, message, and optional details in `shennong_api_error`.

## DataBundle status

The target data materialization contract is
`shennong.dev/data-bundle/v1`. Resource metadata may declare it through
`metadata.data_bundle.schema_version`. Current legacy Resources that omit that
declaration are not reported as official complete bundles: ShennongData marks
their materialized provenance `status = "client_projection"` and records axis
and feature completeness explicitly.

Batch `meta.missing_features`, missing observation axes, query failures, and
ambiguous missing coordinates make a projection partial. Sparse output is
constructed only when `implicit_zero = true`; declared observation axes are
fetched before feature-by-observation matrix construction when supported.

## Deployment boundary

This document records a source and client contract, not a live deployment
assertion. The package default is the local Shennong OS entry point
`http://127.0.0.1:18081`. A deployment must still prove route forwarding,
authentication, Project binding, Artifact streaming, and the advertised
capabilities in its own API/browser/compose checks.

The client treats only `404`/`405` from `/version` as a gateway compatibility
case and then negotiates through `/api/v1/public-config`. Other version errors
remain fatal.

## Verification

Fixtures in `inst/extdata/contract-fixtures/` freeze representative v1
responses for server version, capabilities, Resource inspection, identifier
resolution, and expression queries. Unit tests additionally cover gateway
fallback, structured errors, cursor paging, batch/axis capability gates, and
MCP bounds. Compatibility tests also freeze both sides of the Project
requirement: an OS-style `project_scope_required = true` report fails without
a Project, while an older/direct DB capability document remains projectless.

For a live instance, run:

```r
library(ShennongData)
con <- sn_connect(
  "https://your-shennong-gateway.example",
  token = Sys.getenv("SHENNONG_TOKEN"),
  project_id = "550e8400-e29b-41d4-a716-446655440000"
)
sn_api_compatibility(con)
sn_resources(con)
x <- sn_load_data("toil", connection = con)
sn_resolve_features(x, "YTHDF2", strict = TRUE)
```
