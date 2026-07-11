# ShennongDB API compatibility

The fixtures in `inst/extdata/contract-fixtures/` are a frozen replay of the
current ShennongDB v1 contract used by this package.

| Client concern | Current endpoint | Contract fixture | Proposed server enhancement |
| --- | --- | --- | --- |
| Server identity | `GET /version` | `version.json` | none |
| Capabilities | `GET /api/v1/capabilities` | `capabilities.json` | capability fields may grow |
| Resource discovery | `GET /api/v1/agent/resources/{id}` | `agent-resource-toil.json` | stable `data_contract` section |
| One-feature expression | `POST /api/v1/query` | `query-expression.json` | batch features, metadata views, cursor and streaming |

No fixture represents an endpoint that the current server does not expose.
