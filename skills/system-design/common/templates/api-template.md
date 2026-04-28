# API Contract: {{API_GROUP_NAME}}

<!-- File-level front matter — fill all {{PLACEHOLDER}} fields before finalizing -->

| Field | Value |
|-------|-------|
| **File** | `api/API-{{NNN}}-{{slug}}.md` |
| **Owner module** | [M-{{NNN}}: {{module-name}}](../modules/M-{{NNN}}-{{slug}}.md) |
| **Status** | Draft |
| **Source Features** | {{F-NNN, F-NNN}} |
| **Direction** | {{internal \| external}} |
| **Protocol** | {{REST \| gRPC \| CLI}} |
| **Versioning policy** | {{e.g. "URL-versioned via /v1/ prefix; breaking changes increment the major segment; non-breaking additive changes do not require a new version"}} |

> **Self-contained file principle**: a coding agent must be able to implement every endpoint in
> this file by reading ONLY this file. All auth rules, error envelopes, rate-limit quotas, and
> data-model shapes must be present inline — not referenced by path to another file.

---

<!-- ═══════════════════════════════════════════════════════
     PER-ENDPOINT SECTION — replicate for each endpoint.
     L1 lint (check-api-per-endpoint-blocks.sh) enforces that
     EVERY **METHOD /path** heading is followed by all seven
     subsections in this exact order before the next endpoint
     heading or ### section. Do NOT reorder or omit any subsection.
     ═══════════════════════════════════════════════════════ -->

## Endpoints

### `{{METHOD}} {{/path}}`

<!-- Example: ### `POST /v1/tasks` -->

#### 1. Request

