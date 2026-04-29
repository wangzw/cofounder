# Prompt: Redesign system-design skill (apply prd-analysis redesign template)

> **Audience**: a fresh Claude Code agent session with full file-system + Bash access
> in `/Users/wangzw/workspace/cofounder`. The agent has NO context from prior
> sessions; this file is self-contained.
>
> **Goal**: apply the same redesign that was successfully applied to
> `skills/prd-analysis/` to `skills/system-design/`. The result must be a
> system-design skill with: per-artifact formal-review scripts, script-enforced
> phase-entry gates, the new 5-state issue machine, full test coverage, and
> end-to-end pipeline verification on a real PRD.

---

## 1. Read these references first (in order)

1. **The audit-design guide** — the authoritative spec for what we're
   implementing:
   - `~/Documents/mind/raw/guide/生成式skill的审查设计.md` — formal vs substantive
     review, issue state machine, phase gates
   - `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md` — the parent guide
     (8-role pyramid, dispatch contract, §9 script contract)

2. **The prd-analysis reference implementation** — the exact pattern to mirror:
   - `skills/prd-analysis/SKILL.md` — note the **Phase Contract** section
   - `skills/prd-analysis/README.md` — developer-facing overview
   - `skills/prd-analysis/scripts/` — 27 scripts organized as: per-artifact
     `check-*.sh`, phase gates, aggregator (`run-checkers.sh`), helpers
     (`create-issues.sh`, `update-summary.sh`, `synthesize-clarification.sh`,
     `verify-phase-entry.sh`)
   - `skills/prd-analysis/scripts/lib/prd_lint.py` — shared `Finding` dataclass
     + `emit()` helper used by every per-artifact script
   - `skills/prd-analysis/tests/` — 27 test runners + `lib/test_helpers.sh` +
     `run-all.sh`
   - `skills/prd-analysis/common/issue-schema.md` — on-disk issue format + LLM
     raw-output JSON + summary.yml shapes
   - `skills/prd-analysis/common/review-criteria.md` — formal vs substantive
     CR partitioning
   - `skills/prd-analysis/review/index.md` and `revise/index.md` — read-phase
     and write-phase orchestration with **MANDATORY Step 1**
     `verify-phase-entry.sh ...`

3. **The prd-analysis redesign commit chain** — read for context, NOT to
   cherry-pick into system-design. The right approach is to re-apply the
   redesign idiomatically; not to mechanically copy diffs.
   ```bash
   git -C /Users/wangzw/workspace/cofounder log --oneline 4bce546~1..HEAD -- skills/prd-analysis/
   ```

---

## 2. The system-design current state (what you're transforming)

`skills/system-design/` currently has the **same legacy skill-forge structure**
that prd-analysis had before the redesign:

- ~30 `scripts/check-*.sh` checkers — most are **skill-shape** checks (e.g.
  `check-skill-md-sections.sh`, `check-mode-routing.sh`,
  `check-scaffold-sha.sh`) inherited from skill-forge scaffolding. They
  audit the SKILL bundle, not the design output.
- A **subset of system-design–specific scripts** that are genuinely useful and
  must be preserved (or refactored, not deleted):
  - `check-feature-module-traceability.sh` — design-specific
  - `check-module-interface-types.sh` — design-specific
  - `check-module-deps-vs-protocols.sh` — design-specific
  - `check-api-per-endpoint-blocks.sh` — design-specific
  - `check-api-surface-cols.sh` — design-specific
  - `check-boundary-enforcement-cols.sh` — design-specific
  - `check-endpoint-literal-vs-api.sh` — design-specific
  - `check-architecture-coverage.sh` — design-specific (verifies design
    covers PRD architecture topics)
  - `check-analytics-coverage.sh` — design-specific
  - `check-placeholder-json.sh` — design-specific
  - `check-dependency-layering.sh` — design-specific
  - `check-readme-references.sh` — design-specific
  - `check-single-source-of-truth.sh` — design-specific
- Subagent prompts under `generate/`, `review/`, `revise/`, `shared/` —
  similar legacy structure to prd-analysis pre-redesign
