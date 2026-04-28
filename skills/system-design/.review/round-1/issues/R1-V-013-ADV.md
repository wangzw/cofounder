---
issue_id: R1-V-013-ADV
round: 1
file: scripts/run-checkers.sh
criterion_id: CR-L11
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Lint script JSON output emission is not specified per §12.4 — empty findings, special chars, exit codes are all unverified

## Attack angle

Test gaps + JSON-edge-case correctness (attack vector 9). SKILL.md §12.4 alludes to "13 lint scripts now emit JSON to stdout" but the contract is undocumented in this skill, and the actual scripts have not been verified to emit valid JSON in edge cases.

## Evidence

`SKILL.md` Configuration & Subagent Files section (lines 314-329) lists 13 lint scripts with one-line descriptions. None of the descriptions states the output schema.

`scripts/run-checkers.sh` lines 1-14:
- "Writes: manifest.yml, depgraph.yml, skip-set.yml, issues/round-checker-output.json"
- "Exit: 0=no critical/error issues, 1=has critical/error issues, 2=script error"

So `round-checker-output.json` is presumably the aggregate. But:

- Per `ls .review/round-1/issues/`: only `round-checker-output.json` exists (size 2 bytes — `[]` or `{}` likely). No per-issue files.
- The reviser pipeline expects `LINT-NNN.md` files (per `revise/index.md` Step 2). But `run-checkers.sh` writes a JSON aggregate, not per-issue Markdown files.

This contradicts:

1. `from-scratch.md` Step 9 (line 173): "Outputs: issue files under `<target>/.review/round-1/issues/` (one file per blocker finding; severity: `blocker` | `warning`)" — expects per-issue files.

2. `revise/index.md` Step 2 (line 27): "Collect all `LINT-*.md` files that do NOT end in `.applied.md`" — expects `.reviews/LINT-*.md` files.

3. `run-checkers.sh` actually emits one JSON file (per the header comment).

There is no script in `scripts/` that converts `round-checker-output.json` → per-issue `LINT-NNN.md` files. The connection is broken.

JSON edge cases the prompts do not address:

- **Empty findings**: when `run-checkers.sh` finds zero issues, does it emit `[]`, `{}`, or `{"issues": []}`? The current 2-byte file (`[]\n` or similar) suggests bare list. The reviser pipeline's "no LINT-*.md files = no issues" check would silently pass even if the JSON had `{"issues": []}` (different schema, same outcome).
- **Special chars in paths**: a finding referencing a file with a `"` or `\` in its name produces invalid JSON unless escaped. Scripts using shell heredocs typically don't escape.
- **Mixed encoding**: if any artifact file has non-UTF-8 bytes (e.g. accidentally pasted Windows-1252), grep + JSON emission may produce invalid output.

## Severity reasoning

`important`: the bridge between structural-lint and the rest of the pipeline is missing. Generate-mode Step 9 expects per-issue files; run-checkers produces aggregate JSON. Either the from-scratch text is wrong, or the script's contract is wrong, or there's a missing converter script.

## Fix

1. Decide ONE output convention for `run-checkers.sh`:
   - **Option A**: per-issue `LINT-NNN.md` files written directly to `<target>/.review/round-<N>/issues/` (or `<target>/.reviews/`). Aggregate JSON at `round-checker-output.json` for machine consumption only.
   - **Option B**: aggregate-only JSON; add a converter `scripts/json-to-lint-md.sh` that the orchestrator runs after `run-checkers.sh`.

2. Document the JSON schema in SKILL.md (or a new `scripts/lib/JSON-SCHEMA.md`):

   ```yaml
   schema:
     issues:
       - check_script: string
         criterion_id: string  # e.g. "CR-L4"
         severity: blocker | error | warning
         file: string
         line: int | null
         message: string
         suggested_fix: string | null
   ```

3. Add a JSON-validation step to `run-checkers.sh`: after each per-script output is appended, validate via `python3 -c 'import json,sys; json.load(open(sys.argv[1]))'`. If invalid, exit 2 with a clear error.

4. Add a unit test (or test-vector file) `tests/run-checkers/empty-design.json` that asserts the JSON shape on a known-empty input. Ditto for one-issue and many-issues fixtures.

Without a defined contract and tests, every downstream consumer (revisers, summarizer, judge) is reading the script output speculatively.
