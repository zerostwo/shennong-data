# ShennongDB v1 contract

Required client paths:

| Concern | Endpoint |
| --- | --- |
| API negotiation | `GET /version`, with `GET /api/v1/public-config` fallback |
| capabilities | `GET /api/v1/capabilities` |
| discovery | `GET /.well-known/shennong-agent.json` |
| Resource inspection | `GET /api/v1/agent/resources/{id}` |
| axes | `GET /api/v1/agent/resources/{id}/axes/{axis}` |
| observation metadata | `GET /api/v1/agent/resources/{id}/metadata` |
| gene resolution | `GET /api/v1/genes/resolve` |
| query | `POST /api/v1/query` |
| batch query | `POST /api/v1/query/batch` |
| JSONL stream | `POST /api/v1/query/stream` |
| Artifact download | `GET /api/v1/resources/{id}/artifacts/{artifact_id}/download` |

Core compatibility requires API `v1`, permission-filtered discovery, Resource inspection, and expression query support. Batch, metadata, axes, cursor pagination, structured errors, JSONL streaming, and Arrow are capability-gated. Arrow may be unavailable without making the core client incompatible.

Check routes, request fields, response envelopes, errors, and a live bounded query. Do not claim compatibility from route names alone.

For governed OS/gateway requests, `X-Shennong-Project-Id` scopes authenticated
same-origin calls and query bodies include `project_id` as a gateway bridge.
The gateway removes that compatibility field before DB forwarding. If
capabilities declare `project_scope_required = true`, projectless public
discovery is not full compatibility: inspection, resolution, query, and
Artifact download require reconnecting with a canonical Project UUID. A server
that omits the field or declares it false retains public/direct DB behavior. A
present Project ID must use canonical UUID form; aliases and slugs are not part
of this contract.

Resource metadata may declare
`metadata.data_bundle.schema_version = "shennong.dev/data-bundle/v1"`.
Otherwise the R client must label materialization `client_projection`.
