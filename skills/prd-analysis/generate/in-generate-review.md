# In-Generate Self-Review Checklist — prd-analysis

This file is referenced by `generate/writer-subagent.md`. It defines which CRs apply to which
PRD artifact file types, the PASS/FAIL format each writer must follow, the four `blocker_scope`
values, and an example complete self-review.

`in-generate-review.md` is not a sub-agent prompt. It is an instruction reference read by the
writer within its dispatch context. After producing each leaf file, the writer runs this checklist
immediately and reports PASS/FAIL per applicable CR. For every FAIL row the writer MUST select
exactly one `blocker_scope` value and provide a one-sentence note. CRs not listed for a file type
are NOT applicable and must NOT be checked — checking inapplicable CRs is noise that wastes
reviewer bandwidth.

---

## CR Applicability Table

| File type | Applicable CRs | Severity floor |
|-----------|---------------|----------------|
| `README.md` | CR-PRD-S01 (frontmatter), CR-PRD-S05 (index consistency), CR-PRD-L06 (cross-journey patterns) | error for S01/S05; warning for L06 |
| `journeys/J-NNN-<slug>.md` | CR-PRD-S03 (J-NNN ID), CR-PRD-S08 (≤300 lines), CR-PRD-L02 (mapped-feature backref) | error for S03/L02; warning for S08 |
| `features/F-NNN-<slug>.md` | CR-PRD-S02 (F-NNN ID), CR-PRD-L01 (self-contained), CR-PRD-S06 (wikilink targets exist), CR-PRD-S08 (≤300 lines), CR-PRD-L02 (journey backref), CR-PRD-L03 (MVP discipline), CR-PRD-L04 (boundaries clear) | error for S02/L01/S06/L02/L03/L04; warning for S08 |
| `architecture.md` | CR-PRD-S05 (index matches topic files) | error |
| `architecture/<topic>.md` | CR-PRD-L05 (NFR covers perf/security/a11y), CR-PRD-S06 (wikilink targets exist) | error |
| `REVISIONS.md` | CR-PRD-S07 (revision log consistency) — only if file exists | warning |
| `prototypes/` | _(no applicable CRs — optional artifacts)_ | — |

---

## PASS/FAIL Line Format

Each applicable CR gets exactly one line in the self-review checklist:

```
- <CR-ID> <cr-name>: PASS
- <CR-ID> <cr-name>: FAIL — blocker_scope: <value> — note: <one-sentence reason>
```

Examples:

```
- CR-PRD-S02 features-have-ids: PASS
- CR-PRD-L01 feature-files-self-contained: FAIL — blocker_scope: cross-artifact-dep — note: data model referenced in F-003 not yet inlined here, requires cross-reviewer to verify
- CR-PRD-L03 mvp-discipline: FAIL — blocker_scope: needs-human-decision — note: section "Future Ideas" in feature body may be in-scope or out-of-scope depending on stakeholder decision not recorded in clarification.yml
```

---

## Blocker-Scope Taxonomy

Every FAIL row MUST select exactly one `blocker_scope`:

| `blocker_scope` | One-line definition |
|-----------------|---------------------|
| `global-conflict` | This leaf conflicts with another leaf or another criterion — requires a cross-artifact view outside writer scope; do NOT force-fix in-place |
| `cross-artifact-dep` | This leaf depends on a fact from another leaf not yet produced in this round — the dependency will be resolved once the other writer completes |
| `needs-human-decision` | The choice requires information only a human stakeholder can provide — no skill-internal evidence can resolve it |
| `input-ambiguity` | The input spec is ambiguous or incomplete; a clarification not yet covered by domain-consultant output is needed |

**Critical rule**: NEVER attempt to resolve a `global-conflict` in-place ("硬修"). Write the FAIL
row, set `self_review_status: PARTIAL` in the ACK, and let the cross-reviewer + reviser loop handle it.

---

## Example: Complete Self-Review for a `features/F-001-auth.md` Leaf

```markdown
# Self-Review — R1-W-005

**File reviewed**: `features/F-001-auth.md`
**Round**: 1
**Timestamp**: 2026-04-24T12:00:00Z

## Checklist

- CR-PRD-S02 features-have-ids: PASS
- CR-PRD-L01 feature-files-self-contained: PASS
- CR-PRD-S06 wikilink-targets-exist: PASS
- CR-PRD-S08 leaf-size-within-limit: PASS
- CR-PRD-L02 feature-to-journey-mapping: PASS
- CR-PRD-L03 mvp-discipline: PASS
- CR-PRD-L04 feature-boundaries-clear: FAIL — blocker_scope: global-conflict — note: F-001 and F-002 both describe session token management; boundary overlap requires cross-reviewer to adjudicate which feature owns the behavior

## Summary

**FULL_PASS**: no
**fail_count**: 1
**Scope notes**: CR-PRD-L04 FAIL is a global-conflict between F-001 and F-002. Writer did not
force-fix. Cross-reviewer should compare both feature files and determine which one exclusively
owns session token management, then file a reviser issue for the other to remove the overlapping
section.
```

