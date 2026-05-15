# Skill bugs surfaced during prd-analysis + system-design dual-evolve session

> Date: 2026-05-15
> Skills affected: `prd-analysis`, `system-design`
> Session context: PRD delivery 4 (GitHub Actions hosted agent) + Design delivery 3 propagation
> Severity: medium-high — output quality, not blocking, but degrades the reader experience and creates downstream cleanup work

## Summary

A single user session drove `/prd-analysis --evolve` then `/system-design --evolve` to completion. After delivery commits, six classes of output-quality bugs were discovered. Three required hand-fixed ad-hoc docs commits (`9eae32867`, `673aad53f`, `aba49c68c`) and one more strip pass to clean up. All bugs stem from sub-agent prompts (`writer-subagent.md`, `per-issue-reviser-subagent.md`, `adversarial-reviewer-subagent.md`) lacking explicit constraints, OR from skill orchestration files lacking a "retire-after-commit" cleanup step for transient annotations.

## Bug inventory

### B-1 — Writers / revisers produce `\n` literals inside Mermaid node labels

**Symptom.** In every Mermaid `[NodeId Line1\nLine2]` style the writer used `\n` thinking it was a newline — but Mermaid renders `\n` as the two-character string `"\n"`. Diagrams visibly broken.

**Scope hit this session.** 23 occurrences across 8 files in PRD+Design. Fixed in commit `9eae32867`.

**Root cause.** Writer / reviser sub-agent prompts in both skills do not state Mermaid syntax constraints. Sub-agents fall back to Go-style escape habits.

**Suggested skill fix.** Add to `generate/writer-subagent.md` of BOTH `prd-analysis` and `system-design` (Mermaid section):

> Inside Mermaid node/edge/state-transition labels, line breaks MUST be expressed as `<br/>`. The two-character escape `\n` is rendered as literal text and breaks diagram clarity. Quoted labels (`["Line1<br/>Line2"]`) are the most robust form.

A check-script can also be added: scan all mermaid blocks for `\n` literal, fail formal review when found.

### B-2 — Writers produce `[/path]` Mermaid parallelogram-syntax collision

**Symptom.** `Sock[/var/run/docker.sock]` — Mermaid's `[/text/]` syntax declares a parallelogram node. A leading slash without a closing `/]` corrupts parsing.

**Scope hit this session.** 2 occurrences in `architecture/deployment.md` and `modules/M-002-deployment-infrastructure.md`. Fixed in commit `9eae32867`.

**Suggested skill fix.** Same writer-prompt addendum:

> When a Mermaid node label contains a path with leading `/` (e.g. `"/var/run/docker.sock"`), the label MUST be quoted: `NodeId["/var/run/docker.sock"]`. Unquoted `NodeId[/path...]` collides with the parallelogram-shape syntax `[/text/]` and breaks parsing.

### B-3 — Mermaid stateDiagram-v2 transition labels with inner `:` confuse strict parsers

**Symptom.** Obsidian / mermaid v10+ fails on `running --> terminated : run.finished event (terminal_reason: finished)` because the inner `:` inside parens is parsed as another state-description boundary.

**Scope hit this session.** 14 files, 45 transition lines. Initial fix in commit `673aad53f` was over-broad — REPLACED both `(key: value)` AND endpoint URL paths like `/sessions/:id`, regressing the API surface. Hand-corrected in commit `aba49c68c`.

**Suggested skill fix.** Two parts:
1. Writer prompt: "stateDiagram-v2 transition descriptions MUST avoid `:` inside parens. Use `=` (key=value) or omit the structure. Keep `:` for URL path-parameter syntax only (e.g. `POST /v1/sessions/:id`)."
2. Check-script: scan stateDiagram blocks for `(.*:.*)` patterns (key: value form inside parens) and warn; do NOT warn on URL path patterns `\/:\w+\b`.

### B-4 — `[ADDED]/[MODIFIED]/[REMOVED]/[UNCHANGED]` body markers accumulate across deliveries

**Symptom.** evolve-mode prescribes inline change markers in every modified leaf. After 4 delivery cycles (PRD), 690 markers polluted PRD+Design body content. Markers from delivery 2 and delivery 3 became stale ("ancient changes" no longer relevant) but skill has no retirement step. Per-delivery git diff and tag history already provide the same information.

**Scope hit this session.** 690 markers stripped manually (final commit pending). Worst file: `modules/M-038-session-detail-page.md` had 120 markers — file body unreadable through the noise.

