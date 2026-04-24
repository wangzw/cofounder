# Review Criteria — {{SKILL_NAME}} (schema variant)

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file lists the domain-specific review criteria for {{SKILL_NAME}}. Each criterion is a YAML block with fields: `id`, `name`, `version`, `checker_type`, `severity`, `conflicts_with`, `priority`, `incremental_skip`.

Checker types: `script`, `llm`, `hybrid`. See guide §12.3 for the full schema.

## Schema Variant Hints

Script-type checkers are well-suited for schema artifacts. Consider including:

- **Schema validation** (`checker_type: script`): e.g., `jsonschema validate` against a known valid example to verify the generated schema is syntactically correct.
- **Breaking-change detection** (`checker_type: script`): compare the new schema against the previous version to flag removed fields or narrowed types. Use `check-scaffold-sha.sh` as a reference for diff-based checking.
- **Required-field completeness** (`checker_type: script`): verify all required fields are present and typed correctly in generated schemas.
- **Semantic schema review** (`checker_type: llm`): check for naming consistency, overly permissive types, missing descriptions, or misaligned field semantics.
- **Cross-schema compatibility** (`checker_type: hybrid`): verify that schemas consumed by multiple clients maintain compatibility.

Example CR entry shape:

```yaml
- id: CR-S01
  name: "schema-validates"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-schema-valid.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

<!-- Writer: populate this file with CR entries specific to this skill's schema artifact domain -->
