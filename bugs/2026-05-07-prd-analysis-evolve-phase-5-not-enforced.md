# Bug: prd-analysis `--evolve` does not enforce Phase 5 (Frontend Draft) for new/modified UI features

| Field | Value |
|---|---|
| Skill | `prd-analysis` |
| Mode | `--evolve` (also affects `--review` formal gate) |
| Severity | High — converged deliveries silently lack a load-bearing schema section; downstream consumers (`system-design`, `autoforge`) lose the user-validation signal. |
| Status | Open |
| Filed | 2026-05-07 |
| Filed by | Reproduced on `castworks` repo, delivery-2 (`docs/raw/prd/2026-04-11-castworks/.review/round-5/`) |

## Summary

`evolve-mode.md` prescribes Phase 5 (Frontend Draft generation) for every new or modified user-facing feature in an evolve delivery. The prescription exists in prose only — nothing in the orchestration sequence, the formal checker, or the convergence verdict requires it to actually run. As a result, an evolve delivery can converge with new UI features that have:

- A complete `## Interaction Design` section (Screen & Layout, Component Contracts, ISM, Form Specification, Micro-Interactions, A11y, i18n, Responsive)
- **No** `#### Frontend Draft Reference` subsection
- **No** code under the project's Frontend Implementation Path
- **No** user-experience confirmation

The schema half-says the feature is design-complete; reality is that the visual / interaction draft never existed.

## Reproduction (verified on castworks delivery-2)

1. Start with a baseline PRD that has user-facing features (e.g. `docs/raw/prd/2026-04-11-castworks/`, baseline = delivery-1, 49 features).
2. Run `/prd-analysis --evolve <prd-dir>` with input notes proposing a new UI feature **and** a rewrite of an existing UI feature (delivery-2 added F-050 admin Providers page and rewrote F-047 with per-provider toggle UI).
3. Let the evolve flow proceed to convergence (delivery-2 converged in `round-5` with 41/43 issues fixed).
4. Inspect the converged artifacts:

```
$ grep -lE "^#### Frontend Draft Reference|^### Frontend Draft Reference" \
    docs/raw/prd/2026-04-11-castworks/features/*.md
# (no matches — zero features in the bundle have the new-style section)

$ grep -lE "^## Prototype Reference" docs/raw/prd/2026-04-11-castworks/features/*.md
# (17 features still carry the OLD-style Prototype Reference, pointing at a
#  prototypes/screenshots/ directory that does not exist on disk)

$ ls docs/raw/prd/2026-04-11-castworks/features/F-050-llm-provider-admin-page.md
# 621 lines — full Interaction Design section, but no Frontend Draft Reference,
# no Prototype Reference, no path under frontend/src/.

$ ls frontend/src/pages/admin/providers/ 2>/dev/null
# (no such directory — the admin Providers page F-050 specifies has no implementation)
```

The orchestrator never prompted the user with the evolve-mode.md prose:
> **Ask:** "Do new/modified user-facing features need a frontend draft now?"

and the convergence verdict (`round-5/verdict.yml`) carries `formal_pass: true` despite the missing Phase-5 artifact.

## Expected behavior

For an evolve delivery whose plan contains at least one user-facing feature in `add` or `modify`:

1. Phase 5 (Frontend Draft) MUST run for each such feature.
2. Each affected feature file's `#### Frontend Draft Reference` MUST be populated:
   - `Draft path: {repo-root}/{frontend-implementation-path}/{feature-area}/`
   - `Confirmed (experience): YYYY-MM-DD`
3. The convergence verdict MUST NOT report `formal_pass: true` if any user-facing feature in the delivery scope has an empty Frontend Draft Reference.

## Root cause analysis

### Cause #1 — Phase 5 is "deep-dive" prose, not a phase gate

`generate/evolve-mode.md` lines 155-156:
```
- **Ask:** "Do new/modified user-facing features need a frontend draft now?"
- **Deep-dive:** run the Phase 5 flow (`generate/questioning-phases.md` →
  Phase 5: Frontend Draft) for new and modified user-facing features only.
```

`generate/evolve-mode.md` line 204 (the per-phase summary):
```
8. **Frontend draft** — only for new/modified user-facing features; modify
   the code at the baseline's Frontend Implementation Path in place. Update
   each affected feature file's Frontend Draft Reference (path + new
   Confirmed date).
```

These are descriptive, not enforced. Nothing in `generate/new-version.md` (the orchestration file) calls a `verify-phase-5-completion.sh` style gate, and there is no `check-frontend-draft.sh` script under `scripts/`.

### Cause #2 — `check-feature.sh` does not require Frontend Draft Reference on user-facing features

The current per-feature formal checker (`scripts/check-feature.sh`) enforces only:
- CR-FM01 — frontmatter required fields (`id`, `title`, `status`)
- CR-PP02, CR-PP04, CR-PP15F — generic structural rules

There is no rule of the form: *"if the feature contains `## Interaction Design`, it MUST also contain a populated `#### Frontend Draft Reference`."*  Because the rule does not exist, the cross-reviewer cannot raise it as an issue, the revise loop has nothing to fix, and the convergence verdict computes `formal_pass: true`.

### Cause #3 — Evolve plan template does not list Frontend Draft as a deliverable per touched UI feature

