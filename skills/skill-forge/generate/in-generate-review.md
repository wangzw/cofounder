# In-Generate Self-Review Checklist

This file is referenced by `generate/writer-subagent.md`. It defines which CRs apply to which
file types, the PASS/FAIL format each writer must follow, the four `blocker_scope` values, and an
example complete self-review.

`in-generate-review.md` is not a sub-agent prompt. It is an instruction reference read by the
writer within its dispatch context.

---

## CR Applicability Table

| File type | Applies CRs | Severity floor |
|-----------|------------|----------------|
| `SKILL.md` | CR-S01, CR-S02, CR-S09, CR-L01, CR-L04 | critical for CR-S01/S02/S09; error for LLM |
| `*-subagent.md` (any role) | CR-S08, CR-L01, CR-L02, CR-L05 | critical for CR-S08 |
| `common/review-criteria.md` | CR-S05, CR-S07, CR-L03 | error |
| `common/config.yml` | CR-S06, CR-S11 | error |
| `common/domain-glossary.md` | CR-L06 | warning |
| Template files (`common/templates/*.md`) | CR-L02, CR-L07 | error |
| Any markdown artifact leaf | CR-L02 (self-contained), CR-L08 | error |
| Script files (`scripts/*.sh`) | CR-S13, CR-S14 | error for CR-S14 |

CRs not listed for a file type are NOT applicable and must NOT be checked. Checking inapplicable
CRs is noise and wastes reviewer bandwidth.

---

## PASS/FAIL Line Format

Each applicable CR gets exactly one line in the self-review checklist:

```
- <CR-ID> <cr-name>: PASS
- <CR-ID> <cr-name>: FAIL — blocker_scope: <value> — note: <one-sentence reason>
```

Examples:

```
- CR-S01 skill-md-frontmatter: PASS
- CR-S08 ipc-footer-present: FAIL — blocker_scope: cross-artifact-dep — note: writer-subagent.md not yet produced in this round; cannot verify footer presence
- CR-L02 self-contained-file: FAIL — blocker_scope: global-conflict — note: this file cross-references module M-003 which does not yet exist in target
```

---

## Blocker-Scope Taxonomy

Every FAIL row MUST select exactly one `blocker_scope`:

| `blocker_scope` | One-line definition |
|-----------------|---------------------|
| `global-conflict` | This leaf conflicts with another leaf or another criterion — requires cross-artifact view outside writer scope; do NOT force-fix |
| `cross-artifact-dep` | This leaf depends on a fact from another leaf not yet ready (produced) in this round |
| `needs-human-decision` | The choice requires information only a human can provide — no skill-internal evidence can resolve it |
| `input-ambiguity` | The input spec is ambiguous or incomplete; a clarification not yet covered by domain-consultant output is needed |

**Critical rule**: NEVER attempt to resolve a `global-conflict` in-place ("硬修"). Write the FAIL
row, set `self_review_status: PARTIAL` in ACK, and let the cross-reviewer + reviser loop handle it.

---

## Example: Complete Self-Review for a `*-subagent.md` file

```markdown
# Self-Review — R1-W-003

**File reviewed**: `generate/writer-subagent.md`
**Round**: 1
**Timestamp**: 2026-04-24T11:30:00Z

## Checklist

- CR-S08 ipc-footer-present: PASS
- CR-L01 orchestrator-pure-dispatch: PASS
- CR-L02 self-contained-file: PASS
- CR-L05 ack-format-correct: PASS

## Summary

**FULL_PASS**: yes
**fail_count**: 0
**Scope notes**: All applicable CRs passed. Artifact body contains no HTML-comment envelopes.
ACK format matches Snippet D specification.
```

---

## Example: Self-Review with a FAIL row

```markdown
# Self-Review — R1-W-007

**File reviewed**: `SKILL.md`
**Round**: 1
**Timestamp**: 2026-04-24T11:45:00Z

## Checklist

- CR-S01 skill-md-frontmatter: PASS
- CR-S02 mode-routing-complete: FAIL — blocker_scope: input-ambiguity — note: clarification.yml R-007 is deferred; new-version semantics row in mode routing table cannot be fully specified without it
- CR-S09 dispatch-log-snippet: PASS
- CR-L01 orchestrator-pure-dispatch: PASS
- CR-L04 model-tiers-declared: PASS

## Summary

**FULL_PASS**: no
**fail_count**: 1
**Scope notes**: CR-S02 FAIL is input-ambiguity on R-007 (new-version mode row). Cross-reviewer
should verify whether deferred R-007 materially affects mode routing completeness or if the
default new-version row is sufficient.
```
