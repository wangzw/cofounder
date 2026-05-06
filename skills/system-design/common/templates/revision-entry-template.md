# REVISIONS.md — Append-Entry Template

This file defines the format for entries appended to `REVISIONS.md` by the `--revise` mode summarizer.

## REVISIONS.md Conventions

- **Append-only.** Never edit or delete a prior entry. Each entry is a permanent, immutable record of a completed revision cycle.
- **One entry per `--revise` invocation.** Even when a single invocation processes multiple issues (REVIEW-*.md + LINT-*.md together), it produces exactly one REVISIONS.md entry.
- **Created on first revision.** `REVISIONS.md` does not exist in a freshly generated design directory. The `--revise` summarizer creates it when writing the first entry.
- **README links to REVISIONS.md once it exists.** After the first entry is written, the README.md References section MUST include a link to `REVISIONS.md`. This link is added by the `--revise` summarizer alongside the entry write and is never removed.
- **New-version designs inherit the file.** When `--revise` creates a new dated directory, it copies `REVISIONS.md` from the source directory (if present) before appending the new entry — so the full revision lineage travels with the design.

---

## Entry Format

Append the following block verbatim (replacing `{{PLACEHOLDER}}` values) as the next entry in `REVISIONS.md`. Entries are separated by a horizontal rule (`---`).

```markdown
## REV-{{REV_ID}} — {{DATE}}

| Field | Value |
|-------|-------|
| **Revision ID** | REV-{{REV_ID}} |
| **Date** | {{DATE}} |
| **Triggered by** | {{TRIGGERED_BY}} |
| **Change type** | {{CHANGE_TYPE}} |
| **Status** | {{STATUS}} |

### Modules Touched

{{MODULES_TOUCHED}}

### API Contracts Touched

{{API_CONTRACTS_TOUCHED}}

### Summary

{{SUMMARY}}

### Verification

{{VERIFICATION}}
```

---

## Placeholder Reference

| Placeholder | Format | Description |
|-------------|--------|-------------|
| `{{REV_ID}}` | `NNN` (zero-padded, e.g. `001`) | Sequential revision counter within this design directory. Start at `001`; increment by 1 for each new entry. |
| `{{DATE}}` | `YYYY-MM-DD` | Calendar date the `--revise` invocation completed (UTC). |
| `{{TRIGGERED_BY}}` | Comma-separated issue IDs, e.g. `I-007, I-014` | The `I-NNN` issue IDs (per `common/issue-schema.md`, format `I-\d{3,}`) from `.review/round-<N>/issues/` consumed by this revise pass. Use bare IDs (no path or extension). If no review issues were consumed (interactive-only pass), write `interactive`. |
| `{{CHANGE_TYPE}}` | `In-place edit` \| `New version` | `In-place edit` when changes were applied directly to the existing design directory. `New version` when a new dated directory was created. |
| `{{STATUS}}` | `Applied` \| `Reverted` | `Applied` once all edits are committed and lint is clean. `Reverted` if the revision was rolled back (rare; document the reason in Summary). |
| `{{MODULES_TOUCHED}}` | Bulleted list of `M-NNN-{slug}` IDs, one per line. Write `_None_` if no module files were changed. | All module files (`modules/M-*.md`) modified during this revision cycle. |
| `{{API_CONTRACTS_TOUCHED}}` | Bulleted list of `API-NNN-{slug}` IDs, one per line. Write `_None_` if no API files were changed. | All API contract files (`api/API-*.md`) modified during this revision cycle. |
| `{{SUMMARY}}` | 1–3 plain-English sentences. | What changed and why. Focus on the semantic intent (e.g. "Restructured M-003 to extract caching responsibility into M-007 to reduce coupling with M-004"). Avoid repeating the placeholder IDs already listed above. |
| `{{VERIFICATION}}` | Structured as shown in the example below. | Lint gate outcome + cross-reviewer status (if applicable). |

### Verification block format

```
Lint gate: PASS (0 failures) | FAIL (N failures — not committed)
Cross-reviewer status: Addressed N/N open findings from {{TRIGGERED_BY}} | N/A (no review file consumed)
```

When `Status` is `Applied`, lint gate MUST show `PASS`. A revision that ends with lint failures MUST NOT be committed and MUST set `Status` to `Reverted` with an explanation in Summary.

---

## Example Entry

```markdown
## REV-002 — 2026-05-14

| Field | Value |
|-------|-------|
| **Revision ID** | REV-002 |
| **Date** | 2026-05-14 |
| **Triggered by** | I-007, I-014 |
| **Change type** | In-place edit |
| **Status** | Applied |

### Modules Touched

- M-003-cache-manager
- M-004-api-gateway
- M-007-session-store

### API Contracts Touched

- API-002-auth-token

### Summary

Extracted cache invalidation logic from M-004 into a new M-007 module to eliminate the circular dependency flagged in `I-014`. Updated API-002's response schema to include a `cache_hit` boolean field per `I-007` L2 finding (placeholder JSON removed from example block).

### Verification

Lint gate: PASS (0 failures)
Cross-reviewer status: Addressed 4/4 open findings from I-007, I-014, I-019, I-023
```
