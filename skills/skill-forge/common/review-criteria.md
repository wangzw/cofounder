# Review Criteria

Each criterion is defined below as a human-readable description followed by a YAML code block. Checker scripts extract only the YAML blocks — the prose is for human readers only. All `conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via CR-L04 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**. Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

---

## Structural Criteria (Script-Type)

---

## CR-S01 skill-md-frontmatter

SKILL.md MUST have frontmatter with `name`, `version`, `description` keys. `description` MUST be ≤ 1024 characters and MUST start with the literal phrase "Use when" per guide §21.1.

```yaml
- id: CR-S01
  name: "skill-md-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S02 mode-routing-complete

The mode-routing table in SKILL.md MUST list all 4 base modes plus `--diagnose`. Every row in the routing table MUST include a "Loaded Files" column documenting which topic files are loaded for that mode.

```yaml
- id: CR-S02
  name: "mode-routing-complete"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-mode-routing.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S03 directory-skeleton

All required top-level directories — `generate/`, `review/`, `revise/`, `shared/`, `common/`, `scripts/` — MUST exist at the target skill root. Missing any directory means the skill scaffold is incomplete and downstream agents will fail on file-not-found errors.

```yaml
- id: CR-S03
  name: "directory-skeleton"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S04 subagent-file-inventory

All 8 required sub-agent prompts MUST be present: orchestrator (inline in SKILL.md) + 6 standalone files + reviewer has 2 prompts (standard + adversarial). Missing any prompt breaks the round loop.

```yaml
- id: CR-S04
  name: "subagent-file-inventory"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S05 scripts-inventory

All required shell scripts MUST exist and be executable. The full list (~13 scripts) is defined in guide §7.1. Missing or non-executable scripts cause silent failures in the review round.

```yaml
- id: CR-S05
  name: "scripts-inventory"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scripts-inventory.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-S06 config-schema

`config.yml` MUST contain all §21.2 top-level keys. A missing key causes the orchestrator to fall back to undefined defaults, producing non-deterministic behavior across environments.

```yaml
- id: CR-S06
  name: "config-schema"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-config-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S07 criteria-yaml-shape

Every criterion entry in the target skill's `review-criteria.md` MUST have the fields: `id`, `name`, `version`, `checker_type`, `severity`. `checker_type` MUST be one of `script`, `llm`, or `hybrid`. Malformed criteria are silently skipped by checker scripts.

```yaml
- id: CR-S07
  name: "criteria-yaml-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-criteria-yaml.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S08 ipc-footer-present

Every sub-agent prompt MUST contain the Snippet D fingerprint verbatim. Snippet D is the IPC footer that instructs the sub-agent to write output to the final path inside the sub-session and return exactly one ACK line. Without it, sub-agents return content inline and break the orchestrator's dispatch loop.

```yaml
- id: CR-S08
  name: "ipc-footer-present"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-ipc-footer.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S09 dispatch-log-snippet

The SKILL.md orchestrator body MUST contain the Snippet C fingerprint verbatim. Snippet C is the dispatch-log write pattern that ensures every sub-agent invocation is recorded for observability and retry recovery.

```yaml
- id: CR-S09
  name: "dispatch-log-snippet"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dispatch-log-snippet.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S10 trace-id-format

All `trace_id` occurrences in the generated skill MUST use the format `R<N>-<role-letter>-<nnn>` where `role-letter` ∈ `{C, P, W, V, R, S, J}` per guide §3.5. Malformed trace IDs break log correlation and metrics aggregation.

```yaml
- id: CR-S10
  name: "trace-id-format"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-trace-id-format.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S11 tool-permissions-coverage

`config.yml` `tool_permissions` MUST enumerate all 8 roles. `user-interaction: true` MUST appear ONLY on `domain_consultant`. Any other role with `user-interaction: true` violates the pure-dispatch contract.

```yaml
- id: CR-S11
  name: "tool-permissions-coverage"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-config-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S12 metrics-aggregate-verbatim

`scripts/metrics-aggregate.sh` and `scripts/lib/aggregate.py` sha256 hashes MUST match the values recorded in `shared-scripts-manifest.yml`. These files are shared infrastructure; silent divergence causes cross-skill metrics incompatibility.

