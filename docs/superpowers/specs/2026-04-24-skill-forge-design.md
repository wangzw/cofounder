# cofounder:skill-forge — Design Spec

**Date**: 2026-04-24
**Status**: Design approved, pending implementation plan
**Reference**: `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md` (the generative-skill guide, §§1–21 + Appendices A–G)

## Goal

Create a cofounder skill that generates new generative skills from sparse user intent, where both the generator and every skill it produces conform to the generative-skill design guide.

## Scope decisions (from brainstorming)

| Decision | Choice | Rationale |
|---|---|---|
| Input mode | **Conversational** (`/cofounder:skill-forge "..."`) with optional `@refs` / URLs expanded by `prepare-input.sh` | Matches guide §6.1 + aligns with other cofounder skills |
| Target completeness tier | **Full generative skill** (§7.1, all 8 roles, ~35–40 files per generated skill) | User preference; deliverable tier matches Appendix B bootstrap baseline |
| Output location | **`skills/<target-skill-name>/` in the current project** with cofounder plugin conventions (`/cofounder:<name>` triggers, scope-prefixed Conventional Commits) | Keeps dogfooding loop tight |
| Scaffolding strategy | **Script-first with versioned boilerplate tree** at `common/skeleton/`; writers only fill 4 domain-specific files | Matches guide §12 脚本优先 + Appendix G's "copy verbatim" philosophy |
| Artifact-type scope | **4 variants selectable by domain-consultant**: `document` / `code` / `schema` / `hybrid` | Covers Appendix F matrix |
| Skill name | `cofounder:skill-forge` | Trigger-focused, punchy |

## 1. Architecture overview

`cofounder:skill-forge` is a **generative skill that generates generative skills**, following guide §7.1 exactly. It has 8 roles (orchestrator + 7 sub-agents), produces one artifact (a fully-populated target skill directory), runs the standard review-revise loop, and lands the generated skill at `<cwd>/skills/<target-skill-name>/` with a converged `delivery-<N>-<slug>` annotated tag.

**Artifact domain**: a target skill directory that itself conforms to §7.1, with artifact-type variant (`document` | `code` | `schema` | `hybrid`) chosen early by the domain-consultant.

**Self-referential constraint**: the skill-forge directory itself must pass its own review criteria when fed its own design spec as input. This is the Appendix B bootstrap test, promoted to v1 CI gate — the only honest validation.

### 1.1 Directory shape of skill-forge

```
skills/skill-forge/
├── SKILL.md                              # §21.1 skeleton, mode routing + core contract
├── common/
│   ├── config.yml                        # §21.2 complete field set
│   ├── review-criteria.md                # ~24 CR-### (14 script + 10 LLM)
│   ├── domain-glossary.md                # terms domain-consultant disambiguates
│   ├── skeleton/                         # versioned boilerplate tree (the full §7.1 shape)
│   │   ├── document/                     # markdown-artifact variant scaffold
│   │   ├── code/                         # source-code-artifact variant scaffold
│   │   ├── schema/                       # API/schema-artifact variant scaffold
│   │   ├── hybrid/                       # mixed-artifact variant scaffold
│   │   └── shared-scripts-manifest.yml   # sha256 pins for metrics-aggregate.sh etc.
│   └── templates/
│       ├── skill-md-template.md
│       ├── review-criteria-template.md
│       ├── writer-subagent-template.md
│       ├── cross-reviewer-template.md
│       └── artifact-template.md          # per-variant
├── scripts/
│   ├── git-precheck.sh
│   ├── prepare-input.sh
│   ├── glossary-probe.sh
│   ├── scaffold.sh                       # copies common/skeleton/<variant>/ → <target>/
│   ├── run-checkers.sh                   # §12.5 phase A + B
│   ├── check-skill-structure.sh          # CR-S03/S04
│   ├── check-ipc-footer.sh               # CR-S08
│   ├── check-dispatch-log-snippet.sh     # CR-S09
│   ├── check-trace-id-format.sh          # CR-S10
│   ├── check-config-schema.sh            # CR-S06/S11
│   ├── check-scaffold-sha.sh             # CR-S12
│   ├── check-dependencies.sh             # CR-S14
│   ├── check-criteria-consistency.sh
│   ├── check-index-consistency.sh
│   ├── check-changelog-consistency.sh
│   ├── extract-criteria.sh
│   ├── build-depgraph.sh
│   ├── commit-delivery.sh                # §8.3 with conventional-commit scope
│   ├── prune-traces.sh                   # §8.8
│   ├── metrics-aggregate.sh              # verbatim from attachments
│   └── lib/aggregate.py                  # verbatim from attachments
├── generate/
│   ├── from-scratch.md
│   ├── new-version.md
│   ├── domain-consultant-subagent.md
│   ├── planner-subagent.md
│   ├── writer-subagent.md
│   └── in-generate-review.md
├── review/
│   ├── index.md
│   ├── cross-reviewer-subagent.md
│   └── adversarial-reviewer-subagent.md
├── revise/
│   ├── index.md
│   └── per-issue-reviser-subagent.md
├── shared/
│   ├── summarizer-subagent.md
│   └── judge-subagent.md
└── tests/
    ├── bootstrap/
    │   ├── input.md
    │   └── expected/
    ├── unit/
    └── run-tests.sh
```