**Suggested skill fix.** Either (a) drop the body-inline marker convention entirely — file-level `Status: Modified` + `Baseline:` + `Change summary:` frontmatter is sufficient, or (b) add a `scripts/strip-stale-markers.sh` invoked by `commit-delivery.sh` that removes markers from delivery N-1 and earlier, keeping only delivery N's markers.

Note: simple regex-based strip is dangerous — newline-greedy patterns like `\s*` after the marker eat blank-line separators, joining headings to tables. A safe strip must use `[^\S\n]*` for whitespace and never replace markers with anything that touches surrounding newlines.

### B-5 — Adversarial-reviewer mutates skill catalog files

**Symptom.** During prd-analysis Delivery 4 round 7, the adversarial-reviewer sub-agent (R7-V-002) coined three new CR IDs (`CR-PP-XR`, `CR-AR-MULTITENANT`, `CR-AR-CRED-EVENT`) and appended 102 lines to `~/.claude/skills/prd-analysis/common/review-criteria.md` to register them. The user caught and reverted; the orchestrator dispatched per-leaf revisers to substitute valid CR IDs into the issue files.

**Scope hit this session.** Single incident, fully cleaned. But the failure mode is high-risk: any consuming session can quietly mutate the skill.

**Suggested skill fix.**
1. Every reviewer / writer / reviser dispatch prompt MUST contain a hard prohibition: "You MUST NOT Write/Edit any file under `~/.claude/skills/` or `~/.claude/plugins/cache/`. The skill is read-only. New CR IDs are string labels in your JSON output ONLY; do NOT modify the catalog file." Bake this into the orchestration / sub-agent templates so the orchestrator can't forget to include it.
2. Optional defense-in-depth: orchestrator runs `git -C <skill-root> diff --quiet` after each dispatch; non-zero exit aborts with HITL.

The session has already saved two memory entries on this:
- `~/.claude/projects/-Users-wangzw-workspace-castworks/memory/feedback_skill_files_are_read_only.md`
- `~/.claude/projects/-Users-wangzw-workspace-castworks/memory/feedback_follow_skill_orchestration_verbatim.md`

### B-6 — Orchestrator-side mega-reviser anti-pattern

**Symptom.** During prd-analysis revise phase, orchestrator (Claude) dispatched a single "mega-reviser" sub-agent to handle all 38 issues at once, deviating from the per-leaf-reviser pattern the skill prescribes. The mega-reviser also triggered B-5 (it wrote to the skill catalog) before the user stopped it.

**Suggested skill fix.** Add to `SKILL.md` Forbidden Actions: "Dispatch one sub-agent that combines multiple work units the skill defines as separate (e.g., a single reviser handling >1 leaf, or a single writer authoring >1 artifact). Per-leaf / per-issue dispatch is the contract; the orchestrator may not coalesce."

## Effects on this session's deliveries

| Commit | What it fixed |
|---|---|
| `9eae32867` | B-1 (`\n` in mermaid) + B-2 (`[/path]` parallelogram) |
| `673aad53f` | B-3 first attempt — over-broad |
| `aba49c68c` | B-3 second pass — restored damaged endpoint paths |
| (pending) | B-4 — body marker strip with safe regex |

PRD `prd-analysis-delivery-4-...` tag at commit `033665ed3` and Design `system-design-delivery-3-...` tag at commit `26d456e9d` both predate these fixes; the docs-only commits do not bump or retag.

### B-7 — Summarizer leaves `round-<N>/index.md` missing required schema fields

**Symptom.** `scripts/check-round-index.sh` enforces `CR-RI01` requiring fields `critical_count`, `error_count`, `warning_count`, `info_count`, `justified_regressions_ok` in `.review/round-<N>/index.md`. The summarizer sub-agent (per-round phase) writes the file but omits one or more of these fields. The check didn't fire at delivery time (verdict converged before the gate caught the audit-artifact regression), but a subsequent `run-checkers.sh` exposes it.

**Scope hit this session.** PRD `round-7/index.md` — all 5 of the above fields missing. Design `round-3/index.md` — similar single-issue case.

**Suggested skill fix.** Either (a) tighten the summarizer's per-round prompt with an explicit `MUST emit fields {critical_count, error_count, warning_count, info_count, justified_regressions_ok}` clause referencing the schema in `common/issue-schema.md`, or (b) move `check-round-index.sh` into `verify-phase-entry.sh read` so the gap blocks delivery.

## Recommended priority

1. **B-5** (skill mutation) — security-adjacent, ship soon
2. **B-1 / B-2 / B-3** (mermaid output) — visible quality
3. **B-6** (mega-reviser) — process integrity
4. **B-7** (summarizer field coverage) — silent regression
5. **B-4** (marker retirement) — pure noise reduction
