---
issue_id: R1-V-001-ADV
round: 1
file: generate/from-scratch.md
criterion_id: CR-L11
severity: blocker
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# scaffold.sh hard-fails in FromScratch Step 7 — wrong skeleton, wrong target

## Attack angle

Path / cross-document brittleness — orchestrator calls a script whose contract does not match what the mode requires. The skill cannot reach Step 8 (writer fan-out) under any input.

## Evidence

`generate/from-scratch.md` Step 7 (lines 126-135):

```
scripts/scaffold.sh <target>/ <target>/.review/round-0/clarification/<ts>.yml
```

`scripts/scaffold.sh` is skill-forge's skill-skeleton scaffolder. Its own help text and code:

- Line 27: `The skeleton lives at <generator-skill-root>/common/skeleton/document/`
- Line 50: `SKELETON_DIR="${SKILL_FORGE_DIR}/common/skeleton/document"`

That skeleton produces a Claude Code SKILL — `SKILL.md`, `generate/`, `review/`, `revise/`, `shared/`, `scripts/`. It does NOT produce a system-design artifact bundle (`README.md`, `modules/M-NNN-{slug}.md`, `api/API-NNN-{slug}.md`). Two independent failures follow:

1. **Wrong content target.** Even if the script runs cleanly, it copies a SKILL skeleton onto `docs/raw/design/YYYY-MM-DD-{slug}/`. The user gets a fake skill in their PRD design directory, not a design bundle.

2. **Path resolution fails first.** The script computes `SKILL_FORGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"` (script's grandparent). When the script lives at `skills/system-design/scripts/scaffold.sh`, `SKILL_FORGE_DIR` resolves to `skills/system-design/` — and `skills/system-design/common/skeleton/document/` does not exist (verified by `ls common/`: `config.yml`, `domain-glossary.md`, `review-criteria.md`, `scaffold-provenance.yml`, `shared-scripts-manifest.yml`, `snippets.md`, `templates/` — no `skeleton/`). The script's own `[ ! -d "$SKELETON_DIR" ]` guard exits 2 with `ERROR: skeleton not found`.

The from-scratch sequence therefore halts at Step 7 with a hard error before any writer dispatches. There is no fallback path; the skill is unusable in FromScratch mode.

## Why adversarial flagged this (vs. cross-reviewer)

This is not a semantic-quality issue (CR-D*) — it is a structural cross-reference inconsistency between an orchestration step and a script's actual contract. CR-L11 (cross-reference-consistency) calls out exactly this pattern: "A shell script's stated contract in its header comment is contradicted by its actual execution path" / "review-criteria.md declares `script_path: scripts/X.sh` but the inventory check or scaffold doesn't list `X.sh`." Here Step 7 declares an action (`scaffold.sh <target>/ ...`) that the script's own validation rejects.

## Fix

Either:

(a) Drop Step 7 entirely. The artifact bundle is wholly produced by the writer fan-out (Step 8 writes `README.md`, every `modules/M-NNN.md`, every `api/API-NNN.md` from the templates). No pre-creation is needed; `Write` creates parent dirs.

(b) Replace `scripts/scaffold.sh` with a lightweight `scripts/init-design-dir.sh` that does only `mkdir -p <target>/{modules,api,.reviews}` and writes a `.gitignore` for `.reviews/`. The current scaffold.sh is structurally incompatible with a non-skill target.

Option (a) is preferred. It also removes the false dependency on the skill-forge skeleton invariant and makes the design output directory usable from any cwd that can run `Write`.
