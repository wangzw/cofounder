# Review Criteria — {{SKILL_NAME}} (code variant)

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file lists the domain-specific review criteria for {{SKILL_NAME}}. Each criterion is a YAML block with fields: `id`, `name`, `version`, `checker_type`, `severity`, `conflicts_with`, `priority`, `incremental_skip`.

Checker types: `script`, `llm`, `hybrid`. See guide §12.3 for the full schema.

## Code Variant Hints

Script-type checkers are especially valuable for code artifacts. Consider including:

- **Lint/format checks** (`checker_type: script`): e.g., `ruff`, `eslint`, `gofmt`. Use `script_path` to point to a wrapper shell script.
- **Type-check** (`checker_type: script`): e.g., `tsc --noEmit` for TypeScript, `mypy` for Python. These produce deterministic pass/fail results.
- **Compile check** (`checker_type: script`): verify the generated code compiles without errors.
- **Test execution** (`checker_type: script`): if the skill generates test files, run them.
- **Semantic code review** (`checker_type: llm`): check for logic errors, anti-patterns, security issues not caught by static analysis.

Example CR entry shape:

```yaml
- id: CR-S01
  name: "lint-pass"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-lint.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

<!-- Writer: populate this file with CR entries specific to this skill's code artifact domain -->
