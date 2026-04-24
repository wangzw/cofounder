# Review Criteria — {{SKILL_NAME}} (hybrid variant)

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file lists the domain-specific review criteria for {{SKILL_NAME}}. Each criterion is a YAML block with fields: `id`, `name`, `version`, `checker_type`, `severity`, `conflicts_with`, `priority`, `incremental_skip`.

Checker types: `script`, `llm`, `hybrid`. See guide §12.3 for the full schema.

## Hybrid Variant Hints

Hybrid artifacts mix multiple file types (e.g., markdown docs + code + schemas) in one skill output. Key considerations:

- **Per-file-type routing in `run-checkers.sh`** (`checker_type: script`): the `run-checkers.sh` script must dispatch different checkers based on file extension. Document sub-artifacts follow document criteria; code sub-artifacts follow code criteria.
- **Cross-file-type consistency** (`checker_type: hybrid`): verify that code artifacts implement exactly the interfaces described in documentation artifacts, and that schema artifacts match the data models referenced in code.
- **File-type detection** (`checker_type: script`): add a CR that validates each output file has the expected extension and structure for its declared artifact type.
- **Semantic coherence** (`checker_type: llm`): verify that the mixed artifact set forms a coherent whole — that documentation, code, and schema artifacts describe the same system with consistent naming and semantics.

Example CR entry shape (per-type routing):

```yaml
- id: CR-S01
  name: "per-file-type-routing"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-file-type-routing.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

<!-- Writer: populate this file with CR entries specific to this skill's hybrid artifact domain -->