- No `tests/` directory
- A `.review/` from prior runs (must be cleaned)

---

## 3. The system-design artifacts (what per-artifact scripts you'll need)

Per `SKILL.md` § Output Structure, system-design produces:

| Artifact | Path | Notes |
|----------|------|-------|
| README.md | `<output>/README.md` | overview + module index + **Feature-Module mapping matrix** (✦/△ symbols) |
| Module spec | `<output>/modules/M-NNN-{slug}.md` | one per module; self-contained |
| API contract (optional) | `<output>/api/API-NNN-{slug}.md` | one per API; only when project has APIs |
| REVISIONS.md | `<output>/REVISIONS.md` | only after first `--revise` |
| CHANGELOG.md | `<output>/CHANGELOG.md` | human-readable; **exempt from formal review** per guide §3 |

Audit-side artifacts (analogous to prd-analysis):

| Artifact | Path |
|----------|------|
| Issue files | `.review/round-N/issues/I-NNN.md` |
| Reviewer raw output | `.review/round-N/reviewer-output/<trace_id>.json` |
| Self-reviews | `.review/round-N/self-reviews/<trace_id>.md` |
| Plan | `.review/round-N/plan.md` |
| Round index | `.review/round-N/index.md` |
| Verdict | `.review/round-N/verdict.yml` |
| Version (on-converge) | `.review/versions/<N>.md` |
| Clarification | `.review/round-0/clarification/<ts>.yml` |
| Summary | `.review/issues/summary.yml` |

---

## 4. The redesign checklist (apply in this order)

### 4.1 Cleanup phase (chore commits — no behavior change)

1. **Delete legacy `.review/`** in `skills/system-design/.review/` (transient
   audit data from prior runs, not part of the redesign).
2. **Identify and delete obsolete skill-shape checkers** — same set
   prd-analysis deleted: `check-skill-md-sections.sh`,
   `check-mode-routing.sh`, `check-scaffold-sha.sh`,
   `check-checker-implementations.sh`, `check-criteria-yaml.sh`,
   `check-criteria-consistency.sh`, `check-skill-structure.sh` (if exists),
   `check-scripts-inventory.sh`, `check-config-schema.sh`,
   `check-trace-id-format.sh` (if exists), `check-dispatch-log-snippet.sh`,
   `check-ipc-footer.sh`, `check-artifact-pyramid.sh`,
   `check-frontmatter.sh` (the legacy one — the new per-artifact
   scripts will validate frontmatter inline), `check-changelog-consistency.sh`,
   `check-index-consistency.sh` (if exists), `check-dependencies.sh`,
   `check-drift.sh`, `build-depgraph.sh`, `scaffold.sh`. **Preserve the
   13 design-specific checkers** listed in §2 — they need refactoring,
   not deletion.
3. **Delete dead manifests**: `common/scaffold-provenance.yml`,
   `common/shared-scripts-manifest.yml`, `common/skeleton/` (if any).
4. **Strip skill-forge mentions** from `SKILL.md`, `common/snippets.md`,
   `review-criteria.md`, etc. (grep `skill-forge\|scaffold-provenance\|skeleton\|skip-set`
   and triage each hit — most are removable boilerplate, some are explanatory
   text that should stay with rewording).

### 4.2 Foundational scripts (one commit per group)

5. Add **`scripts/lib/sd_lint.py`** — direct port of
   `skills/prd-analysis/scripts/lib/prd_lint.py` with the same `Finding`
   dataclass, `parse_frontmatter`, `emit()`, etc. Naming convention: `sd_lint`
   instead of `prd_lint` to match the skill name.

6. Add **`tests/lib/test_helpers.sh`** — copy verbatim from prd-analysis;
   reusable across skills.

7. Add **`common/issue-schema.md`** — copy verbatim from prd-analysis. The
   issue schema is skill-agnostic.

### 4.3 Per-artifact formal-review scripts

