# Artifact Template — {{SKILL_NAME}} (schema variant)

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file defines the canonical structure for schema artifacts produced by {{SKILL_NAME}}. The writer sub-agent uses this template as a structural scaffold when authoring new schema files.

## Artifact Structure (schema variant)

Schema artifacts should specify:
- Schema format (e.g., JSON Schema Draft 7, OpenAPI 3.1, Avro, Protobuf)
- Top-level object type and namespace
- Required vs optional fields
- Validation constraints (patterns, enums, min/max values)
- Versioning strategy (e.g., `$schema` URI, version field)

<!-- Writer: describe the schema artifact's format, field hierarchy, and constraint style -->

## Required Fields

<!-- Writer: list all mandatory schema fields with their types and constraints -->

## Optional Fields

<!-- Writer: list optional schema fields and their conditions -->

## Breaking-Change Policy

<!-- Writer: specify which changes are considered breaking (removed fields, narrowed types, etc.) -->

## Example

<!-- Writer: provide a minimal valid schema artifact conforming to this template -->
