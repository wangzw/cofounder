---
issue_id: R1-V-015-ADV
round: 1
file: review/adversarial-reviewer-subagent.md
criterion_id: CR-L11
severity: suggestion
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Adversarial-reviewer trigger flag is documented two different ways and may never fire in `--review` mode

## Attack angle

Mode confusion (attack vector 5). Adversarial-reviewer's trigger condition uses `state.yml adversarial_review_triggered: true`. Generate-mode has a path to set this flag (`config.yml adversarial_review.triggered_by`). `--review` mode has no documented path.

## Evidence

`review/adversarial-reviewer-subagent.md` line 102-106:
> Trigger Condition
> Dispatched by orchestrator ONLY when `config.yml adversarial_review.triggered_by` threshold is met (default: any in-generate critical or error issue). MUST check `state.yml` for the `adversarial_review_triggered: true` flag before beginning — if absent, emit a no-op ACK and return immediately (do not file false issues).

`config.yml` line 49-51:
```
adversarial_review:
  triggered_by: [critical]
  tier: heavy
```

Generate-mode flow: cross-reviewer files an issue with `severity: critical` → orchestrator sets `state.yml.adversarial_review_triggered: true` → adversarial dispatched. Plausible.

But `review/index.md` Step 4 (line 86-89):
> Dispatch **cross-reviewer** and **adversarial-reviewer** in parallel. Both perform a **forced full review** — do NOT apply any skip-set.

The `--review` mode dispatches adversarial UNCONDITIONALLY in parallel with cross. But adversarial's prompt says it MUST emit no-op ACK if `state.yml.adversarial_review_triggered` is absent. So:

- In `--review` mode, the orchestrator does NOT have a generate loop — there's no preceding cross-reviewer dispatch to trigger the flag.
- Either the orchestrator pre-sets `adversarial_review_triggered: true` for `--review` mode (undocumented), OR adversarial fires and immediately no-ops (returning empty linked_issues), so the user-facing review SUMMARY only ever has cross-reviewer findings.

Either way, the contract is unclear. If the prompt's no-op behaviour is what fires in `--review` mode, the user pays a heavy-tier dispatch cost (per `config.yml adversarial_review.tier: heavy` = opus) for no findings. That's wasted spend.

## Severity reasoning

`suggestion`: cost concern, not correctness. But the cost is non-trivial: one heavy-tier dispatch per `--review` invocation, each ~$3-4. Over many runs this compounds.

## Fix

1. In `review/index.md` Step 4, explicitly document that the orchestrator MUST set `state.yml.adversarial_review_triggered: true` before dispatching the adversarial-reviewer in `--review` mode, OR

2. In `review/adversarial-reviewer-subagent.md` line 102-106, add a "Mode-specific trigger" note:
   > In `--review` mode (read-only over an existing design), the adversarial reviewer is dispatched unconditionally. Treat the absence of `adversarial_review_triggered` as `true` when `state.yml.mode == 'review'`.

3. Replace the no-op ACK pathway with a concrete check: parse `state.yml.mode` first; if mode is `review`, fire normally; if mode is `generate-from-scratch` or `generate-new-version` and the trigger flag is not set, emit no-op ACK.

4. Add an integration test: dispatch adversarial in `--review` mode against a design known to have NFR violations; assert at least one issue is filed.
