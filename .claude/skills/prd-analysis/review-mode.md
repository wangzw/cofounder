# PRD Review Mode (`--review`)

This file contains instructions for reviewing an existing PRD for quality, completeness, and consistency. This mode is read-only — it reports findings but does not modify any files.

Review Checklist dimensions are defined in `SKILL.md` — read that first.

---

0. **Version discovery** — scan the parent directory for sibling PRD directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the versions form a consistent chain. Chain links may be via Revision History (revise-mode) or Baseline.Predecessor (evolve-mode) — check both. Record this context for subsequent steps. If the reviewed PRD is an evolve-mode PRD (has Baseline section): additionally validate all `→ baseline` reference links, Change Summary accuracy, and change annotation completeness using the evolve-specific checks from the Evolve Step 4 Review Checklist.
1. **Read all files** — README.md, journeys/*.md, architecture.md, features/*.md
2. **Run Review Checklist** — check every dimension (including Version integrity), collect findings
3. **Present findings** — if multiple versions were discovered in step 0, lead with a version context block before the findings table:
   ```
   Version context:
     Reviewing: {path of reviewed directory} ({position, e.g. v1 of 2})
     Latest:    {path of latest directory}
     Chain:     {whether Revision History links form a consistent chain}
     ⚠ You are reviewing an older version.       ← only if not latest
   ```
   Then present the structured table of issues with severity (Critical / Important / Suggestion).
4. **Recommend next step:**
   - If issues are minor (wording, missing cross-links): note them for the next revision
   - If issues are significant (missing journeys, orphan features, gaps): recommend `--revise` to address the issues
   - If reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version
