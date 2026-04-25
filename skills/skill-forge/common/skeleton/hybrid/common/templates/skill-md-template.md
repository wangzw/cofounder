# Template: SKILL.md — Shape Reference for Writer

This template is READ by the writer sub-agent when authoring the target skill's `SKILL.md`. It describes
the fully-filled end-state the writer targets. The skeleton has placeholders (`{{SKILL_NAME}}` etc.);
the writer replaces all of them using `clarification.yml` fields.

---

## Shape Reference

```
---
name: <skill-name>
version: 1.0.0
description: "Use when <trigger condition — one or two sentences max>. ≤ 1024 chars."
---

# <skill-name> — <one-line purpose>

## Artifact Variant: <Document | Code | Schema | Hybrid>

<One-paragraph explanation of what this skill generates and which guide §7.x variant applies.>

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:<skill-name> "<description>"` | `generate/from-scratch.md`, `common/review-criteria.md` | <one-line semantics> |
| generate (new version)  | `/cofounder:<skill-name> --target <path> "<change>"` | `generate/new-version.md`, `common/review-criteria.md` | <one-line semantics> |
| review  | `/cofounder:<skill-name> --review --target <path>` | `review/index.md`, `common/review-criteria.md` | <one-line semantics> |
| revise  | `/cofounder:<skill-name> --revise --target <path>` | `revise/index.md`, `common/review-criteria.md` | <one-line semantics> |
| `--diagnose` | `[--round N | --delivery N | --since <iso>]` | Only `scripts/metrics-aggregate.sh` | Aggregate harness JSONL + dispatch-log |

## Bootstrap Precheck

Every mode MUST call `scripts/git-precheck.sh` as the first action. On failure (non-zero exit):
skill exits; does NOT enter any generate/review/revise mode.

- Verifies `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`
- If cwd is not a git repo, auto-runs `git init` + empty bootstrap commit
- During Bootstrap Precheck, orchestrator MUST write
  `skill-root: <absolute path to this skill\'s root directory>` to
  `<target>/.review/state.yml` so downstream sub-agents can locate this skill's own scripts.

## Core Contract

- Orchestrator is **pure dispatch + bookkeeping only**. Forbidden: reading artifact leaves,
  summarizing content, computing convergence verdicts, rewriting artifacts, analyzing issue priority.
- Hard dependencies: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`. NEVER add `pyyaml` / `jq` /
  `slugify` / any third-party package.
- Target artifact in-place mutated. History through git tags (`delivery-<N>-<slug>` annotated tags)
  + `.review/versions/<N>.md` + target `CHANGELOG.md`.
- `.review/` lives at target root. Pyramid-indexed: `round-<N>/` + `metrics/` + `versions/`.
- Round numbers are cross-delivery monotonic.

## Orchestrator Dispatch Contract

<!-- snippet-c-fingerprint: dispatch-log-v1 -->

### Per every dispatch (mandatory)

For **every** sub-agent dispatch the orchestrator MUST:

1. **Assign a `trace_id`** in the format `R{round}-{role-letter}-{nnn}` ...
[Snippet C body copied verbatim from common/snippets.md — do not abbreviate]

## `--diagnose` Mode

**Pure script mode. MUST NOT** load any sub-agent prompt.

### Execution Steps (FORBIDDEN to deviate)

1. Validate `scripts/metrics-aggregate.sh` exists and is executable.
2. Pass-through args verbatim.
3. Invoke:
   ```bash
   scripts/metrics-aggregate.sh --diagnose "$@" \
     --review-dir ./.review \
     --harness-dir "${CLAUDE_HARNESS_DIR:-$HOME/.claude/projects}" \
     --config common/config.yml
   ```
4. Handle exit codes: 0=success; 1=argument error; 2=input error; 3=JOIN coverage < 50%.
5. Relay script output verbatim — no LLM post-processing.

## Model Tiers

Abstract: `heavy` / `balanced` / `light`. Mapping in `common/config.yml` (`model_tier_defaults` + `model_mapping`).

### Per-dispatch model override (MANDATORY for cost control)

When the orchestrator dispatches a sub-agent via the Claude Code Agent tool, it **MUST**
pass the `model` parameter to override the default (parent-session inheritance). Without
this override, all sub-agents run on the parent session's model — typically `opus` —
which costs 5–25× the configured tier rate. Per the `tool_permissions` +
`model_tier_defaults` sections of `common/config.yml`:

| Role | Default tier | Agent-tool `model` value |
|------|------|------|
| domain-consultant | `heavy` | `"opus"` |
| planner | `heavy` | `"opus"` |
| writer | `balanced` | `"sonnet"` |
| reviewer (cross + adversarial) | `heavy` | `"opus"` |
| reviser | `balanced` | `"sonnet"` |
| summarizer | `light` | `"haiku"` |
| judge | `light` | `"haiku"` |

Users may override a single dispatch via `--tier <role>=<tier>` (see CLI Flags).

Orchestrator MUST log both `model_requested` (the tier-mapped value passed to the Agent
tool) and the `model` actually observed in the harness JSONL for each dispatch, so
`--diagnose` can flag drift.

## CLI Flags

| Flag | Applies to | Semantics |
|------|-----------|-----------|
| `--full` | `--review` | Force full review — bypass skip-set, treat every leaf as `cross_reviewer_focus`. Orchestrator passes `--full` to `scripts/run-checkers.sh`; `skip-set.yml` records `forced_full: true`. |
| `--interactive` | Generate | Force-dispatch `domain-consultant` even on dense input. |
| `--no-consultant` | Generate | Skip `domain-consultant` even if triggers fire; orchestrator synthesizes a minimal `clarification.yml` (R-001..R-007 = `deferred`) from the user prompt + `input.md` expanded refs. Saves the consultant's heavy-tier dispatch (~$4 at opus rates). |
| `--force-continue` | Generate | Override `oscillating`/`diverging` judge verdict and run one more round; requires HITL approval gate. |
| `--tier <role>=<tier>` | Generate / Review / Revise | Override model tier for one dispatch role (e.g. `--tier writer=heavy`). |
| `--max-iterations N` | Generate / Review / Revise | Override `config.yml.convergence.max_iterations`. |

## Configuration & Subagent Files

- **Config**: `common/config.yml`
- **Review criteria**: `common/review-criteria.md`
- **Domain glossary**: `common/domain-glossary.md`
- **Sub-agent prompts**:
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md`
  - `review/adversarial-reviewer-subagent.md`
  - `revise/per-issue-reviser-subagent.md`
  - `shared/summarizer-subagent.md`
  - `shared/judge-subagent.md`