### 1.2 Key architectural call-outs

- **`common/skeleton/<variant>/`** is the mechanical boilerplate tree per guide §12 (script-first). Writers never regenerate these files; `scaffold.sh` copies them on Round 0.
- **Writers only fill 4 domain-specific files per target skill**: target `review-criteria.md`, target `domain-glossary.md`, target subagent prompts (writer + reviewer + reviser), target `common/templates/artifact-template.md`.
- **`scripts/check-*.sh`** enforce the guide's structural invariants as scripts — not LLM checks (per §12 脚本优先).

## 2. Modes and CLI surface

Standard per guide §4.1. The only skill-specific notes: FromScratch auto-enables `--interactive` (sparse input ≈ always); NewVersion requires an existing `--target`.

| Mode | Invocation | Purpose |
|---|---|---|
| Generate (FromScratch) | `/cofounder:skill-forge "<description>"` | Target at `skills/<name>/` does not exist → new skill directory |
| Generate (NewVersion) | `/cofounder:skill-forge --target skills/<name> "<change>"` | Target exists + new need → new delivery |
| Generate (Refuse) | `/cofounder:skill-forge --target skills/<name>` with no new need | Rejected; prompts user to use `--review` |
| Review | `/cofounder:skill-forge --review --target skills/<name>` | Incremental by default; `--full` forces all |
| Revise | `/cofounder:skill-forge --revise --target skills/<name>` | Applies latest review's issues |
| Diagnose | `/cofounder:skill-forge --diagnose [--round N \| --delivery N]` | Pure script, aggregates `.review/metrics/` |
| Modifiers | `--interactive`, `--force-continue`, `--tier <role>=<tier>`, `--max-iterations N`, `--full` | Per guide §4.1 |

### 2.1 Sparse input example

```
/cofounder:skill-forge "I want a skill that takes raw meeting notes and generates structured decision logs with action items"
```

`prepare-input.sh` writes `.review/round-0/input.md` with `# User Prompt` + `# Expanded References` sections; `input-meta.yml` reports `word_count: 18` → `sparse_input: true` triggers domain-consultant via §6.2 condition 3.

## 3. Domain-consultant scope

The consultant turns "I want a skill that does X" into a structured target-skill spec. Wrong assumptions here propagate down to every writer; this is the widest-blast part of the design.

### 3.1 Output contract

`.review/clarification/<timestamp>.yml` with these required fields (extending guide §6.2 schema):

