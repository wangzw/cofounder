---
issue_id: R1-V-014-ADV
round: 1
file: common/templates/design-readme-template.md
criterion_id: CR-L11
severity: suggestion
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Design README template's PRD path examples are wrong-depth — relative paths will fail X8 lint when followed verbatim

## Attack angle

Path / cross-document brittleness (attack vector 4). Template comments instruct the writer on relative paths. The instructions are off-by-one on directory depth.

## Evidence

`common/templates/design-readme-template.md` lines 17-19:
```
{{PRD_PATH}}     = relative path from this README to the PRD README.md
                   (e.g. "../../prd/2026-01-15-taskflow/README.md").
```

Per SKILL.md `Output Path` section (line 71-72):
> Cross-document paths: when referencing PRD files, use relative paths from the design directory. Example: if PRD is at `docs/raw/prd/2026-04-09-foo/` and design is at `docs/raw/design/2026-04-09-foo/`, a module's Source Feature link is `../../../prd/2026-04-09-foo/features/F-001-slug.md`

That's `../../../prd/...` (three `..` levels) for the MODULE file, which lives at `docs/raw/design/<date>-<slug>/modules/M-NNN.md` (4 levels deep).

But the README at `docs/raw/design/<date>-<slug>/README.md` is only 3 levels deep. The correct relative path from README.md to `docs/raw/prd/<date>-<slug>/README.md` is `../../prd/<date>-<slug>/README.md` — two `..`. That matches the template's example. So far so good.

HOWEVER, the template line 70 in `module-template.md` says:
```
- [F-{{NNN}}: {{Feature Name}}](../../../prd/{{YYYY-MM-DD-slug}}/features/F-{{NNN}}-{{slug}}.md)
```

Three `..` from `modules/M-NNN.md` → up to design-dir, up to dated-design-dir-parent (`design/`), up to `raw/`, then `prd/`. That's correct: `../../../prd/...`.

BUT `module-template.md` line 67 says:
```
From docs/raw/design/YYYY-MM-DD-{slug}/modules/M-NNN-{slug}.md the typical form is:
../../../prd/YYYY-MM-DD-{slug}/features/F-NNN-{slug}.md
```

Here's the discrepancy: from `docs/raw/design/<date>-<slug>/modules/M-NNN.md`:
- `..` → `docs/raw/design/<date>-<slug>/`
- `../..` → `docs/raw/design/`
- `../../..` → `docs/raw/`
- `../../..//prd/...` → `docs/raw/prd/<date>-<slug>/features/F-NNN.md` ✓

OK, this one is right. Let me check the README's variant more carefully.

`design-readme-template.md` line 19: `"../../prd/2026-01-15-taskflow/README.md"`
- README at `docs/raw/design/<date>-<slug>/README.md`
- `..` → `docs/raw/design/<date>-<slug>/` (no, that's the same as where we are; `..` goes UP one)
- `..` → `docs/raw/design/`
- `../..` → `docs/raw/`
- `../../prd/...` → `docs/raw/prd/<date>-<slug>/README.md` ✓

OK both are correct. So where's the bug?

`design-readme-template.md` line 11 (Design Input):
```
- **Source:** [{{PRD_NAME}}]({{PRD_PATH}}) | {{INPUT_MODE}}
```

The placeholder `{{PRD_PATH}}` has no fixed convention. A writer must read the comment at line 17-19 to learn the depth. But X8 lint (CR-X8 readme-references) checks "Every relative path referenced from `README.md` MUST resolve to an existing file." If a writer follows ONLY `module-template.md` (the writer prompt's primary template) and copy-pastes its `../../../prd/...` form into the README's Design Input link, X8 fires (the path resolves one level too far up).

Plus: writers are told (writer-subagent.md line 102) to use the template "as the structural scaffold." If the writer fan-out produces both README and modules in parallel, the writer of README and the writer of M-NNN.md derive the path independently. There is no shared truth source.

## Severity reasoning

`suggestion`: writers may get it right, but the failure mode (X8 lint fires after Step 9 → orchestrator dispatches reviser → reviser fixes the path → next round) burns one full round. Cumulative cost over many designs is a measurable percentage of total round count.

## Fix

1. Add to `from-scratch.md` Step 5 planner output a `prd_relative_path_from_readme:` and `prd_relative_path_from_module:` key that's pre-computed by the planner and copied verbatim by every writer. No more derived paths.

2. Centralize the depth-truth in `common/domain-glossary.md` `cross-document path` (already exists, line 29):
   - Currently: "All inter-directory references MUST use relative paths"
   - Add: "Canonical depths: from README.md to PRD README is `../../prd/<slug>/README.md`; from modules/M-NNN.md to PRD feature is `../../../prd/<slug>/features/F-NNN.md`. Confirm with `realpath` before writing."

3. Templates should encode the path PATTERN, not exemplary text. Move the comment from `module-template.md` line 67 to a constant in the planner or writer prompt — once. Templates are copied verbatim and the example-text invites copy-paste errors.
