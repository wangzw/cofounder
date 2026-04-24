# Bootstrap Test Fixture

This fixture exercises skill-forge against itself — the "Appendix B" bootstrap test from the generative-skill design guide. When skill-forge is run with this prompt as input, it should produce a target skill at `skills/skill-forge-generated/` (or similar) that matches the §7.1 directory shape and passes its own review.

## Fixture Prompt

```
/cofounder:skill-forge "I want a skill that generates generative Claude Code skills from sparse user intent. The artifact is a skill directory at skills/<name>/ following the 8-role generative-skill guide. Input is the user's description of the target skill's purpose and artifact domain. Supports 4 artifact variants: document, code, schema, hybrid. Reviews the generated skill against ~24 structural and semantic criteria."
```

## Expected Assertions

When this prompt is processed:

| Assertion | Expected |
|---|---|
| `rounds_to_convergence` | ≤ 3 (per Appendix B baseline) |
| `cost.total_usd` | ≤ $0.50 (per Appendix B baseline) |
| Verdict sequence contains | no `oscillating` / `diverging` |
| Generated tree matches | §7.1 (all required directories + subagent prompts present) |
| CR-S12 (metrics-aggregate sha) | passes on generated target |
| CR-S08 (IPC footer) | passes on all 8 subagent prompts |
| Self-review via `/cofounder:skill-forge --review --target skills/skill-forge` | returns `converged` |

## Running

```bash
# Dry-run mode (currently a stub — see tests/run-tests.sh):
./tests/run-tests.sh bootstrap
# Emits: "bootstrap harness pending (requires claude --plugin-dir)"
```

## Notes

End-to-end bootstrap validation requires the `claude --plugin-dir` harness with skill-forge installed. This is a manual validation step for v1. A later CI gate (§D.1 extension direction) would automate it.