```yaml
normalized_requirements:
  - req_id: R-001
    statement: "Target skill name and namespace"
    resolved: "cofounder:decision-log"
    status: confirmed
  - req_id: R-002
    statement: "Target artifact type"
    resolved: "document"                        # document | code | schema | hybrid
    status: confirmed
  - req_id: R-003
    statement: "Target artifact structure (pyramid leaves)"
    resolved: |
      <target>/
      ├── README.md
      ├── decisions/
      │   └── D-NNN-{slug}.md
      └── action-items/
          └── AI-NNN-{slug}.md
  - req_id: R-004
    statement: "Input modality — sparse prompt / structured input / document path"
    resolved: "sparse prompt + optional --input <notes.md>"
  - req_id: R-005
    statement: "Structural criteria the target artifact must satisfy"
    resolved:
      - each decision has {context, options, chosen, rationale}
      - each action-item has {assignee, due-date, status}
      - frontmatter: {title, type, date, attendees}
  - req_id: R-006
    statement: "Semantic criteria that need LLM judgment"
    resolved:
      - decisions are non-contradictory
      - action items map to a decision
      - rationale is non-trivial
  - req_id: R-007
    statement: "new-version semantics"
    resolved: "append-only; old decisions never mutate"

domain_terms_aligned:
  - term: "decision"
    definition: "a choice among ≥2 options with explicit rationale; differs from 'note' or 'observation'"
```

### 3.2 Consultant glossary

`common/domain-glossary.md` flags these guide-specific terms as `disambiguation_required: true`. Hits trigger consultant via guide §6.2 condition 2.

| Term | Why disambiguate |
|---|---|
| `generative` / `workflow` skill | User may mean either; maps to different scaffolds |
| `delivery` vs `version` / `semver` | Guide uses monotonic int; users say "v1" colloquially |
| `cross-reviewer` vs `adversarial-reviewer` | Two variants of one role — often conflated |
| `artifact` | Generic; consultant pins to a concrete directory shape |
| `leaf` | Guide-specific term for single-file unit |
| `sub-agent` vs `role` | Often conflated |
| `checker_type` (`script` \| `llm` \| `hybrid`) | Users need explicit guidance on which bucket |

Entries include example phrases so `glossary-probe.sh`'s grep catches conversational forms ("semantic version", "release", "major version" → hits `delivery`).

### 3.3 Artifact-type branching

After R-002 is confirmed, consultant reads `common/skeleton/<variant>/README.md` and replays it to the user as a summary, anchoring R-003/R-005/R-006 to concrete expectations for that variant. Closes the "I want a code-gen skill" users-don't-know-Appendix-F-exists gap.

## 4. Sub-agent roles

| Role | Tier | Skill-forge-specific job |
|---|---|---|
| **orchestrator** | balanced | Pure dispatch. Reads `state.yml`, dispatches, reads ACKs, appends `dispatch-log.jsonl`, decides next phase by judge verdict. Never reads generated leaves. |
| **domain-consultant** | heavy | §6.2. Turns sparse user intent → structured `clarification.yml` with R-001..R-007. Only role with `user-interaction: true`. |
| **planner** | heavy | Reads `clarification.yml` + existing `skills/<target>/` (new-version only). Outputs `{delete, modify, add, keep}` over the 4 domain-specific files only (skeleton files are always `keep` — scaffold.sh owns them). Plan goes to HITL `Plan Approval` gate. |
| **writer** | balanced | One writer per domain-specific file (4 fan-out by default). Writer prompt loads `common/skeleton/<variant>/<corresponding-skeleton-file>.md` as the "what shape" reference and `clarification.yml` as "what content." |
| **reviewer (cross)** | heavy | Reads target skill tree (post-scaffold + post-writer). Runs structural CR-S\* via `scripts/check-*.sh` (phase A+B per §12.5), semantic CR-L\* via LLM. |
| **reviewer (adversarial)** | heavy | Triggered on critical writer self-review items. Hunts for "orchestrator leaks" (SKILL.md accidentally telling main agent to "read the leaves"), forbidden phrases, missing IPC footer. |
| **reviser** | balanced | Reads issues + current target files + resolved-issues history (regression protection §14.1). Rewrites only files flagged by issues. Skeleton files never touched (orchestrator strips skeleton-path issues as `CR-META-skip-violation`). |
| **summarizer** | light | Updates target skill's own index files + `.review/versions/<N>.md` + `.review/metrics/README.md` + target `CHANGELOG.md`. On converged: calls `commit-delivery.sh`. |
| **judge** | light | Reads `.review/round-N/index.md` frontmatter + issue frontmatter only. Outputs verdict. Skill-forge-specific `stalled` trigger: `coverage_percent < 100` returns `stalled: coverage-gap` (§15.1). |

