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

**Owning module:** [M-{XXX}: {name}](../modules/M-{XXX}-{slug}.md)
**Serving features:** F-001, F-003

### Endpoints

Adapt the format below to match the protocol. Examples for REST, gRPC, and CLI follow.

#### REST Endpoints

**{METHOD} {/path}**

**Description:** {what it does}

**Request:**

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| {name} | path/query/body | string | Y | {desc} |

**Request example:**

```json
{}
```

**Response:**

| Status Code | Meaning | Body |
|-------------|---------|------|
| 200 | Success | {structure} |
| 400 | Bad request | `{"error": "..."}` |
| 404 | Not found | `{"error": "..."}` |

**Response example:**

```json
{}
```

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

### Authentication & Permissions

{Auth method, required permissions — omit if not applicable}

### Test Scenarios

{Key scenarios a coding agent must cover when testing this API. Focus on boundary values, error paths, and concurrency — not happy-path duplicates of the endpoint examples above.}

| Endpoint | Scenario | Input | Expected Result |
|----------|----------|-------|-----------------|
| {e.g. POST /tasks} | {e.g. missing required field} | `{"description": "no name"}` | 400, `{"error": "name is required"}` |
| {e.g. POST /tasks} | {e.g. duplicate name} | `{"name": "existing"}` | 409, `{"error": "task already exists"}` |
| {e.g. DELETE /tasks/:id} | {e.g. idempotent delete} | DELETE twice with same ID | First: 204; Second: 204 (not 404) |
| {e.g. GET /tasks} | {e.g. pagination boundary} | `?limit=0` | 400, or empty list depending on contract |

### Constraints

- {Rate limiting, size limits, idempotency, etc.}

## Rules

- **Authoritative**: design API contracts refine and supersede PRD feature-level API contracts — they add parameter types, error codes, examples, and constraints. If a PRD feature's API Contract conflicts, the design version takes precedence
- **Direction**: `internal` = inter-module interface, `external` = exposed to outside consumers
- **Protocol**: each API file uses only the format matching its Protocol (REST, gRPC, or CLI) — delete the other protocol sections from the template
- **One file per API group**: group related endpoints together (e.g., all task CRUD in one file), not one file per endpoint
- **Request/Response examples are mandatory**: examples prevent ambiguity more than schemas alone
- **Test Scenarios complement examples**: endpoint examples show happy-path usage; Test Scenarios cover boundaries, error paths, and concurrency. Don't duplicate happy-path in Test Scenarios. Focus on cases where the expected behavior is non-obvious or easily missed.
- **Omit empty sections**: no Authentication for internal-only APIs, no Constraints if none exist, no Test Scenarios if the API is trivial (single CRUD endpoint with no edge cases)
- **Precise language**: "returns 400 when", "rejects if" — not "might return an error"
