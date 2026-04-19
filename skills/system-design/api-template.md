# API Contract Template

Each file describes a group of related API endpoints. **Self-contained** — a coding agent implements the API by reading only this file.

## Template

The API contract file follows this structure. Omit any section that has no useful content.

### Header

```
# API-{001}: {API Group Name}

> **Direction:** internal | external  **Protocol:** REST | gRPC | CLI
```

### Context

**Owning module(s):** [M-{XXX}: {name}](../modules/M-{XXX}-{slug}.md)
If multiple modules jointly serve this API, list all with their responsibility scope.
**Serving features:** F-001, F-003

### Endpoints

Adapt the format below to match the protocol. Examples for REST, gRPC, and CLI follow.

#### REST Endpoints

Each endpoint MUST include every subsection below — Description, Authentication & Permissions, Request (including headers), Request example, Response, Response example, and Constraints. No subsection is optional at the endpoint level. File-level notes (e.g. a Dual-Surface block at the top of the file) do not substitute for per-endpoint fields — a reader opening a single endpoint must see its auth and constraints inline.

**{METHOD} {/path}**

**Description:** {what it does}

**Authentication & Permissions:**

| Requirement | Value |
|------------|-------|
| Required headers | {e.g. `x-api-key`, `anthropic-version`, `anthropic-beta: managed-agents-2026-04-01`} |
| Roles permitted | {e.g. Developer, OrgAdmin, Admin — or `internal-only`} |
| Workspace scoping | {e.g. "request must carry a workspace-scoped key; cross-workspace access returns 404 (existence-concealment)"} |

For internal-only endpoints, write `internal-only — invoked by M-XXX; no external callers` and skip roles/scoping.

**Request:**

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| {name} | path/query/body/header | string | Y | {desc} |

Location: `path` / `query` / `body` / `header` (e.g., Authorization, X-Request-ID)

**Request example:**

{Populated JSON — never `{}`. Include all required fields with realistic values. For endpoints with no request body (e.g. DELETE), show the full HTTP line with headers instead.}

```json
{
  "name": "example-task",
  "metadata": {"owner": "alice"}
}
```

**Response:**

| Status Code | Meaning | Body |
|-------------|---------|------|
| 200 | Success | {structure} |
| 400 | Bad request | `{"type":"error","error":{"type":"invalid_request_error","message":"..."}}` |
| 404 | Not found | `{"type":"error","error":{"type":"not_found_error","message":"..."}}` |

**Response example:**

{Populated JSON of the success body — never `{}`. Include a realistic object with stable-looking IDs (e.g. `task_01abc...`) and timestamps.}

```json
{
  "id": "task_01abc",
  "type": "task",
  "name": "example-task",
  "created_at": "2026-04-19T10:00:00Z"
}
```

**Constraints:**

- {Idempotency — e.g. "idempotent on `Idempotency-Key` header within 24 h window; differing body returns 409"}
- {Rate limit — e.g. "60 req/min/workspace shared with other mutations; governed by rate_limit_configs"}
- {Size — e.g. "request body ≤ 1 MiB; response `data[]` ≤ 100 items without cursor"}
- {Concurrency — e.g. "max 8 concurrent requests per key"}

For internal-only endpoints, list at minimum: concurrency cap, timeout, and idempotency semantics.

#### gRPC Services

```protobuf
service TaskService {
  rpc CreateTask(CreateTaskRequest) returns (CreateTaskResponse);
  rpc ListTasks(ListTasksRequest) returns (stream Task);
}

message CreateTaskRequest {
  string name = 1;
  string description = 2;
}

message CreateTaskResponse {
  string task_id = 1;
  Task task = 2;
}
```

**RPC: CreateTask**

**Description:** {what it does}

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Y | {desc} |

**Error codes:**

| gRPC Code | When | Description |
|-----------|------|-------------|
| INVALID_ARGUMENT | name is empty | {detail} |
| ALREADY_EXISTS | duplicate name | {detail} |

#### CLI Subcommands

**`{command} {subcommand} [flags]`**

**Description:** {what it does}

| Flag | Short | Type | Default | Description |
|------|-------|------|---------|-------------|
| --output | -o | string | stdout | {desc} |
| --format | -f | enum(json,table) | table | {desc} |

**Arguments:**

| Position | Name | Required | Description |
|----------|------|----------|-------------|
| 1 | {name} | Y | {desc} |

**Example:**