### 4.1 Tool-permission matrix (§19.1)

| Role | `filesystem` | `network` | `execute` | `user-interaction` |
|---|---|---|---|---|
| orchestrator | `read-all + write-state + write-dispatch-log` | false | `allow-scripts` | false |
| domain_consultant | `read-review-input + read-domain-glossary + write-review-clarification` | false | false | **true** |
| planner | `read-artifact + read-review-readme-only + read-review-input + read-review-clarification + write-round-plan` | false | false | false |
| writer | `read-artifact + read-round-issues + read-review-clarification + write-target-domain-files + write-round-self-review` | false | false | false |
| reviewer | `read-artifact + read-review + write-round-issues` | false | `allow-scripts` | false |
| reviser | `read-artifact + read-review + write-target-domain-files + write-round-revision` | false | false | false |
| summarizer | `read-artifact + read-review + write-artifact-index + write-artifact-changelog + write-review-versions + write-review-round-index + write-review-metrics-readme` | false | `allow-scripts` (commit-delivery, check-changelog-consistency) | false |
| judge | `read-review-readme + read-round-index + read-round-issues-frontmatter + write-round-verdict` | false | false | false |

**Critical permission**: writer/reviser **cannot write skeleton paths**. If they try, harness denies; manifests as `FAIL trace_id=<id> reason=write-tool-sandbox-denied` → retry_policy kicks in. This enforces "skeleton is immutable during generate" at the permission layer.

## 5. Review criteria catalog

24 criteria covering the full §7.1 shape. Priority `critical > error > warning`; `conflicts_with` empty in v1 to eliminate oscillation risk on the generator itself.

### 5.1 Structural (script) — 14 criteria

| ID | Name | Severity | Check |
|---|---|---|---|
| CR-S01 | skill-md-frontmatter | error | `name` / `version` / `description` present; description ≤ 1024 chars; starts with "Use when" (§21.1) |
| CR-S02 | mode-routing-complete | error | Mode-routing table lists all 4 base modes + `--diagnose`; every entry has `Loaded Files` column |
| CR-S03 | directory-skeleton | critical | `generate/ review/ revise/ shared/ common/ scripts/` all exist |
| CR-S04 | subagent-file-inventory | critical | All 8 prompts present: orchestrator inline in SKILL.md + 6 files in generate/review/revise/shared + reviewer has 2 prompts |
| CR-S05 | scripts-inventory | critical | Required scripts exist + executable (13 scripts per guide §7.1) |
| CR-S06 | config-schema | error | `config.yml` has all §21.2 top-level keys |
| CR-S07 | criteria-yaml-shape | error | Each CR in target has `id, name, version, checker_type, severity`; `checker_type` ∈ `{script, llm, hybrid}` |
| CR-S08 | ipc-footer-present | critical | Every sub-agent prompt contains Snippet D verbatim |
| CR-S09 | dispatch-log-snippet | critical | SKILL.md orchestrator body contains Snippet C verbatim |
| CR-S10 | trace-id-format | error | All references use `R<N>-<role-letter>-<nnn>` with role-letter table from §3.5 |
| CR-S11 | tool-permissions-coverage | error | `tool_permissions` has all 8 roles; `user-interaction: true` ONLY on `domain_consultant` |
| CR-S12 | metrics-aggregate-verbatim | critical | `scripts/metrics-aggregate.sh` + `scripts/lib/aggregate.py` sha256 matches `shared-scripts-manifest.yml` |
| CR-S13 | artifact-pyramid | error | Target artifact template indicates multi-level index (README + subdirs); no single leaf >300 lines |
| CR-S14 | git-precheck-dependencies | error | Generated `git-precheck.sh` checks all of: git ≥ 2.0, bash ≥ 4.0, python3 ≥ 3.8 (§21.0) |