For each system-design artifact, write **one `scripts/check-X.sh` + one
`tests/test-check-X.sh`**. Follow guide §9 contract: 3-state returncode
(0/1/2) + stdout restates the meaning + idempotent + agent-actionable Findings.

**Domain-bundle scripts (mirror prd-analysis's check-readme/feature/journey
pattern)**:

8. `check-readme.sh` — README.md (id index + Feature-Module matrix presence +
   no TBD/TODO + frontmatter). Emits CR-SD01 (readme-shape), CR-SD02
   (feature-module-matrix-present), CR-SD03 (no-TBD), CR-SDFM01 (frontmatter).

9. `check-module.sh` — `modules/M-NNN-{slug}.md` per-module: ID monotonicity
   (CR-SD04), required frontmatter (id, title, owner, status), no TBD, presence
   of required sections (Responsibilities, Public Interfaces, Data Models,
   Dependencies, Boundary Enforcement). Refactor the existing
   `check-module-interface-types.sh` and `check-module-deps-vs-protocols.sh`
   logic INTO this script (or call them as sub-routines).

10. `check-api.sh` — `api/API-NNN-{slug}.md` per-API: ID monotonicity, required
    frontmatter, per-endpoint blocks (refactor `check-api-per-endpoint-blocks.sh`),
    surface-cols (`check-api-surface-cols.sh`), endpoint-literal consistency
    (`check-endpoint-literal-vs-api.sh`).

