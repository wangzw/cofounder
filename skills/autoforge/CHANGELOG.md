# Changelog

All notable changes to the `autoforge` skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.0] — 2026-05-07

Adds **`--evolve` mode** so autoforge can absorb in-place mutations made by
`system-design --evolve` and re-implement only the affected modules without
rebuilding from scratch. The plan directory is mutated in place, mirroring the
design directory's lifecycle; per-delivery identity lives in `versions/<N>.md`,
`CHANGELOG.md`, and `autoforge-delivery-<N>-<slug>` annotated git tags.

### Added

- **Input Modes:** `--evolve`, `--evolve --plan-only`, `--evolve --from`,
  `--evolve --fresh`. Mode Routing rows added.
- **`--evolve Mode` section in `SKILL.md`** with steps E0–E6:
  - E0 Locate prior delivery + plan (auto-discover via tags; refusal gates).
  - E1 Compute affected module set (`removed / added / revised-direct /
    revised-downstream / kept`) using a sonnet subagent for semantic-vs-
    cosmetic interface diffing; user approval gate.
  - E2 Create evolution branch `autoforge/{name}-{hash4}-d{N}`.
  - E3 Apply removals (with deferred-deletion when `kept` consumers would break).
  - E4 Re-plan affected modules in place.
  - E5 Execute affected modules in parallel batches.
  - E6 Acceptance + `versions/{N}.md` + `CHANGELOG.md` +
    `autoforge-delivery-{N}-<slug>` tag.
- **Variant 5 — Evolve from Existing Code** in `module-developer-prompt.md`:
  minimum-viable-diff Developer prompt that reads delivery N−1 source and
  applies only the changes the revised plan classifies as `change` / `add` /
  `remove`. Refuses gratuitous refactors.
- **Module Agent evolution mode**: `is_evolution`, `evolution_class`,
  `parent_commit`, `previous_plan_path`, `baseline_design_tag`,
  `target_design_tag`, `design_delta_summary_path`, `evolution_delivery_n`
  context parameters. Variant 5 dispatch on first Developer spawn.
- **Planner evolution context**: same parameters surface in
  `planner-prompt.md`, plus a new "Evolution Planning" sub-section requiring
  every step to carry an explicit `keep | change | add | remove`
  classification, stable step IDs, and an Evolution Notes section in the plan.
- **Plan README schema** (`plan-readme-template.md`): new Design Input rows
  (`Feature Branch Family`, `Current Design Delivery`, `Autoforge Delivery`,
  `Autoforge Delivery Tag`); new `## Evolution History` table; `Kept` and
  `Removed` Module Status legend entries; in-place-mutation footer note.
- **Output Structure** documents `versions/`, `CHANGELOG.md`, `.evolve-{N}/`,
  archived `acceptance-d{N-1}.md`.
- **Branch / tag conventions:** `autoforge/{name}-{hash4}-d{N}` evolution
  branch family; `autoforge-delivery-{N}-<slug>` annotated tag.
- **Commit messages** for evolution-specific operations:
  `chore(plan): remove modules in delivery-{N}`, `docs(plan): refresh
  conventions for delivery-{N}`, `docs(plan): re-plan for delivery-{N}`,
  `docs(plan): archive delivery-{N-1} acceptance report`, `docs(plan):
  finalize autoforge delivery-{N}`, `feat(M-{id}): evolve to delivery-{N}`.
- **Key Principle:** "In-place evolution mirrors system-design" plus "Evolution
  scope is module-level, not file-level".

### Changed

- `--cleanup Mode` refuses to delete a plan directory when `versions/<N>.md`,
  `CHANGELOG.md`, or `autoforge-delivery-*` tags exist (delivery history would
  be destroyed). User must manually remove tags + `versions/` if they really
  want to discard the chain.
- `module-agent-prompt.md` Spawning Developer table now lists Variant 5 first.
- `planner-prompt.md` Self-Check adds evolution-specific bullets; Output Report
  emits an `EVOLUTION:` line when planning under `--evolve`.

### Migration

- Existing v1.0.0 plan directories without an `Autoforge Delivery` field are
  treated as delivery 1; the first `--evolve` run will populate the field and
  start at N=2.
- `--evolve --from <delivery-N-slug>` overrides auto-discovery if multiple
  design deliveries have accumulated since the last autoforge run, allowing
  catch-up evolution.
- `--evolve --fresh` is an explicit opt-out for cases where in-place mutation
  would be more confusing than starting over (e.g. >70% modules revised); it
  falls through to default mode with a new plan dir. Discouraged.

## [1.0.0] — 2026-05-07

First stable release. Round-2 audit (commit-pending) verified zero
residual findings via line-by-line cross-checks of all eight round-1
fix categories. Convergence achieved in a single fix iteration — the
skill's contract surface (11 markdown files; orchestrator + 7
sub-agent prompts + 3 templates) is now internally consistent,
aligned with the released `system-design` v1.0.0 contracts, and
follows the same audit guardrails proven on `prd-analysis` and
`system-design`.

## [0.1.0] — 2025-05-29

### Fixed