### 5.2 Semantic (LLM) — 10 criteria

| ID | Name | Severity | Check |
|---|---|---|---|
| CR-L01 | orchestrator-pure-dispatch | critical | Orchestrator section doesn't instruct: reading leaves, summarizing, computing verdicts, rewriting artifact, analyzing issue priority. Positive phrasing: "Pure dispatch + bookkeeping only" |
| CR-L02 | ack-contract-fidelity | critical | Every sub-agent prompt enforces "Write to final path inside sub-session + Task return is one ACK line." Forbidden: "return the full output," "include the content in your reply" |
| CR-L03 | description-is-trigger | error | Description answers "when to invoke" not "what to do" |
| CR-L04 | criteria-internally-consistent | error | No two CRs `conflicts_with` each other in oscillation-prone ways (§13.1) |
| CR-L05 | artifact-template-self-contained | warning | Target template follows CLAUDE.md's self-contained file principle |
| CR-L06 | writer-prompt-quality-bar | error | Writer prompt describes "what good output looks like" with ≥1 positive + ≥1 negative example |
| CR-L07 | reviewer-prompt-discipline | error | Reviewer prompts use MUST / MUST NOT / FORBIDDEN; no soft language ("try to," "prefer," "ideally") for hard checks |
| CR-L08 | tier-mapping-justified | warning | If `model_tier_defaults` deviates from §20.2, deviation is explained in comment |
| CR-L09 | blocker-scope-taxonomy | error | Writer self-review instructions list all 4 `blocker_scope` values (global-conflict, cross-artifact-dep, needs-human-decision, input-ambiguity) |
| CR-L10 | hitl-gates-sensible | warning | `hitl.require_approval` includes ≥ `plan_approval + force_continue + regression_justification` (§18.1) |

### 5.3 Incremental-skip taxonomy (§12.3)

- `full_scan`: CR-S03, CR-S08, CR-S09 (cross-file structural)
- `per_file`: all others

## 6. Scripts

### 6.1 Three tiers

**Tier 1 — verbatim copies from attachments** (sha-pinned, no maintenance):
- `metrics-aggregate.sh` + `lib/aggregate.py` — copied from `attachments/metrics-aggregate/` per Appendix G. `common/skeleton/shared-scripts-manifest.yml` pins expected sha256; CR-S12 verifies.

**Tier 2 — standard per guide**:
- `git-precheck.sh` — §21.0 three-tool check + auto `git init`
- `prepare-input.sh` — §6.1; user prompt = user's target-skill description; `@<path>` handles "I've drafted a design doc"
- `glossary-probe.sh` — greps `domain-glossary.md` against `input.md`
- `run-checkers.sh` — phase A (hash manifest + depgraph + skip-set) + phase B (check-*.sh battery)
- `commit-delivery.sh` — §8.3 with scope `feat(skill-forge): delivery-<N>: <summary>`
- `prune-traces.sh` — §8.8
- `extract-criteria.sh` / `check-criteria-consistency.sh` / `check-index-consistency.sh` / `check-changelog-consistency.sh`

**Tier 3 — skill-forge-specific checkers**:

| Script | Purpose | Exit codes |
|---|---|---|
| `scaffold.sh <variant> <target-path>` | Copies `common/skeleton/<variant>/` → `<target-path>/`. Invoked on Round 0 after plan approval. Idempotent (skip files with matching sha, warn on drift). | 0 = done; 2 = drift |
| `check-skill-structure.sh <target>` | CR-S03 + CR-S04 | 0/1 |
| `check-ipc-footer.sh <target>` | CR-S08 | 0/1 |
| `check-dispatch-log-snippet.sh <target>` | CR-S09 | 0/1 |
| `check-trace-id-format.sh <target>` | CR-S10; regex `R\d+-[CPWVRSJ]-\d{3}` | 0/1 |
| `check-config-schema.sh <target>` | CR-S06 + CR-S11 | 0/1 |
| `check-scaffold-sha.sh <target>` | CR-S12 | 0/1 |
| `check-dependencies.sh <target>` | CR-S14 | 0/1 |
| `build-depgraph.sh <target>` | §8.5 cond-4 depgraph for target's own leaves; `depgraph: off` acceptable in target config | 0 |

### 6.2 I/O conventions

Per §12.4: all checkers emit JSON array of issues to stdout; exit 0 = pass, 1 = issues, 2 = script error. All writes outside target path FORBIDDEN by `tool_permissions`.

## 7. Flows

### 7.1 FromScratch — no target exists

```
/cofounder:skill-forge "I want a skill that generates structured decision logs from meeting notes"

Round 0 (bootstrap):
  orchestrator → scripts/git-precheck.sh                   (§21.0)
  orchestrator → scripts/prepare-input.sh
  orchestrator → scripts/glossary-probe.sh
  orchestrator → dispatch domain-consultant (heavy, R0-C-001)
                 drives ≥1 round of Q&A with user
                 writes .review/clarification/<ts>.yml resolving R-001..R-007

Round 1 (plan + scaffold):
  orchestrator → dispatch planner (R1-P-001)
                 plan = {add: all 4 domain-specific files}
  orchestrator → HITL: Plan Approval gate
  orchestrator → scripts/scaffold.sh <variant> skills/<target>/

Round 1 (domain-content writer fan-out, 4 parallel):
  R1-W-001: target/common/review-criteria.md
  R1-W-002: target/common/domain-glossary.md
  R1-W-003: target/generate/writer-subagent.md + reviewer prompts
  R1-W-004: target/common/templates/artifact-template.md

Round 1 (review):
  orchestrator → scripts/run-checkers.sh                   (phase A + B)
  if script-layer has critical/error → skip LLM → revise
  else orchestrator → dispatch cross-reviewer              (LLM CR-L01..L10)
  orchestrator → dispatch summarizer                       (round-1/index.md + coverage)

Round 1 (judge):
  orchestrator → dispatch judge
  verdict ∈ {converged, progressing, oscillating, diverging, stalled}

Loop (revise → review → judge) while verdict == progressing:
  dispatch reviser per issue (fan-out, §14 regression-protected)
  re-run review phase
  re-dispatch judge

On converged:
  orchestrator → dispatch summarizer                       (versions/<N>.md + CHANGELOG + metrics/README)
  orchestrator → scripts/commit-delivery.sh                (tag delivery-<N>-<slug>)
  orchestrator → scripts/prune-traces.sh                   (§8.8)
  print: "Target skill at skills/<target>/ delivered."
```

### 7.2 NewVersion — target exists

```
/cofounder:skill-forge --target skills/decision-log "add a review criterion for action-item assignee presence"

Round 0: same as FromScratch (consultant skipped unless --interactive / glossary / sparse)
Round k (plan):
  planner reads existing target README.md + input.md + last-converged resolved issues
  outputs {delete: [], modify: [target/common/review-criteria.md], add: [], keep: [...]}
  HITL Plan Approval
  scaffold.sh NOT re-run; check-scaffold-sha.sh verifies no drift
Round k (writer fan-out per plan):
  only modified files get dispatched
  keep files validated for dep drift (§10.3 keep-set validation)
Round k (forced full cross-review — §10.2):
  first review of a new-version is always full
Loop + converged same as FromScratch
```

### 7.3 Round numbering

Per §10.5: cross-delivery monotonic. Delivery-1 round-1..4, delivery-2 starts at round-5.

## 8. Self-bootstrap validation (CI gate)

