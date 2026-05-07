# Changelog

All notable changes to the `autoforge` skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