<!-- L1: "Request" subsection — table of all parameters + headers. -->
<!-- L2: The Request body example below MUST use real-looking values.
     FORBIDDEN inside ```json blocks:
       "..."  |  /* ... */  |  // ...  |  {}  |  "<placeholder>"
       "TBD"  |  "TODO"    |  "FIXME" |  "snapshot of above"
       "items": [...]  (array with only ellipsis — write at least one element)
     These patterns cause L2 lint failures. -->

**HTTP method + path:** `{{METHOD}} {{/path}}`

**Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Y | Bearer token — `Authorization: Bearer <access_token>` |
| `Content-Type` | Y | `application/json` |
| `{{X-Custom-Header}}` | {{Y\|N}} | {{description}} |

**Query parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `{{param_name}}` | `{{string\|integer\|boolean}}` | {{Y\|N}} | `{{default}}` | {{description}} |

**Body schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `{{field_name}}` | `{{string}}` | Y | {{description — e.g. "Human-readable task name; 1–200 chars"}} |
| `{{metadata}}` | `object` | N | {{description — e.g. "Arbitrary key-value pairs; max 16 keys, keys ≤ 64 chars"}} |

**Request body example:**

```json
{
  "name": "Deploy production build",
  "metadata": {
    "owner": "alice",
    "team": "platform"
  }
}
```

---

#### 2. Response

<!-- L1: "Response" subsection — success body schema + populated example. -->
<!-- L2: Response example must match every field in the Response table Body column.
     No "..." filler, no empty {}, no placeholder strings. -->

**Success body schema:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Stable resource identifier — e.g. `task_01abc` |
| `type` | `string` | Resource type discriminator — e.g. `"task"` |
| `name` | `string` | The name provided in the request |
| `metadata` | `object` | The metadata provided in the request |
| `created_at` | `string (ISO 8601)` | Creation timestamp |
| `{{additional_field}}` | `{{type}}` | {{description}} |

**Response body example:**

```json
{
  "id": "task_01abc123def456",
  "type": "task",
  "name": "Deploy production build",
  "metadata": {
    "owner": "alice",
    "team": "platform"
  },
  "created_at": "2026-04-28T09:15:00Z"
}
```

---

#### 3. Status Codes

<!-- L1: "Status codes" subsection — complete table of every code this endpoint returns. -->

| Code | Meaning | When | Example body |
|------|---------|------|-------------|
| `201` | Created | Resource was successfully created | `{"id":"task_01abc123def456","type":"task","name":"Deploy production build","metadata":{"owner":"alice","team":"platform"},"created_at":"2026-04-28T09:15:00Z"}` |
| `400` | Bad request | Required field missing or validation failed | `{"type":"error","error":{"type":"invalid_request_error","message":"name is required"}}` |
| `401` | Unauthorized | Missing or invalid `Authorization` header | `{"type":"error","error":{"type":"authentication_error","message":"invalid API key"}}` |
| `403` | Forbidden | Caller lacks required role or scope | `{"type":"error","error":{"type":"permission_error","message":"insufficient permissions"}}` |
| `409` | Conflict | A resource with this name already exists | `{"type":"error","error":{"type":"conflict_error","message":"task with name 'Deploy production build' already exists"}}` |
| `429` | Too many requests | Rate limit exceeded | `{"type":"error","error":{"type":"rate_limit_error","message":"rate limit exceeded; retry after 30s"}}` |
| `500` | Internal server error | Unexpected server-side failure | `{"type":"error","error":{"type":"api_error","message":"internal server error"}}` |

---

#### 4. Error Model

<!-- L1: "Error model" subsection — error envelope shape + all error codes + retry semantics. -->

**Error envelope shape (all non-2xx responses):**

```json
{
  "type": "error",
  "error": {
    "type": "{{error_type_string}}",
    "message": "{{human-readable description}}"
  }
}
```

**Error codes enumerated:**

| `error.type` | HTTP status | Meaning | Retryable |
|-------------|-------------|---------|-----------|
| `invalid_request_error` | 400 | Malformed request or failed field validation | No |
| `authentication_error` | 401 | Missing, expired, or invalid credentials | No — re-authenticate first |
| `permission_error` | 403 | Caller authenticated but lacks required role/scope | No |
| `not_found_error` | 404 | Requested resource does not exist (or existence is concealed) | No |
| `conflict_error` | 409 | Uniqueness constraint violated | No — resolve conflict first |
| `rate_limit_error` | 429 | Quota exhausted for this window | Yes — after `Retry-After` seconds |
| `api_error` | 500 | Unexpected server-side failure | Yes — exponential backoff |

**Retry semantics:**

- `rate_limit_error` (429): read the `Retry-After` response header (seconds). Use exponential
  backoff starting at the indicated delay with ±10 % jitter.
- `api_error` (500): retry up to 3 times with exponential backoff (base 1 s, cap 30 s, ±10 %
  jitter). Abandon if the third attempt also fails.
- All other error types: do not retry — the request will not succeed without caller-side changes.

---

#### 5. Auth

<!-- L1: "Auth" subsection — token type + required scopes + roles/permissions matrix. -->

**Authentication mechanism:**

- **Token type:** `{{Bearer JWT | API key via x-api-key header | mTLS client certificate}}`
- **Header:** `Authorization: Bearer {{access_token}}`
- **Token scope required:** `{{e.g. tasks:write}}`

**Authorization rules (roles/permissions matrix):**

| Role | Allowed | Condition |
|------|---------|-----------|
| `{{Admin}}` | Yes | Any workspace |
| `{{Developer}}` | Yes | Own workspace only — cross-workspace access returns `404` (existence-concealment) |
| `{{ReadOnly}}` | No | — |
| `internal-only` | N/A | If this endpoint is internal, replace this table with: "internal-only — invoked by M-{{NNN}}; no external callers" |

**Workspace scoping:** {{e.g. "request must carry a workspace-scoped key; cross-workspace access
returns 404 (existence-concealment) — never 403, to prevent resource enumeration"}}

---

#### 6. Rate Limits

<!-- L1: "Rate limits" subsection — quota, window, throttle behavior, backoff. -->

| Dimension | Value |
|-----------|-------|
| **Quota** | `{{60}}` requests |
| **Window** | `{{1 minute}}` per `{{workspace \| API key \| user}}` |
| **Shared bucket** | `{{e.g. workspace.mutations — shared with POST /v1/tasks and PATCH /v1/tasks/:id}}` |
| **Throttle behavior** | Returns `429` with `Retry-After: {{30}}` header when quota is exhausted |
| **Burst allowance** | `{{e.g. up to 10 requests in any 1-second window before throttling}}` |
| **Backoff guidance** | Exponential backoff starting at `Retry-After` value, ±10 % jitter, cap at 60 s |

---

#### 7. Examples

<!-- L1: "Examples" subsection — at least one full round-trip request/response pair. -->

**Example 1 — Happy path (create a task)**

```bash
curl -X POST "https://api.{{example.com}}/v1/tasks" \
  -H "Authorization: Bearer sk-ant-api03-abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Deploy production build",
    "metadata": {
      "owner": "alice",
      "team": "platform"
    }
  }'