```bash
$ mytool task create --output json "My Task"
{"id": "t-001", "name": "My Task", "status": "created"}
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid input |
| 2 | Resource not found |

### Error Codes

| Code | Meaning | Trigger |
|------|---------|---------|
| {code} | {meaning} | {when} |

### Authentication & Permissions (File-level Summary)

{Summary only — each endpoint above MUST carry its own Authentication & Permissions block. This file-level summary lists the auth mechanism common to all endpoints and the role matrix overview. It does NOT replace per-endpoint fields.}

- **Auth mechanism:** {e.g. "API key via `x-api-key` header; JWT cookie for admin surface"}
- **Role matrix:** Developer / OrgAdmin / Admin — per-endpoint permitted roles are listed in each endpoint's block
- **Beta headers:** {e.g. "endpoints flagged [beta] require `anthropic-beta: managed-agents-2026-04-01`"}
- **Dual-surface paths:** {e.g. "all `/v1/*` paths are also available at `/api/v1/*` on the native surface" — if applicable}

Omit this file-level summary only when there is exactly one endpoint (all auth content lives in the endpoint block).

### Test Scenarios

{Key scenarios a coding agent must cover when testing this API. Focus on boundary values, error paths, and concurrency — not happy-path duplicates of the endpoint examples above.}

| Endpoint | Scenario | Input | Expected Result |
|----------|----------|-------|-----------------|
| {e.g. POST /tasks} | {e.g. missing required field} | `{"description": "no name"}` | 400, `{"error": "name is required"}` |
| {e.g. POST /tasks} | {e.g. duplicate name} | `{"name": "existing"}` | 409, `{"error": "task already exists"}` |
| {e.g. DELETE /tasks/:id} | {e.g. idempotent delete} | DELETE twice with same ID | First: 204; Second: 204 (not 404) |
| {e.g. GET /tasks} | {e.g. pagination boundary} | `?limit=0` | 400, or empty list depending on contract |

### Constraints (File-level Summary)

{Summary of constraints that apply uniformly across the endpoint group (e.g. shared rate-limit bucket, shared idempotency window, shared pagination contract). Per-endpoint deviations MUST still be listed in that endpoint's own Constraints block. This section never replaces per-endpoint Constraints.}

- {e.g. "All endpoints in this group share the `workspace.mutations` rate-limit bucket"}
- {e.g. "All list endpoints use cursor pagination with `limit` 1..100, default 20"}
- {e.g. "All mutation endpoints honor `Idempotency-Key` with a 24 h replay window"}

## Rules

- **Authoritative**: design API contracts refine and supersede PRD feature-level API contracts — they add parameter types, error codes, examples, and constraints. If a PRD feature's API Contract conflicts, the design version takes precedence
- **Direction**: `internal` = inter-module interface, `external` = exposed to outside consumers
- **Protocol**: each API file uses only the format matching its Protocol (REST, gRPC, or CLI) — delete the other protocol sections from the template
- **One file per API group**: group related endpoints together (e.g., all task CRUD in one file), not one file per endpoint
- **Per-endpoint completeness (REST)**: every endpoint MUST carry its own Authentication & Permissions block, Request table, Request example, Response table, Response example, and Constraints block. A file-level summary does NOT substitute — readers who open a single endpoint must see all of its contract inline. Reviewers reject endpoints where any of these subsections is missing or defers to "see file-level notes above".
- **Examples must be populated**: `{}` as a request or response body is rejected at review time. Examples must include realistic field values; every field in the corresponding Response table's Body column must appear in the example. For endpoints with no body (e.g. some DELETEs), show the full HTTP request line + headers and the full response envelope (e.g. `{"id":"...","type":"..._deleted"}`).
- **Dual-surface paths**: if endpoints are served on both a public (`/v1/*`) and native (`/api/v1/*`) surface, each endpoint block must list both paths in its `METHOD path` header — a file-level summary note is not sufficient; readers of a single endpoint must see both paths.
- **Test Scenarios complement examples**: endpoint examples show happy-path usage; Test Scenarios cover boundaries, error paths, and concurrency. Don't duplicate happy-path in Test Scenarios. Focus on cases where the expected behavior is non-obvious or easily missed.
- **Omit whitelist** (only these sections may be omitted):
    - *Authentication & Permissions (File-level Summary)* — omit only when the file has exactly one endpoint
    - *Constraints (File-level Summary)* — omit when there are no cross-endpoint shared constraints
    - *Error Codes (file-level table)* — omit when error codes are fully enumerated per-endpoint with no file-level aggregation needed
    - *Test Scenarios* — omit if every endpoint is trivial CRUD with no edge cases
  - All per-endpoint subsections are mandatory and cannot be omitted.
- **Precise language**: "returns 400 when", "rejects if" — not "might return an error"
