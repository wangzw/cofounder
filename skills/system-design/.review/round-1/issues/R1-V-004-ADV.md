---
issue_id: R1-V-004-ADV
round: 1
file: common/templates/module-template.md
criterion_id: CR-L11
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Module template's API Surface columns contradict CR-L4 and the API Surface domain glossary

## Attack angle

Template-vs-criterion drift. The module template prescribes column names a writer would copy verbatim; the L4 lint script and the domain glossary mandate different names. Writers will produce files that pass the template's structure check but fail the L4 lint script under `run-checkers.sh`, generating a guaranteed false-blocker pass on every initial generation.

## Evidence

`common/templates/module-template.md` lines 193-201:
```
L4 lint (check-api-surface-cols.sh) enforces EXACTLY 7 columns per row.
Column order MUST be: Method | Path | Auth | Roles | Rate | Idempotency | Owner

| Method | Path | Auth | Roles | Rate | Idempotency | Owner |
```

`common/domain-glossary.md` line 14 (definition of "API surface"):
> Required columns (seven): `Method + Path`, `Auth & Role`, `Success`, `Error Codes`, `Request Example`, `Response Example`, `Constraints`.

`common/review-criteria.md` CR-L4 (lines 410-411):
> Every `## API Surface` table row in `modules/M-*.md` MUST fill all seven columns: Method+Path, Auth & Role, Success, Error Codes (at least one status code with error-type string, e.g. `400 invalid_request_error`), Request Example (anchor link of the form `[API-NNN](../api/API-NNN-slug.md#anchor)`), Response Example (anchor link), Constraints

Three sources of truth, two completely different schemas:

| Template | Glossary + CR-L4 |
|----------|------------------|
| Method | Method + Path (combined) |
| Path | Auth & Role |
| Auth | Success |
| Roles | Error Codes |
| Rate | Request Example |
| Idempotency | Response Example |
| Owner | Constraints |

The same disagreement exists for Boundary Enforcement: template (line 227-228) says `Operation | Authorization | Validation | Error response`; CR-L3 (lines 393-394) says `Constraint | Tool / Lint / Test | File Path | CI Job`. Glossary line 15 also says `Constraint | Tool / Lint / Test | File Path | CI Job`.

## Why this breaks production

Writers are explicitly told (writer-subagent.md line 158-160): "API Surface | 7 columns filled for every HTTP-facing endpoint: Method+Path, Auth & Role, Success, Error Codes, Request+Response example links, Constraints. Leave table absent (not empty) for non-HTTP modules."

So the writer prompt aligns with CR-L4 and glossary. But the writer is also told (line 102) to use `module-template.md` as the structural scaffold. The two instructions contradict each other. Whichever the writer follows:

- If it follows the template → the L4 script `check-api-surface-cols.sh` flags every row as missing required columns. Every module is a blocker on round 1.
- If it follows the writer prompt → the template's commentary about "L4 lint enforces EXACTLY 7 columns: Method | Path | Auth | Roles | Rate | Idempotency | Owner" is dead text inside the artifact. Worse, the X2 lint references "anchor link of the form `[API-NNN](../api/API-NNN-slug.md#anchor)`" but the template's Owner column already provides exactly that — the L4 column name is just wrong.

Either way, this is a self-inflicted divergence between the structural-lint script and the artifact template. CR-S17 (`checker-implements-declared-cr`) was supposed to catch this — but only at the script level, not at the template level.

## Fix

Pick ONE column schema and propagate to all four files. Recommendation: keep the writer-prompt + glossary + CR-L4 schema (`Method+Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints`). Rewrite `module-template.md` line 193-201 to match. Same exercise for Boundary Enforcement (template line 227-238 disagrees with CR-L3 and glossary).

Add a new structural check `scripts/check-template-vs-criteria.sh` that grep-asserts the column header rows in `common/templates/module-template.md` match the column lists in `common/review-criteria.md` CR-L3 and CR-L4. Without it this drift will recur as the template evolves.