```yaml
- id: CR-S12
  name: "metrics-aggregate-verbatim"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scaffold-sha.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-S13 artifact-pyramid

The target skill's `common/templates/artifact-template.md` MUST indicate a multi-level index structure (README + subdirectories). No single leaf file MAY exceed 300 lines. Flat single-file artifacts defeat the self-contained file principle.

```yaml
- id: CR-S13
  name: "artifact-pyramid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-artifact-pyramid.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S14 git-precheck-dependencies

The target skill's `git-precheck.sh` MUST verify: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8` per guide §21.0. Missing version checks allow the skill to run in unsupported environments and produce hard-to-debug failures.

```yaml
- id: CR-S14
  name: "git-precheck-dependencies"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dependencies.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-L01 orchestrator-pure-dispatch

The orchestrator body MUST explicitly forbid: reading leaf files, summarizing content, computing verdicts, rewriting artifacts, and analyzing issue priority. MUST include an explicit "Pure dispatch + bookkeeping only" statement. An orchestrator that does semantic work violates the role boundary and creates non-deterministic round behavior.

```yaml
- id: CR-L01
  name: "orchestrator-pure-dispatch"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-L02 ack-contract-fidelity

Every sub-agent prompt MUST enforce the ACK contract: "Write to final path inside sub-session" and "Task return is one ACK line". Phrases like "return the full output" or "include the content in your reply" are FORBIDDEN. Violating the ACK contract causes the orchestrator to receive inline content instead of a file path, breaking state management.

```yaml
- id: CR-L02
  name: "ack-contract-fidelity"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-L03 description-is-trigger

SKILL.md `description` MUST answer "when to invoke this skill" — not "what the skill does internally". A description that describes internal mechanics rather than trigger conditions prevents correct skill selection by the routing layer.

```yaml
- id: CR-L03
  name: "description-is-trigger"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L04 criteria-internally-consistent

No two criteria in the target's `review-criteria.md` MUST have `conflicts_with` references that create oscillation-prone pairs per guide §13.1. Oscillating criteria cause the convergence judge to never reach `converged` verdict.

```yaml
- id: CR-L04
  name: "criteria-internally-consistent"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L05 artifact-template-self-contained

The target skill's artifact template MUST follow the self-contained file principle: feature and module files MUST NOT contain cross-references to other files. All referenced context (data models, conventions, journey context) MUST be copied inline.

```yaml
- id: CR-L05
  name: "artifact-template-self-contained"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L06 writer-prompt-quality-bar

The writer sub-agent prompt MUST describe "what good output looks like" with at least 1 positive example (DO) and at least 1 negative example (DON'T / FORBIDDEN / BAD). Without a quality bar, the writer has no grounding for self-review and produces inconsistent output.

```yaml
- id: CR-L06
  name: "writer-prompt-quality-bar"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L07 reviewer-prompt-discipline

Reviewer prompts MUST use normative language: `MUST`, `MUST NOT`, `FORBIDDEN`. Soft language (`try to`, `prefer`, `ideally`) is FORBIDDEN for hard checks. Soft language in reviewer prompts produces inconsistent issue severity classification and blocker under-reporting.

```yaml
- id: CR-L07
  name: "reviewer-prompt-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L08 tier-mapping-justified

If `model_tier_defaults` in `config.yml` deviates from the guide §20.2 recommended tiers, the deviation MUST be explained in a comment. Unexplained tier changes may indicate copy-paste errors or cost optimizations that degrade output quality.

```yaml
- id: CR-L08
  name: "tier-mapping-justified"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L09 blocker-scope-taxonomy

The writer sub-agent prompt's self-review instructions MUST list all 4 `blocker_scope` values: `global-conflict`, `cross-artifact-dep`, `needs-human-decision`, `input-ambiguity`. Missing scope values cause the reviewer to silently omit blockers that would trigger HITL escalation.

```yaml
- id: CR-L09
  name: "blocker-scope-taxonomy"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L10 hitl-gates-sensible

`config.yml` `hitl.require_approval` MUST include at minimum: `plan_approval`, `force_continue`, `regression_justification` per guide §18.1. Missing HITL gates allow the skill to proceed autonomously past points that require human judgment.

```yaml
- id: CR-L10
  name: "hitl-gates-sensible"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
