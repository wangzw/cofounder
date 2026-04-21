# in-generate-review.md — Writer Self-Review Checklist (T3)

Every writer traverses this checklist in a **single pass** after composing the leaf body, before emitting the output. Any `FAIL` must be fixed in-place or escalated via `regression_justified`.

This is embedded in the writer's system prompt and referenced in `generate/writer-subagent.md`.

---

## Traversal rules

1. Run only criteria from `applicable_criteria` (orchestrator selects them per leaf_kind).
2. For each criterion, emit one line: `- <id> <name>: PASS | FAIL — "<reason>" → fixed. | N/A`
3. If a criterion has an explicit saturation rule (e.g. "one EC per permission boundary is sufficient") and you've hit the minimum, PASS even if the reviewer could arguably want more — that's the rule, not laziness.
4. Order criteria by severity: `critical` first, then `error`, `warning`, `info`.
5. After the last criterion, emit `regression_justified: false` (or `true` with a one-line reason) as the final self-review line.

## Authoring pass vs. review pass — what's in scope here

The in-generate self-review is deliberately **narrow**:
- Structural / header metadata / basic completeness (CR-001, CR-002, CR-007).
- Leaf-type-specific mandatory sections (e.g. user-facing feature → Interaction Design, state machine, a11y).
- Self-containment (CR-020, CR-021) — does this file stand alone?
- Testability (CR-030, CR-031, CR-032, CR-033) — are ACs observable?
- Obvious traceability (CR-010 script half) — does the leaf cross-reference what it should?

The in-generate self-review does **not** run cross-file criteria (CR-045 cross-feature event flow, CR-041 screen-name-consistency, CR-011 metrics-have-verification across README + feature, etc.) — those require the full artifact view and are the cross-reviewer's job.

## Leaf-kind mapping (which criteria apply)

| Leaf Kind | Always | If user-facing | If has Permission | If has Dependencies | If has Notifications |
|-----------|--------|----------------|-------------------|---------------------|----------------------|
| readme | CR-001, CR-002, CR-007 | CR-011 | — | — | — |
| journey | CR-001, CR-002, CR-007, CR-034, CR-036, CR-049 | — | — | — | — |
| feature | CR-001, CR-002, CR-007, CR-020, CR-021, CR-030, CR-031, CR-032 | CR-040, CR-042, CR-043, CR-047, CR-048, CR-049, CR-050, CR-051, CR-052, CR-053, CR-055, CR-057 | CR-033 | CR-035 | CR-090 |
| architecture-topic | CR-001, CR-002, CR-007 | — | — | — | — |
| tombstone | CR-001, CR-007 | — | — | — | — |

Topic-file specific:

| Topic file | Criterion |
|-----------|-----------|
| coding-conventions.md | CR-060 |
| test-isolation.md | CR-061 |
| dev-workflow.md | CR-062 |
| security.md | CR-063 |
| backward-compat.md | CR-064 |
| git-strategy.md | CR-065 |
| code-review.md | CR-066 |
| observability.md | CR-067 |
| performance.md | CR-068 |
| deployment.md | CR-069 |
| ai-agent-config.md | CR-070 |
| privacy.md | CR-091 |
| auth-model.md | CR-092 |
| accessibility.md | CR-050 |
| i18n.md | CR-052 |

## FAIL handling

- **Fixable without escalation**: edit the body in-place and flip the line to `FAIL → fixed.` Do NOT leave a genuine FAIL in the footer unless there's a substantive reason.
- **Design conflict** (e.g. the saturation-rule boundary IS violated, but the requirements say so explicitly): emit `FAIL — "<reason>"`; do NOT fix; the cross-reviewer will judge.
- **Regression into a resolved issue**: set `regression_justified: true` with a concise reason; HITL will decide.

## Saturation rules (inherited from CR-### narrative)

Respect the following so that repeated `--revise` rounds don't generate ever-tighter demands for non-improvement:

| Criterion | Saturation |
|-----------|------------|
| CR-032 non-behavioral-criterion-present | ≥1 NR per distinct operational characteristic (read vs write, steady vs burst). Do NOT demand per-endpoint p95. |
| CR-033 authorization-edge-case | ≥1 unauthorized-access EC per permission boundary (role × scope). Do NOT enumerate every combination. |
| CR-037 test-data-requirements | Reader can set up the test without reading implementation. Do NOT prescribe fixture JSON shape. |
| CR-053 i18n-per-feature-frontend | Key-naming convention stated once. Do NOT audit individual keys. |
| CR-054 i18n-per-feature-backend | One row per error category (validation / permission / conflict / not_found). |
| CR-048 micro-interactions-use-tokens | Animations reference motion tokens. Do NOT demand frame-by-frame choreography. |
| CR-020 feature-self-contained | Feature contains the capability, contract, and observable behavior. Do NOT demand deeper inlining of entities already present at JSON-schema level. |
