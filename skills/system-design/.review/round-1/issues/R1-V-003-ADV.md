---
issue_id: R1-V-003-ADV
round: 1
file: review/index.md
criterion_id: CR-L11
severity: blocker
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# `--review` and generate-mode write to TWO different issue paths; revisers consume neither correctly

## Attack angle

Mode confusion → silent issue-loss. Output paths for cross-reviewer issues are documented three different ways across the skill; the actual sub-agent prompt writes to a path the revise pipeline never reads.

## Evidence

Three different output paths for the same artifact:

| Source | Stated path |
|--------|-------------|
| `review/index.md` line 99 (--review mode 4a) | `<design-dir>/.reviews/REVIEW-<NNN>.md` (capital S in `.reviews/`) |
| `review/cross-reviewer-subagent.md` line 192-195 | `<design-dir>/.reviews/REVIEW-<NNN>.md` for `--review` mode; `<design-dir>/.review/round-<N>/issues/REVIEW-<NNN>.md` for generate-mode internal review |
| `generate/from-scratch.md` line 173 (Step 9 lint output) | `<target>/.review/round-1/issues/` (no S, no REVIEW prefix) |
| `generate/from-scratch.md` line 188-196 (Step 10) | `<target>/.review/round-1/issues/` |

But the cross-reviewer prompt's frontmatter schema says:
```
id: R<N>-<seq>
```
and the adversarial prompt's schema says:
```
issue_id: <target-slug>-round-<N>-<seq>
```

These are different keys (`id:` vs `issue_id:`) and different formats. The judge subagent (`shared/judge-subagent.md` lines 100-101) reads issue frontmatter and counts by `severity`, `criterion_id`, `status`, `round`. Neither key it expects (`id`/`issue_id` is implicit) is consistent across cross + adversarial. If they collide, summarizer counts may double or miss issues.

## Concrete production failure

The reviser pipeline (`revise/index.md` Step 2) globs `<design-dir>/.reviews/REVIEW-*.md`. The generate-mode internal review writes to `<design-dir>/.review/round-1/issues/`. **A user who runs `--revise` after a generate-mode round 1 with open issues finds nothing in `.reviews/` and gets**:

> No open issues found in <design-dir>/.reviews/. Run --review first.

…even though the round-1 generate cycle DID file issues. The user would need to know to either (a) re-run `--review` to copy issues into the right place, or (b) hand-edit the directory. This is a silent abandonment of every issue raised inside the generate loop.

## Adversarial angle

The cross-reviewer files generate-mode issues to `.review/round-N/issues/`. The reviser fan-out in generate-mode is supposed to consume them — but `from-scratch.md` Step 9 (lint reviser loop) is hand-waved and Step 12 (judge) returns `progressing` only on issue change, while no formal generate-mode reviser dispatch is described between Step 10 (review) and Step 12 (judge). Re-read `from-scratch.md`: the dispatch sequence has Step 9 lint → Step 10 review → Step 11 summarizer → Step 12 judge. No step calls `revise/per-issue-reviser-subagent.md` to actually FIX the issues found in Step 10. Step 12 just emits `verdict: progressing` and "loop from Step 8 (writer fan-out on changed files only, as listed in `verdict.yml.changed_files`)" — but `verdict.yml`'s schema (`shared/judge-subagent.md` lines 148-165) has no `changed_files` field.

## Fix

1. Standardise the in-generate output path. Pick ONE of:
   - `<target>/.review/round-<N>/issues/<issue-id>.md` (consistent with skill-forge IPC)
   - `<target>/.reviews/REVIEW-<NNN>.md` (consistent with `--review` mode)
   Update cross-reviewer-subagent.md, adversarial-reviewer-subagent.md, from-scratch.md Step 9-10, judge-subagent.md, summarizer-subagent.md to all reference the chosen path.

2. Standardise issue ID schema. Pick `id:` OR `issue_id:`. Make cross-reviewer + adversarial-reviewer use the SAME key. Currently one uses `id` and the other uses `issue_id`.

3. Add a real "Step 9.5 — Per-issue reviser fan-out" (or rename Step 11) to `from-scratch.md` that dispatches `revise/per-issue-reviser-subagent.md` once for each blocker issue from Step 10 BEFORE Step 12 judge. Otherwise the generate loop converges on issues that nobody fixes.

4. Add a `changed_files` field to `judge-subagent.md` `verdict.yml` schema, OR remove the reference in `from-scratch.md` Step 12.