11. `check-revisions.sh` — REVISIONS.md when present (mirror prd-analysis's).

**Cross-bundle scripts** (these are the design-specific ones — no direct
prd-analysis analogue, but follow the same emit pattern):

12. `check-feature-module-mapping.sh` — refactor of existing
    `check-feature-module-traceability.sh`: every feature in the PRD has at
    least one ✦ in the matrix; every module is referenced from at least one
    matrix cell. Read the linked PRD path from `.review/state.yml` or pass as
    arg. Emits CR-SD05.

13. `check-architecture-coverage.sh` — keep its current logic but reformat
    output to the §9 contract (Finding dicts + emit()).

14. `check-analytics-coverage.sh` — same: reformat to §9 contract.

15. `check-dependency-layering.sh` — keep logic, reformat output.

16. `check-placeholder-json.sh` — keep logic, reformat output.

17. `check-readme-references.sh` — keep logic, reformat (or merge into
    `check-readme.sh` as a sub-check).

18. `check-single-source-of-truth.sh` — keep logic, reformat.

19. `check-boundary-enforcement-cols.sh` — keep, reformat (could be merged
    into check-module.sh as a sub-check; engineer's choice).

**Audit-side scripts (verbatim port from prd-analysis with sd_lint imports)**:

20. `check-issue.sh` — issue file schema validation
21. `check-clarification.sh` — clarification yml
22. `check-plan.sh` — plan.md
23. `check-self-review.sh` — writer self-reviews
24. `check-reviewer-output.sh` — reviewer JSON output
25. `check-round-index.sh` — round-N/index.md
26. `check-verdict.sh` — verdict.yml
27. `check-version.sh` — versions/<N>.md

**Phase gates + helpers (verbatim port from prd-analysis)**:

28. `check-review-readiness.sh`
29. `check-revise-completeness.sh`
30. `verify-phase-entry.sh` (with system-design-specific `generate-fresh`
    precondition: design output dir is empty)
31. `create-issues.sh` (verbatim — schema is skill-agnostic; **MUST include
    the leading-summary-line tolerance fix from prd-analysis commit `9cec6b8`**)
32. `update-summary.sh` (verbatim — but verify it correctly emits the
    `history` and `fix_history` blocks from `commit 7a25f1d`)
33. `synthesize-clarification.sh` (verbatim — orchestrator pure-dispatch
    helper for `--no-consultant`)
34. `run-checkers.sh` — thin dispatcher that auto-discovers every
    `check-*.sh` (excluding phase gates). Verbatim port.
35. **Existing infrastructure to preserve**: `git-precheck.sh`, `prepare-input.sh`,
    `glossary-probe.sh`, `commit-delivery.sh`, `prune-traces.sh`,
    `metrics-aggregate.sh` + `lib/aggregate.py`. **Note**: prepare-input.sh
    must include the **CJK word_count fix** from prd-analysis commit `b9cb7fa`.

### 4.4 Orchestration files

36. **`SKILL.md`** — add the **Phase Contract** section (mirror
    `prd-analysis/SKILL.md` lines covering the boundary-gate mapping table).
    Update Mode Routing to drop legacy `review-checklist.md` etc. and reference
    `common/issue-schema.md`. Update CLI flags table to drop `--full`
    (skip-set is dead).

37. **`review/index.md`** — Step 1 MUST be
    `scripts/verify-phase-entry.sh read <design-dir>`. Step 2: cross-reviewer
    dispatch. Step 3: adversarial-reviewer (conditional). Step 4:
    `create-issues.sh`. Step 5: `update-summary.sh`. Step 6: summarizer. Step
    7: judge. Step 8: verdict routing. Step 9: delivery sequence. Mirror
    prd-analysis structure.

38. **`revise/index.md`** — Step 1 MUST be
    `scripts/verify-phase-entry.sh revise <design-dir> <round>`. Then build
    issue-group manifest, fan-out per-issue revisers, self-verify formal pass,
    `check-revise-completeness.sh`, update-summary, summarizer, judge.

39. **`generate/from-scratch.md`** — Step 1 git-precheck, Step 2
    `verify-phase-entry.sh generate-fresh <design-dir>`, Step 3 prepare-input,
    Step 4 glossary-probe, Step 5 domain-consultant (conditional), Step 6
    planner, Step 7 HITL plan-approval gate, Step 8 writer fan-out, Step 9
    enter review/index.md.

40. **`generate/new-version.md`** — same shape with `verify-phase-entry.sh
    generate-evolve`.

### 4.5 Subagent prompts

41. **`generate/planner-subagent.md`** — **CRITICAL**: rewrite the
    "FromScratch mode" section's `add` list to be the system-design bundle,
    NOT skill-bundle files. Canonical shape: `README.md`,
    `modules/M-NNN-{slug}.md` (one per module the planner derives from PRD
    features), `api/API-NNN-{slug}.md` (one per API surface). **Bug 2 from
    prd-analysis (commit `b9cb7fa`) was exactly this issue** — verify your
    rewrite doesn't reintroduce skill-shape paths like
    `generate/writer-subagent.md` in the example YAML. Templates to reference:
    `common/templates/module-template.md`, `common/templates/api-template.md`,
    `common/templates/design-readme-template.md`.

42. **`generate/writer-subagent.md`** — adapt prd-analysis's writer to
    system-design's leaf classes: Module spec, API contract, README. Update
    the formal pre-check section to invoke per-artifact `check-X.sh` for the
    leaf type assigned (NOT `run-checkers.sh` — that scope is too broad for
    a single writer).

43. **`generate/in-generate-review.md`** — port from prd-analysis with
    leaf-type → CR mapping for system-design CRs.

44. **`generate/domain-consultant-subagent.md`** — adapt R-001..R-007
    requirements to design-specific scope (e.g. R-002 should ask about module
    granularity rather than journey count).

45. **`review/cross-reviewer-subagent.md`** — emit JSON to
    `<round-dir>/reviewer-output/<trace_id>.json`. Read summary.yml for
    fingerprint matching. Apply ONLY checker_type:llm criteria. **No issue
    files written directly by reviewer** — guide §7.1.

46. **`review/adversarial-reviewer-subagent.md`** — same shape.

47. **`revise/per-issue-reviser-subagent.md`** — state machine transitions
    (new → fixed/false-positive/deferred/superseded). Append to history (per
    revise/index.md contract).

48. **`shared/judge-subagent.md`** — use the **fixed convergence rule**:
    only `new_count == 0`, `recurrence_count == 0`, `justified_regressions_ok`
    matter. **Do NOT include `critical_count == 0` or `error_count == 0`
    checks** — those were Bug 3 in prd-analysis (commit `c65cbf9`); they
    incorrectly block convergence after fixes because severity counts are
    over all states.

49. **`shared/summarizer-subagent.md`** — Phase 1 (per-round) + Phase 2
    (on-converge). Mirror prd-analysis exactly.

### 4.6 Common files

50. **`common/review-criteria.md`** — partition criteria into Formal
    (script-type) and Substantive (LLM-type) per audit guide §1.3. Each formal
    CR has `script_path: scripts/check-X.sh` (note: when multiple scripts
    emit the same CR, declare a primary owner and add the
    "script_path is illustrative" note from prd-analysis review-criteria
    preamble — see prd-analysis commit `9cec6b8`).

51. **`common/config.yml`** — fix `tool_permissions` for reviewer (writes
    `reviewer-output/`, NOT `issues/`), reviser (writes leaf + issue
    transitions + version files), judge (must include `read-issues-summary`
    + `read-state-yml`). Drop the `--full` flag and skip-set references.

52. **`common/snippets.md`** — drop or rephrase references to deleted check
    scripts (`check-dispatch-log-snippet.sh`, `check-ipc-footer.sh`).

53. **`common/templates/review-readme-template.md`** — port the new state
    machine vocabulary from prd-analysis.

### 4.7 Tests

54. Add **`tests/run-all.sh`** — verbatim port; auto-discovers `test-*.sh`.

55. Add **one `tests/test-check-X.sh` per `scripts/check-X.sh`**. Each test
    file covers:
    - Exit-code semantics (0 / 1 / 2)
    - Each CR the script emits has at least one passing fixture and one
      failing fixture
    - Idempotency
    - Edge cases (missing dir, empty dir, bad input)

    Aim for 5–15 test cases per script. The 14 per-artifact test runners in
    prd-analysis average ~12 tests each; replicate that density.

56. Add **`tests/test-verify-phase-entry.sh`** with test cases for each
    phase mode (read / revise / generate-fresh / generate-evolve).

57. Add tests for the helpers (`test-create-issues.sh`,
    `test-update-summary.sh`, `test-synthesize-clarification.sh`,
    `test-prune-traces.sh`, etc.) — copy from prd-analysis with appropriate
    fixture adjustments.

58. **Goal: all tests pass before end-to-end test**. Final
    `bash tests/run-all.sh` should report ≥350 passing, 0 failing.

### 4.8 Documentation

59. **`README.md`** — developer-facing, mirror prd-analysis's. Sections:
    What it produces (the design bundle), Modes, Phase Contract architecture,
    Output mapping (artifact ↔ script ↔ test), Issue lifecycle, Running tests,
    Adding a new artifact / CR, Design references, Stats.

### 4.9 End-to-end test on real input

60. **Find a real PRD** to run system-design against. Best option: use the
    PRD that prd-analysis just produced —
    `/Users/wangzw/workspace/auto-flows/docs/raw/prd/2026-04-29-multi-agent-task-system/`.
    It has 23 leaves (3 journeys + 9 features + 9 architecture topics +
    README + architecture index), all formal-clean, recently delivered.

61. **Run the full pipeline manually** (mirror what was done for prd-analysis):
    ```
    a) git-precheck on the artifact root
    b) verify-phase-entry generate-fresh on a NEW design output dir
    c) prepare-input + glossary-probe + synthesize-clarification (--no-consultant)
    d) Dispatch planner subagent (sonnet model) → produces plan.md
    e) Verify check-plan.sh PASSES on plan.md
    f) Fan out writers in parallel (one per module + one per API + README) — use Agent tool with run_in_background:true
    g) verify-phase-entry read
    h) Dispatch cross-reviewer + adversarial-reviewer
    i) create-issues.sh, update-summary.sh, summarizer, judge
    j) Dispatch revisers per file group; check-revise-completeness; update-summary
    k) Loop review/revise until verdict=converged
    l) Phase 2 summarizer + commit-delivery → annotated git tag
    m) metrics-aggregate.sh --diagnose --delivery 1
    ```

62. **Bug-find as you go**. Apply prd-analysis's lessons:
    - Watch for **CJK** failures in `prepare-input.sh` (the `word_count` fix
      should already be in your port; verify).
    - Watch for **planner SKILL-leak** — verify the planner emits
      `modules/M-NNN-...md` paths, NOT `generate/writer-subagent.md` paths.
    - Watch for **judge convergence-rule** issues — your port should already
      have the fix; verify by reading the converged-rule body.
    - Watch for **reviser stream timeouts on large issue batches** —
      dispatch revisers with single-issue scope or 2-issue scope max. Don't
      bundle 5+ issues per reviser.
    - Watch for the **on-converge summarizer** to be dispatched correctly
      after the verdict (it's a separate dispatch, not the same as Phase 1).

63. **Fix any bug found** in place; add a regression test; verify the fix
    end-to-end. The full cycle test on prd-analysis surfaced 3 real bugs;
    expect a similar order of magnitude on system-design.

### 4.10 Independent code review

64. **Spawn a code-reviewer agent** (`Agent` tool, `subagent_type:
    superpowers:code-reviewer`) AFTER all the above is committed and tests
    pass. Brief it the same way prd-analysis was reviewed:
    1. Run `bash skills/system-design/tests/run-all.sh`; confirm all pass
    2. Trace step numbering across orchestration files
    3. Verify verify-phase-entry contract is wired correctly
    4. Verify create-issues.sh contract (default mode reads
       reviewer-output/, --stdin tolerates leading summary line)
    5. Verify update-summary.sh emits history/fix_history/recurrence_count
    6. Look for orphans / dead code
    7. Schema drift between docs and code

   Address any CRITICAL or HIGH findings; document MEDIUM/LOW for follow-up.

65. **Lock in**: once all reviewer findings are addressed, the redesign is
    done. The skill is at parity with prd-analysis.

---

## 5. Working style guidance

- **Commit frequently** — one logical change per commit. The prd-analysis
  redesign was 23 commits; system-design will be similar.
- **Run `bash skills/system-design/tests/run-all.sh` after every commit**.
  Don't accumulate broken tests.
- **Don't blindly copy from prd-analysis**. Some files (issue-schema, helpers,
  test framework) are skill-agnostic and CAN be copied verbatim. Others
  (planner, writer, criteria) are skill-specific and need rewriting.
- **Use bash + Python (stdlib only)**. No `pyyaml`, no `jq`, no third-party
  packages — same dependency policy as prd-analysis.
- **The `Agent` tool with `model: sonnet`** is appropriate for testing the
  planner / writer / reviewer / reviser dispatches at lower cost. Use
  `model: haiku` for summarizer + judge (light tier).
- **Use `run_in_background: true`** when fanning out parallel writers or
  revisers. Wait for completion notifications.

---

## 6. Definition of done

- [ ] All legacy skill-shape checkers + dead manifests removed
- [ ] Per-artifact formal-review scripts written (≥7 system-design–specific +
      8 audit-side scripts; total ≥15 `check-*.sh`)
- [ ] All scripts follow guide §9 contract (3-state returncode, stdout
      restates, idempotent, agent-actionable Findings via `sd_lint.emit()`)
- [ ] Phase-gate scripts present:
      `verify-phase-entry.sh` (4 phases), `check-review-readiness.sh`,
      `check-revise-completeness.sh`
- [ ] Helpers present: `create-issues.sh` (with stdin-summary tolerance),
      `update-summary.sh` (with history/fix_history fields),
      `synthesize-clarification.sh`, `run-checkers.sh` (auto-discovery
      dispatcher)
- [ ] Orchestration files (review/index.md, revise/index.md, generate/*) all
      have **Step 1 = MANDATORY verify-phase-entry.sh call**
- [ ] Subagent prompts updated: planner emits design-bundle paths; reviewer
      writes JSON; reviser does state transitions; judge uses fixed
      convergence rule
- [ ] `common/issue-schema.md`, `common/review-criteria.md` (formal/substantive
      split) present
- [ ] `tests/` directory with ≥350 tests passing across ≥20 runners
- [ ] `README.md` developer-facing doc present
- [ ] End-to-end test on real PRD (auto-flows multi-agent system) reaches
      `verdict: converged` and produces a committed delivery tag
- [ ] `metrics-aggregate.sh --diagnose` works for both `--round` and
      `--delivery` scopes
- [ ] Independent code-reviewer agent run; all CRITICAL/HIGH findings
      resolved
- [ ] Final commit message at HEAD: `feat(system-design): redesign per
      audit-design guide — full cycle verified` (or similar)

---

## 7. References — exact file paths & commit hashes

**Audit-design guide**: `~/Documents/mind/raw/guide/生成式skill的审查设计.md`
(read sections §1.3 dual-criteria, §5 convergence, §7 issue lifecycle, §9
script contract, §10 self-closure).

**Reference implementation**:
`/Users/wangzw/workspace/cofounder/skills/prd-analysis/`

**Key prd-analysis commits to consult** (read with
`git -C /Users/wangzw/workspace/cofounder show <hash>`):

| Commit | What |
|--------|------|
| `4bce546` | Remove skill-forge + legacy .review (cleanup template) |
| `45bb418` | Drop skill-shape checkers (which scripts to remove) |
| `a5598a9` | Formal-review pipeline (the 7 foundational scripts) |
| `278579e` | Orchestration + subagent prompts (template for reviewer/reviser/judge prompts) |
| `4fd7402` | review-criteria split + SKILL routing + writer formal pre-check |
| `97b2d5f` | Generate-mode self-audit alignment (writer per-artifact pre-check) |
| `5a4cd69` | Self-review fixes (recurrence_count chain + same-batch dedup + Step 9 delivery sequence) |
| `b8b8a75` | Writer self-audit scoping (per-leaf, not whole-bundle) |
| `7a25f1d` | C1/C5/M1/M3/M4 fixes (reviewer IPC contract: --stdin + from-dir, history fields, CR-PP01 split, config.yml perms, synthesize-clarification) |
| `dfdb6c8` | M2 doc clarity |
| `2df9822` | Phase Contract docs (SKILL.md elevation) |
| `24f894a` | verify-phase-entry.sh (script-enforced gates) |
| `9cec6b8` | Stream-summary tolerance + CR-META + step renumbering |
| `b9cb7fa` | CJK word_count + planner SKILL-leak fixes (real bugs from end-to-end test) |
| `c65cbf9` | judge convergence-rule fix (the critical_count over-strict bug) |

When in doubt, do `git diff HEAD <commit>~1 -- skills/prd-analysis/<path>` to
see the exact change.

---

## 8. What NOT to do

- ❌ Don't copy `skills/prd-analysis/` wholesale into `skills/system-design/`
  with sed-renames. The artifacts are different, the CRs are different, and
  blind copy will lose the design-specific checks.
- ❌ Don't preserve any `check-skill-md-sections.sh` /
  `check-mode-routing.sh` / `check-scaffold-sha.sh` style scripts —
  these are skill-shape, not design-shape.
- ❌ Don't reintroduce the **3 bugs prd-analysis already fixed** —
  CJK word_count, planner SKILL-leak, judge over-strict. Verify each fix is
  carried forward to system-design.
- ❌ Don't run the test cycle without first ensuring all unit tests pass.
  Cycle bugs are expensive; unit tests are cheap.
- ❌ Don't bundle 5+ issues into one reviser dispatch — observed stream
  timeouts in prd-analysis. Single-issue or 2-issue scope only.

---

## 9. First action

When you start: **read this file end-to-end first**, then read the audit
guide, then `cd /Users/wangzw/workspace/cofounder` and run:

```bash
git log --oneline 4bce546~1..HEAD -- skills/prd-analysis/ | head -25
```

to confirm you can see the 23-commit chain. Then propose a written plan back
to the user (don't start coding immediately) — list the proposed order of
operations and ask for approval before the first commit.

Good luck.