`generate/planner-subagent.md` produces a plan whose `modify`/`add` rows describe what content the writer should put into each feature file. The plan does not have a column or sibling row for "produce frontend draft at `<path>` for this feature." Without that, the writer subagent has no instruction to call into Phase 5, and the orchestrator has nothing to verify after the writer returns.

### Cause #4 — The bundle is mid-migration from old "Prototype Reference" schema

The castworks bundle was migrated from an older schema (commit `6b40e33` — "migrate 2026-04-11-castworks bundle to current schema"). The migration did not strip stale `## Prototype Reference` blocks (17 features still carry them, pointing at a non-existent `prototypes/screenshots/` directory) and did not insert the new `#### Frontend Draft Reference`. This is its own bug to file separately, but it interacts with this one: the lack of an enforcement gate let the migration's incomplete state survive through delivery-2 evolution.

## Proposed fix

### Minimum (closes the silent-pass)

1. **Add `scripts/check-frontend-draft.sh`** with rule `CR-PP-FD01`:
   - For every feature file containing `^## Interaction Design`, require a populated `^#### Frontend Draft Reference` subsection containing both `Draft path:` and `Confirmed (experience):` lines.
   - `Confirmed (experience):` MAY be `null` for explicitly-deferred drafts (records the gap rather than hides it), but null requires a sibling `Drift:` line stating why.
2. **Wire the new check into `scripts/run-checkers.sh`** so it runs as part of the formal-review hard gate.
3. **Update `common/review-criteria.md`** to register `CR-PP-FD01` as a script-tier criterion.

### Stronger (closes the missed prompt in evolve)

4. **Add Phase-5 readiness verification to `scripts/verify-phase-entry.sh`** (or a new `verify-phase-5-readiness.sh`) called from `generate/new-version.md` Step N (post-write, pre-review). Block transition to read phase if any feature touched in this delivery's plan has an unpopulated Frontend Draft Reference.
5. **Augment `planner-subagent.md`** to emit, for every `add` or `modify` row referencing a user-facing feature, a paired `frontend_draft` directive with `target_path` and `must_run_phase_5: true`.
6. **Augment `writer-subagent.md`** to either run Phase 5 inline or escalate to the orchestrator (depending on the orchestrator's pure-dispatch contract — likely escalate, since the writer is artifact-only).

### Optional (full-loop fix)

7. **Update `evolve-mode.md`** §Phase 5 to be a numbered step in the orchestration sequence rather than prose under "Per-phase delta questioning"; reference the new gate script.
8. **Update the convergence verdict template (`shared/judge-subagent.md`)** so `formal_pass` AND a new `phase5_pass` are required for `converged: true` on evolve deliveries.

## Workaround (until fixed)

After an evolve delivery converges, manually:
1. Diff `plan.md` against `features/` to enumerate new + modified user-facing features.
2. For each, run Phase 5 manually: confirm the Frontend Implementation Path, generate or update the runnable draft under `frontend/src/...`, validate the experience with the user.
3. Edit each affected feature file to add the `#### Frontend Draft Reference` subsection with `Draft path:` and `Confirmed (experience):` populated.
4. File a follow-up evolve delivery (e.g. delivery-N+1) whose only purpose is to apply the schema patch and record the user-experience confirmations. Note in `REVISIONS.md` that this fills a gap left by an earlier evolve.

## Impact

- **PRD authenticity** — the `Status: converged` verdict overstates the delivery's completeness; downstream `system-design` consumers receive a feature spec whose visual contract has never been seen by a human.
- **Coding-agent fidelity** — `autoforge` builds production code from feature files and assumes the Frontend Draft Reference points at a confirmed, runnable starting point. With an empty section, autoforge has no anchor for visual fidelity.
- **Migration debt accumulates silently** — repos in transition between the old `## Prototype Reference` schema and the new `#### Frontend Draft Reference` schema (like castworks) carry no detectable signal that they're mid-migration.

## Related artifacts

- Reproducing PRD: `docs/raw/prd/2026-04-11-castworks/` (castworks repo)
- Convergence verdict (false-pass): `docs/raw/prd/2026-04-11-castworks/.review/round-5/verdict.yml`
- Affected features in delivery-2: `F-049-llm-provider-management.md` (backend, no UI), `F-050-llm-provider-admin-page.md` (NEW UI, missing draft), `F-047-org-llm-config-page.md` (rewritten UI, missing draft + drifted from existing code), `F-035-system-config-page.md` (UI scope demoted, missing draft + drifted from existing code)
- Skill files implicated:
  - `skills/prd-analysis/generate/evolve-mode.md` (prose, lines 153-156, 200-204)
  - `skills/prd-analysis/generate/new-version.md` (orchestration; no Phase-5 gate)
  - `skills/prd-analysis/generate/planner-subagent.md` (plan rows lack Phase-5 directive)
  - `skills/prd-analysis/scripts/check-feature.sh` (no Frontend Draft Reference rule)
  - `skills/prd-analysis/scripts/run-checkers.sh` (no Phase-5 hook)
  - `skills/prd-analysis/common/review-criteria.md` (no `CR-PP-FD01`)
- Castworks ADR / REVISIONS entry to be added in delivery-3.