```

**Response (201 Created):**

```json
{
  "id": "task_01abc123def456",
  "type": "task",
  "name": "Deploy production build",
  "metadata": {
    "owner": "alice",
    "team": "platform"
  },
  "created_at": "2026-04-28T09:15:00Z"
}
```

**Example 2 — Validation error (missing required field)**

```bash
curl -X POST "https://api.{{example.com}}/v1/tasks" \
  -H "Authorization: Bearer sk-ant-api03-abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {
      "owner": "alice"
    }
  }'
```

**Response (400 Bad Request):**

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "name is required"
  }
}
```

---

<!-- ═══════════════════════════════════════════════════════
     END PER-ENDPOINT BLOCK
     Replicate the seven-subsection pattern above for each
     additional endpoint in this API group.
     ═══════════════════════════════════════════════════════ -->

---

## Authentication & Permissions (File-level Summary)

<!-- Omit this section ONLY if the file has exactly one endpoint — all auth content lives
     in that endpoint's block. When two or more endpoints share the same auth mechanism,
     summarize here for readability, but NEVER replace the per-endpoint Auth subsection. -->

- **Auth mechanism:** `{{e.g. "API key via Authorization: Bearer header; JWT cookie for admin surface"}}`
- **Role matrix overview:** `{{Developer}}` / `{{OrgAdmin}}` / `{{Admin}}` — per-endpoint permitted
  roles are listed in each endpoint's Auth subsection.
- **Beta headers:** `{{e.g. "endpoints flagged [beta] require anthropic-beta: managed-agents-2026-04-01"
  — omit if no beta endpoints}}`
- **Dual-surface paths:** `{{e.g. "all /v1/* paths are also available at /api/v1/* on the native
  surface" — omit if not applicable}}`

---

## Error Codes (File-level Summary)

<!-- Omit this section if error codes are fully enumerated per-endpoint and no file-level
     aggregation is needed. Include it when the same error type appears across multiple endpoints
     and you want a single reference table. Per-endpoint Error model subsections remain mandatory. -->

| Code | Meaning | Trigger |
|------|---------|---------|
| `invalid_request_error` | Validation failed | Missing required field or type mismatch |
| `authentication_error` | Auth failed | Missing/expired/invalid token |
| `permission_error` | Authz failed | Caller lacks required role |
| `not_found_error` | Resource absent | ID does not exist in caller's workspace |
| `conflict_error` | Uniqueness violated | Duplicate name or idempotency replay with differing body |
| `rate_limit_error` | Quota exhausted | Over the per-window request quota |
| `api_error` | Server failure | Unexpected internal error |

---

## Test Scenarios

<!-- Omit this section only if every endpoint is trivial CRUD with no edge cases.
     Focus on boundary values, error paths, and concurrency — NOT happy-path duplicates. -->