```

---

## Content Requirements

Fill the following from `clarification.yml`:

| Placeholder | Source field |
|-------------|-------------|
| `<skill-name>` | `clarification.skill_name` |
| `<one-line purpose>` | `clarification.purpose` |
| `<trigger condition>` | `clarification.trigger` — MUST start with "Use when" |
| Artifact Variant paragraph | `clarification.artifact_variant` + `clarification.variant_notes` |
| Mode Routing "Semantics" column | `clarification.mode_semantics.*` |
| Snippet C body | Copied verbatim from `common/snippets.md` — never paraphrase |

**Critical rules**:
- `description` MUST start with the exact phrase "Use when" (CR-S01 hard check).
- Mode Routing table MUST include all 5 rows AND the "Loaded Files" column (CR-S02 hard check).
- Orchestrator body MUST contain the line `<!-- snippet-c-fingerprint: dispatch-log-v1 -->` verbatim (CR-S09 hard check).

---

## Positive Example — decision-log skill (excerpts)

```yaml
---
name: decision-log
version: 1.0.0
description: "Use when the team needs to record an architectural or product decision with
  rationale, alternatives considered, and action items. Run before implementing any
  significant technical change. ≤ 1024 chars."
---
```

Mode Routing (good — all 5 rows, Loaded Files column present):

```markdown
| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:decision-log "adopt PostgreSQL for primary store"` | `generate/from-scratch.md`, `common/review-criteria.md` | New decision record from prompt; consultant clarifies scope, writers author leaf |
| generate (new version) | `/cofounder:decision-log --target decisions/ "revise auth decision"` | `generate/new-version.md`, `common/review-criteria.md` | Amend existing decision; planner emits delta plan |
| review | `/cofounder:decision-log --review --target decisions/` | `review/index.md`, `common/review-criteria.md` | LLM + script checks; issues filed under `.review/` |
| revise | `/cofounder:decision-log --revise --target decisions/` | `revise/index.md`, `common/review-criteria.md` | Per-issue revise loop |
| `--diagnose` | `[--round N]` | Only `scripts/metrics-aggregate.sh` | Aggregate metrics; no sub-agent |
```

Snippet C fingerprint line (correct):

```
<!-- snippet-c-fingerprint: dispatch-log-v1 -->
```

---

## Negative Example — common mistakes (with CR annotations)

**Anti-pattern A — description doesn't start with "Use when"** → CR-S01 fires:

```yaml
description: "The decision-log skill helps teams document architectural decisions."
#             ^^^ WRONG: starts with "The", not "Use when"
```

**Anti-pattern B — Mode Routing table missing "Loaded Files" column** → CR-S02 fires:

```markdown
| Mode | Args | Semantics |
|------|------|-----------|
| generate | ... | ... |
# ^^^ WRONG: no "Loaded Files" column
```

**Anti-pattern C — orchestrator body omits Snippet C fingerprint** → CR-S09 fires:

```markdown
## Orchestrator Dispatch Contract

For every dispatch the orchestrator MUST assign a trace_id...
# ^^^ WRONG: the fingerprint comment line is absent; check-dispatch-log-snippet.sh will fail
```

---

## How to Fill

1. Open `clarification.yml` at `.review/round-0/clarification/<ts>.yml`.
2. Map `skill_name` → every `{{SKILL_NAME}}` placeholder.
3. Map `trigger` → `description` value (prepend "Use when" if not already present).
4. Copy Snippet C verbatim from `common/snippets.md`; do not paraphrase or shorten.
5. Confirm all 5 Mode Routing rows are present before writing.
