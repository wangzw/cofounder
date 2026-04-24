# Bootstrap Test

The bootstrap test exercises skill-forge by using it to generate a skill that matches its own design — the strongest form of self-validation per the generative-skill design guide's Appendix B.

## V1 Status: Manual

Full end-to-end validation requires running `/cofounder:skill-forge` against the fixture at `input.md`, then asserting the generated tree matches §7.1 and passes skill-forge's own review. This requires:

- Claude Code harness with skill-forge installed as a plugin
- Live LLM dispatch (balanced + heavy tier)
- Post-run inspection of the generated tree

The golden fixture files under `expected/` will be populated after the first successful bootstrap run (via REGEN=1 on `run-tests.sh`).

## Future: Automated CI Gate

Per guide §D.1 extension direction, the bootstrap test would become a CI gate once:
- The generator is stable enough for `rounds_to_convergence ≤ 3`
- Total cost per run is tractable (< $0.50)
- Golden fixture files are stable across guide updates