| Endpoint | Scenario | Input | Expected Result |
|----------|----------|-------|-----------------|
| `POST /v1/tasks` | Missing required field `name` | `{"metadata":{"owner":"alice"}}` | `400 invalid_request_error — name is required` |
| `POST /v1/tasks` | Duplicate name in same workspace | `{"name":"Deploy production build"}` (second time) | `409 conflict_error` |
| `POST /v1/tasks` | Rate limit exceeded | 61st request within 1-minute window | `429 rate_limit_error`, `Retry-After: 30` header |
| `POST /v1/tasks` | Invalid auth token | `Authorization: Bearer expired-token` | `401 authentication_error` |
| `POST /v1/tasks` | Cross-workspace key | Valid key scoped to a different workspace | `404 not_found_error` (existence-concealment) |

---

## Constraints (File-level Summary)

<!-- Omit this section if there are no cross-endpoint shared constraints.
     Per-endpoint deviations MUST still be listed in that endpoint's Rate limits subsection. -->

- `{{e.g. "All endpoints in this group share the workspace.mutations rate-limit bucket (60 req/min/workspace)"}}`
- `{{e.g. "All list endpoints use cursor-based pagination: limit 1–100, default 20; cursor is opaque"}}`
- `{{e.g. "All mutation endpoints honour Idempotency-Key header with a 24-hour replay window; a replayed key with a differing body returns 409"}}`

---

## Rules (authoring reference — do NOT copy into generated files)

<!--
     These rules are for the writer producing an api/API-NNN-{slug}.md file from this
     template. They should NOT appear in the generated output; strip this section before
     finalizing.
-->

- **Authoritative**: design API contracts refine and supersede PRD feature-level API contracts —
  they add parameter types, error codes, examples, and constraints. If a PRD feature's API
  contract conflicts, this design version takes precedence.
- **Direction**: `internal` = inter-module interface; `external` = exposed to outside consumers.
- **Protocol**: delete the protocol sections not applicable to this file (REST / gRPC / CLI).
- **One file per API group**: group related endpoints together; not one file per endpoint.
- **Per-endpoint completeness (L1 lint)**: every endpoint MUST carry all seven subsections in the
  order defined above. L1 lint (check-api-per-endpoint-blocks.sh) will fail the build if any
  subsection is missing or out of order. The seven subsections are:
  1. Request  2. Response  3. Status codes  4. Error model  5. Auth  6. Rate limits  7. Examples
- **Forbidden placeholder patterns (L2 lint)**: `check-placeholder-json.sh` greps inside every
  ```json block. These patterns cause a mechanical lint failure:
    `"..."` | `/* ... */` | `// ...` | `{}` (literal empty body) | `"<placeholder>"` |
    `"TBD"` | `"TODO"` | `"FIXME"` | `"snapshot of above"` | `"items": [...]` (array with only ellipsis)
- **Schema–example consistency**: every field in a Response table's Body column must appear as a
  key in the Response body example. Every key in the example must appear in the Body column
  (except standard envelope fields: `id`, `type`, `created_at`).
- **Dual-surface paths**: if an endpoint is served on both `/v1/*` and `/api/v1/*`, list both
  paths in the endpoint's METHOD + path header line. A file-level note is not sufficient.
- **Test Scenarios vs. Examples**: Examples show happy-path usage. Test Scenarios cover boundaries,
  error paths, and concurrency. Do not duplicate happy-path in Test Scenarios.
- **Omit whitelist** (only these sections may be omitted):
  - *Authentication & Permissions (File-level Summary)* — only when the file has exactly one endpoint
  - *Constraints (File-level Summary)* — when no cross-endpoint shared constraints exist
  - *Error Codes (file-level table)* — when error codes are fully enumerated per-endpoint
  - *Test Scenarios* — only if every endpoint is trivial CRUD with no edge cases
  - All per-endpoint subsections (the seven L1-enforced blocks) are mandatory and cannot be omitted.
- **Precise language**: write "returns 400 when X" and "rejects if Y" — not "might return an error".