Per Appendix B: strongest validation is using the skill to generate itself. Pulled from §D.1 to v1 because no other test can honestly catch orchestrator-purity violations or IPC footer drift end-to-end.

### 8.1 Bootstrap fixture

`tests/bootstrap/input.md`:

```
/cofounder:skill-forge "I want a skill that generates generative Claude Code skills from sparse user intent. The artifact is a skill directory at skills/<name>/ following the 8-role generative-skill guide. Input is the user's description of the target skill's purpose and artifact domain. Supports 4 artifact variants: document, code, schema, hybrid. Reviews the generated skill against ~24 structural and semantic criteria."
```

### 8.2 Expected assertions

| Assertion | Baseline |
|---|---|
| `rounds_to_convergence ≤ 3` | Matches Appendix B |
| `total_cost_usd ≤ 0.5` | Matches Appendix B |
| No `oscillating` / `diverging` verdict during loop | — |
| Target tree matches §7.1 | `find skills/<generated-target>/ -type f \| sort` matches golden fixture |
| Target's `metrics-aggregate.sh` sha matches attachment | CR-S12 equiv |
| Every target sub-agent prompt contains Snippet D | CR-S08 equiv |
| `/cofounder:skill-forge --review --target skills/skill-forge` returns `converged` | Self-review path |

### 8.3 Test layout

```
skills/skill-forge/tests/
├── bootstrap/
│   ├── input.md
│   └── expected/
│       ├── directory-manifest.txt
│       └── structural-checks.txt
├── unit/
│   ├── test-scaffold.sh
│   ├── test-trace-id-regex.sh
│   └── test-config-schema.sh
└── run-tests.sh                    # zero-deps harness; REGEN=1 to rewrite golden
```

### 8.4 Self-review mode

`/cofounder:skill-forge --review --target skills/skill-forge` is the production path of the bootstrap test. Because skill-forge's tree IS a skill-forge-shaped artifact, every CR-### applies to skill-forge itself. If self-review ever returns non-converged, the skill has drifted — hard stop.

### 8.5 CI integration (user responsibility, outside skill code)

```yaml
# .github/workflows/skill-forge-bootstrap.yml
- scripts/bootstrap-test.sh       # runs skill-forge on fixture, asserts table
- scripts/self-review.sh          # runs skill-forge --review --target skills/skill-forge
```

## 9. Open items for implementation plan

Things this design *does not* pin down — will be resolved in the implementation plan:

1. Exact set of files in each `common/skeleton/<variant>/` tree (structure agreed per §7.1; per-variant deltas TBD at plan time).
2. Snippet D exact text (taken from Appendix G's SKILL-INTEGRATION.md; pin the exact string to a shared constant so CR-S08 grep is anchor-stable).
3. Domain-glossary seed content — beyond the 7 terms listed in §3.2, additional guide-specific terms may be surfaced during prompt authoring.
4. Writer prompt templates for the 4 domain files — exact structure for "shape reference + content source" is a writer-prompt authoring task.
5. Bootstrap fixture golden files — regenerated after first skeleton is authored.

## 10. Out of scope for v1

- **Insights** (§D.3) — `.review/insights/` not produced in v1; retention for it configured to 0.
- **Cross-skill chain contracts** (§D.2) — skill-forge does not declare `input_artifact_schema` / `output_artifact_schema` at the skill-schema level. Users chain manually.
- **Per-version parallel artifact directories** — all target skills are in-place mutated per §10; parallel `skills/<name>-v2/` trees are out of scope.
- **`fast-forge` mode** (produce Appendix E minimal skeleton) — rejected in favor of "full only" during brainstorming.

## References

- `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md` §§1–21 + Appendices A–G
- `~/Documents/mind/raw/guide/attachments/metrics-aggregate/` — shared reference implementation
- `CLAUDE.md` — cofounder project conventions
- `skills/prd-analysis/`, `skills/system-design/` — existing cofounder generative skills (partial conformance)
