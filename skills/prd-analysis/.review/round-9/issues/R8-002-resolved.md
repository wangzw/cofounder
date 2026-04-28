---
id: R8-002-resolved
round: 9
file: SKILL.md
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolves: R8-002
---

# R8-002 resolved: SKILL.md "Exception for revise-mode Step 2" carve-out has been deleted

## Verification

Round-8 reviser R8-R-002 deleted the legacy `Exception for revise-mode Step 2` carve-out
that R8-002 flagged. The current `SKILL.md` line 41 now reads:

> **Exception for review-mode Step 1 and Step 4:** The main agent MAY read `README.md`,
> `REVISIONS.md`, and `architecture.md` (the index file) during inventory — these are
> index/navigation files, not per-feature or per-journey artifact leaves. The main agent
> MAY perform targeted reads of single feature or journey files when a cross-file check
> requires spot-verification. It MUST NOT bulk-read the full feature/journey set.

This is a `review-mode`-only carve-out (note "review-mode Step 1 and Step 4"). It refers
to the canonical `review/index.md` orchestration (which SKILL.md mode-routing line 19
points at), not to the retired `revise/revise-mode.md` interactive flow.

The R8-002 defect — the carve-out targeting `revise/revise-mode.md` Step 2 ("Present PRD
Overview") which is not part of the canonical `revise/index.md` Step 2 ("Fan-out
Per-Issue-Reviser") — is gone. The carve-out semantics are now coherent with the
canonical mode-routing.

This corresponds to R8-002's "Option 1 — Delete line 43 entirely" suggested fix, modulo
the introduction of a tightly-scoped review-mode-only carve-out that was already needed
for review-mode Step 1's README inventory read. That review-mode carve-out matches
the canonical review/index.md Step 1 + Step 4 orchestration semantics. No legacy
revise-mode reference remains in the carve-out.

## Class-based scan note

I grep'd all five focus leaves for legacy revise-mode terminology (`revise-mode|revise/revise|Pre-Answered|Clustering|fix subagent|revise-mode Step (2|5)`).
After the round-8 fixes, no in-focus leaf still references the retired interactive
revise flow:

- `SKILL.md` line 41: review-mode-only carve-out (canonical) — clean.
- `common/parallel-dispatch.md` line 4: revise-mode Step 2 fan-out (canonical) — clean.
- `common/parallel-dispatch.md` line 134: revise/index.md Step 2 (Fan-out) (canonical) — clean.
- `review/index.md` lines 25, 106: revise/index.md (canonical) — clean.

The dual-spec drift class that opened R7-V001-002, R7-V001-003, R8-001, R8-002 is now
fully closed across all five focus leaves.

## Status

`resolved` — the stale revise-mode carve-out is deleted; the new carve-out targets the
canonical review-mode flow only.