#### Sub-agent context / parameter propagation
- **[HIGH] SKILL.md** — Module Agent spawn template now passes `developer_prompt_path`, `tester_prompt_path`, and `reviewer_prompt_path` to the spawned Module Agent so it can read the sub-prompt files from disk (they are not inherited from the Orchestrator's context).
- **module-agent-prompt.md** — `race_detection_flag` substitution is now documented in the Spawning Tester section; the Module Agent must substitute the flag value before spawning when conventions require race detection.
- **module-developer-prompt.md** — Variants 2, 3, and 4 Inputs sections now include `conventions_path`, matching the Module Agent Setup step 5 requirement to pass it to every Developer spawn.
- **module-developer-prompt.md** — Variant 4 (Replan Mode) now has a full Inputs section listing `module_design_path`, `module_plan_path`, and `conventions_path`.
- **module-reviewer-prompt.md** — Reviewer Inputs section now includes `conventions_path`, required for Category 4 "Convention compliance" checks.

#### Missing parameters on agent spawns
- **SKILL.md** — Integration Tester parameter table now includes `project_coding_standards`.
- **SKILL.md** — Acceptance Tester parameter table now includes `project_coding_standards` and `previous_report_path` (populated only when `is_rerun = true`).
- **integration-tester-prompt.md** — `project_coding_standards` added to the parameters list and as a `## Project Coding Standards` section in the prompt body.
- **acceptance-tester-prompt.md** — `project_coding_standards` added to the parameters list.
- **SKILL.md** — Integration fix Developer inline prompt now includes `conventions_path` (Inputs) and `project_coding_standards` section.
- **SKILL.md** — Acceptance fix Developer inline prompt now includes `conventions_path` (Inputs) and `project_coding_standards` section.

#### Output filename inconsistency
- **SKILL.md** — Developer Role description (line ~402) changed `review-comments` → `review-M-{id}.md` to match the actual filename used by the Reviewer.
- **SKILL.md** — Reviewer Role description (line ~456) changed `review-comments.md` → `review-M-{id}.md`.

#### Missing instructions in Developer variants
- **module-developer-prompt.md** — Variant 3 (Retry From Reviewer) task body now includes an explicit instruction to run all tests and report results to confirm no regressions.
- **module-developer-prompt.md** — Variant 4 (Replan Mode) task body now includes an instruction to write updated developer notes to `{report_dir}/developer-notes-M-{id}.md`.

#### Verdict / logic inconsistencies
- **acceptance-tester-prompt.md** — PASS verdict pseudo-code updated to match the acceptance-report-template definition: PASS now requires all criteria to be `PASS` or `NOT_COVERED(with valid justification)` AND `pass_rate >= acceptance_threshold` AND no critical failures (previously only checked `all criteria PASS`).
- **SKILL.md** — Acceptance fix re-run now passes `previous_report_path` in the `is_rerun: true` call.
- **SKILL.md** — Step 4 header corrected: Step 4 is also executed when the user explicitly chooses to merge with a PARTIAL verdict, not only on a clean PASS verdict.

#### Missing retry bounds on fix cycles
- **SKILL.md** — Phase integration fix cycle now has an explicit ceiling: maximum 10 fix rounds, stall detection after 3 consecutive non-progress rounds, with human escalation if still blocked.
- **SKILL.md** — Acceptance fix cycle now has the same explicit ceiling and stall detection.

#### Decision Request handling
- **SKILL.md** — Decision Request fix Developer spawn now specifies which Developer variant to use (Variant 3 or custom prompt), and which parameters to pass (`module_design_path`, `module_plan_path`, `conventions_path`, `project_coding_standards`).
- **module-agent-prompt.md** — DECISION_REQUEST return format `REPORTS` field updated: `decision-request-M-{id}.md` is now listed as the primary report; `failure-details-M-{id}.md` is noted as optional (present only when the stall was from the Tester).

#### Status tracking
- **plan-readme-template.md** — Module Status legend now includes `Replan {n}` state for modules in Replan Mode.
- **SKILL.md** — Status Tracking section Module Status example now includes the same `Replan {n}` legend entry.

#### Infrastructure failure handling
- **module-agent-prompt.md** — New "Infrastructure Failures" section: if a sub-agent spawn fails due to infrastructure, retry once; if it fails again, record the error and return `DECISION_REQUEST` with the failure context.

#### Git / merge policy
- **SKILL.md** — "Always rebase before merge" principle corrected to "Prefer fast-forward merge; rebase only when fast-forward is not possible", which matches the canonical merge command sequence.
- **SKILL.md** — `state(M-{id}): update module state` commit message added to the Commit Messages reference list.

#### Model escalation policy
- **SKILL.md** — Escalation rule paragraph now includes the Acceptance Tester escalation: escalate ambiguity-classification pass to `opus` when a PRD ambiguity failure is encountered; revert after resolution.

#### Templates
- **plan-readme-template.md** — Acceptance Threshold field is now `{acceptance_threshold}% (default: 80)` instead of a hardcoded `80%`.

### Added
- `version: 0.1.0` added to `SKILL.md` frontmatter.
