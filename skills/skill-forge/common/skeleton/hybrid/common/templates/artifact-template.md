# Artifact Template — {{SKILL_NAME}} (hybrid variant)

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file defines the canonical structure for hybrid artifacts produced by {{SKILL_NAME}}. Hybrid artifacts mix multiple file types (documentation, code, schemas) in a single skill output.

## Artifact Structure (hybrid variant)

A hybrid artifact set typically includes:
- **Documentation files** (`.md`): human-readable specifications, usage guides, architecture notes
- **Code files** (`.py`, `.ts`, `.go`, etc.): implementation, utilities, tests
- **Schema files** (`.json`, `.yaml`): data contracts, API definitions, config schemas

<!-- Writer: describe the full set of output files this skill produces and their types -->

## File-Type Routing

Each file type uses different checkers in `run-checkers.sh`. Specify here which file extensions map to which checker profiles:

| Extension | Checker profile |
|-----------|----------------|
| `.md` | document |
| `.py` / `.ts` | code |
| `.json` / `.yaml` | schema |

<!-- Writer: fill in the file-extension to checker-profile mapping for this skill's outputs -->

## Cross-File Consistency Requirements

<!-- Writer: describe consistency invariants that span multiple files (e.g., "every function in code/ must have a corresponding entry in docs/") -->

## Example

<!-- Writer: provide a minimal valid hybrid artifact set conforming to this template -->
