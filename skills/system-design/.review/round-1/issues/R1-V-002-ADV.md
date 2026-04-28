---
issue_id: R1-V-002-ADV
round: 1
file: review/cross-reviewer-subagent.md
criterion_id: CR-L11
severity: blocker
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Cross-reviewer scope is contradicted across three files; CR-L01..L11 are silently dropped

## Attack angle

Mode confusion + criterion-coverage gap. The cross-reviewer is the LLM half of the two-phase quality gate, yet its scope is documented three different ways. The strict reading (subagent prompt itself) drops 11 of the 21 LLM criteria, including CR-L01 orchestrator-pure-dispatch, CR-L02 ack-contract-fidelity, and CR-L11 cross-reference-consistency — i.e. exactly the criteria that protect the dispatch loop.

## Evidence

Three contradictions:

1. **`review/cross-reviewer-subagent.md` line 7-8**:
   > Evaluates all LLM-type criteria (CR-D01..CR-D10) against the focused leaves. Mechanical criteria (CR-L1..L5, CR-X1..X8) are excluded — they are covered by `scripts/run-checkers.sh`

   And line 96-98 + line 132 + line 150 repeat: scope is **only CR-D01..CR-D10**.

2. **`review/index.md` line 98** (the input contract handed to that same sub-agent):
   > `common/review-criteria.md` (CR-L01..CR-L11 and CR-X1..CR-X8 semantic sides)

   This claims CR-L01..L11 ARE in scope.

3. **`common/review-criteria.md`** has both:
   - **CR-L1..L5** (script-tier domain lint, with `script_path:`) — correctly script-tier
   - **CR-L01..CR-L11** (LLM-tier generic criteria, no `script_path:`) — semantic, must be evaluated by a reviewer

   The cross-reviewer prompt's "CR-L1..L5 ... excluded" is correct ONLY for CR-L1..L5 (digit forms). It then conflates them with CR-L01..L11 (zero-padded forms). The prompt as written tells the reviewer to skip BOTH families.

## Why this breaks production

CR-L01 (orchestrator-pure-dispatch), CR-L02 (ack-contract-fidelity), CR-L05 (artifact-template-self-contained), CR-L06 (writer-prompt-quality-bar), CR-L07 (reviewer-prompt-discipline), CR-L09 (blocker-scope-taxonomy), CR-L11 (cross-reference-consistency) are LLM-type with NO script tier. None of them are covered by `scripts/run-checkers.sh` — verified by reading `common/review-criteria.md` lines 587-764 (the LLM-Type block has no `script_path:` keys). If the cross-reviewer skips them, NO ONE checks them. Every generated design will silently pass an orchestrator that violates pure-dispatch, an ACK contract that allows inline content, etc.

This is the classic CR-S17 problem (`checker-implements-declared-cr`) but at the LLM-tier: the criteria are declared, but the reviewer is told not to evaluate them.

## Adversarial angle (vs. CR-L07 which the cross-reviewer would file at most)

The cross-reviewer cannot file a finding against itself. Even if it could, it would file against a single line ("review/index.md says CR-L01..L11 in scope"). The adversarial angle is the **systemic gap**: the trigger for adversarial-reviewer is "in-generate critical or error issue" (`config.yml adversarial_review.triggered_by: [critical]`), but every CR-L01..L11 violation will be missed by the cross-reviewer in round 1, so adversarial may never be triggered for those classes either. The skill silently converges on broken artifacts.

## Fix

In `review/cross-reviewer-subagent.md`:

1. Line 7-8 → "Evaluates all LLM-type criteria (CR-L01..CR-L11 generic + CR-D01..CR-D10 domain) against the focused leaves. Script-tier criteria (CR-S01..S17, CR-L1..L5 digit-form, CR-X1..X8) are excluded — covered by `scripts/run-checkers.sh`."
2. Lines 105-118 (the criteria scope table) — add rows for CR-L01..CR-L11 with one-line dimension descriptions.
3. Line 132 — replace "CR-D01..CR-D10" with "CR-L01..CR-L11 and CR-D01..CR-D10".
4. Line 150 — match the corrected scope.

Also: rename CR-L01..CR-L11 in `common/review-criteria.md` to a different prefix (e.g. CR-LM01..CR-LM11 for "LLM-Meta") to disambiguate from CR-L1..CR-L5 (script-tier domain lint). The collision of "CR-L" + zero-padding is the root cause that even a careful reader hits.
