# Review Mode (`--review`)

Review an existing design directory for quality, completeness, and consistency. **This mode is read-only** — it reports findings but does not modify any files.

## Steps

0. **Version discovery** — scan the parent directory for sibling design directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether `REVISIONS.md` in each version forms a consistent chain (each newer version links back to its predecessor). Record this context for subsequent steps.

1. **Read all files** — README.md, REVISIONS.md (if present), modules/*.md, api/*.md (if present).

2. **Run the Design Review checklist** — see `design-review-checklist.md`. Check every dimension (including Version integrity, which is in-scope for this mode), collect findings. If directory structure doesn't match template conventions, note this as a finding.

3. **Present findings.** If multiple versions were discovered in step 0, lead with a version context block before the findings table:

   ```
   Version context:
     Reviewing: {path of reviewed directory} ({position, e.g. v1 of 2})
     Latest:    {path of latest directory}
     Chain:     {whether REVISIONS.md links form a consistent chain}
     ⚠ You are reviewing an older version.       ← only if not latest
   ```

   Then present the structured table of issues with severity (Critical / Important / Suggestion). Group findings by theme (completeness, consistency, implementability, etc.) rather than listing raw checklist order. Lead with Critical issues, then Important, then Suggestions. If findings exceed 15 items, summarize low-severity items into a "Minor" group to keep the report actionable.

4. **Recommend next step:**
   - If issues are minor (wording, missing cross-links): note them for the next revision.
   - If issues are significant (missing modules, interface mismatches, coverage gaps): recommend `--revise` to address the issues.
   - If reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version.

## Key Difference vs. Self-Review

`--review` is **read-only**. The fix step from the standard self-review flow is replaced with a recommendation. To apply fixes, the user must follow up with `--revise`.
