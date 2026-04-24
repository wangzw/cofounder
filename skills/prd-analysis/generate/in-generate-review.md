# In-Generate Self-Review Checklist — {{SKILL_NAME}}

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

This file is referenced by `generate/writer-subagent.md`. It defines which CRs apply to which
file types and the PASS/FAIL format for writer self-reviews.

---

## CR Applicability Table

<!-- Writer: populate with the CR-to-file-type mapping for this skill's domain -->

| File type | Applies CRs | Severity floor |
|-----------|------------|----------------|
| `SKILL.md` | CR-S01, CR-S02, CR-S09, CR-L01 | critical for CR-S01/S02/S09 |
| `*-subagent.md` | CR-S08, CR-L01, CR-L02 | critical for CR-S08 |
| `common/review-criteria.md` | CR-S05, CR-L03 | error |
| `common/config.yml` | CR-S06 | error |
| Any artifact leaf | CR-L02 | error |

---

## PASS/FAIL Line Format

```
- <CR-ID> <cr-name>: PASS
- <CR-ID> <cr-name>: FAIL — blocker_scope: <value> — note: <one-sentence reason>
```

---

## Blocker-Scope Taxonomy

| `blocker_scope` | One-line definition |
|-----------------|---------------------|
| `global-conflict` | Leaf conflicts with another leaf or criterion |
| `cross-artifact-dep` | Leaf depends on a fact from another leaf not yet ready |
| `needs-human-decision` | Choice requires information only a human can provide |
| `input-ambiguity` | Input spec is ambiguous or incomplete |
