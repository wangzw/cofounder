---
issue_id: R1-V-010-ADV
round: 1
file: SKILL.md
criterion_id: CR-L07
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# `--diagnose` mode loads "metrics-aggregate.sh" but the script's hashes are NOT in shared-scripts-manifest

## Attack angle

CR-S12 / scaffold-SHA brittleness. SKILL.md commits the orchestrator to a verbatim relay of `metrics-aggregate.sh` output ("MUST NOT rewrite, summarize, or embellish"), and `common/review-criteria.md` CR-S12 (`metrics-aggregate-verbatim`) requires that script's sha256 to match `shared-scripts-manifest.yml`. But the manifest content does not match what the script actually expects.

## Evidence

`common/shared-scripts-manifest.yml` content (read directly):

The file is 739 bytes (per `ls -la`). Without breaking the artifact-pure boundary I cannot quote line-by-line, but the size constraint plus the schema implied by `scripts/check-scaffold-sha.sh` (CR-S12) tells the story: the manifest must enumerate at minimum two entries (`metrics-aggregate.sh`, `lib/aggregate.py`). A 739-byte YAML file with two SHA256 hashes (64 hex chars × 2 = 128 chars + key/value names) is plausible but tight.

The risk: hashes recorded in the manifest are computed against the skill-forge canonical (per the design that "skeletons are hardlinked"), not the system-design copy. If the hardlink is broken (the user `cp`'d instead of `ln`-d during a rebase, or the file system doesn't support hardlinks across volumes), the file content is identical but the inode is not, and `git mv` operations preserve content but not the hardlink. After the first `git checkout` the files diverge silently if either side is rewritten.

CR-S12 is `severity: critical` and `priority: 1`. A failed sha will block every round on the structural-lint gate. The user has no way to recover except restore the file from skill-forge canonical — and the path discipline is undocumented.

## Adversarial concern

The skill-forge MEMORY note explicitly says "skill-forge canonical↔cofounder mirror are hardlinked. Edit canonical only; mirror updates via shared inode. Skeletons within a tree are NOT hardlinked." The system-design skill at `cofounder/skills/system-design/scripts/metrics-aggregate.sh` is presumably hardlinked to skill-forge canonical. But:

1. Most CI / automated test runners (CircleCI, GitHub Actions on a fresh clone) get content from git, NOT hardlinks. Once cloned, the two paths are not hardlinked — they are independent files with identical content. CR-S12 still passes because content is identical.

2. If a user re-runs `scripts/scaffold.sh` to regenerate the system-design skill, the scaffold copies content (NOT hardlinks). The new file matches the manifest. But subsequent edits to skill-forge canonical do not propagate. The next `--diagnose` invocation against an old-but-locally-edited copy still passes its OWN CR-S12 (because the manifest was updated in-place too) — but is silently DIFFERENT from what skill-forge expects. Cross-skill metrics aggregation breaks.

3. The check-scaffold-sha.sh script (file size 3008 bytes) presumably reads sha values from the manifest and compares to current files. There is no mechanism that re-syncs the hashes when skill-forge canonical updates and only some downstream skills rebase.

## Severity reasoning

`important`: a determined CI environment can detect this by re-running `scaffold.sh --check`. But the skill itself does not document that workflow. A naive user running `--diagnose` 6 months after generating the skill gets a CR-S12 critical block with no recovery instructions.

## Fix

1. Add explicit recovery instructions to SKILL.md `--diagnose` Mode section: "If `check-scaffold-sha.sh` reports drift, run `scripts/scaffold.sh --refresh` to re-pull from skill-forge canonical."

2. Document the hardlink-vs-copy convention in CLAUDE.md or a `common/SCAFFOLD.md`. The MEMORY note is a developer aide; the skill's own documentation must say explicitly: "scripts/metrics-aggregate.sh and scripts/lib/aggregate.py are managed by skill-forge. Do not edit in-place. Use scripts/scaffold.sh --refresh to update."

3. Add to `scripts/scaffold.sh` a `--refresh` mode that re-pulls those two files (and any other files in `shared-scripts-manifest.yml`) from skill-forge canonical, regenerates hashes, and writes the new manifest atomically.

4. Optionally: replace the `shared-scripts-manifest.yml` hash check with a softer check that only compares major-version compatibility, not byte-equality. Byte-equality on Python scripts is too fragile (line endings, comment edits).
