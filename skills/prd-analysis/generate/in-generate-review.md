# In-Generate Self-Review Checklist — prd-analysis

Referenced by `generate/writer-subagent.md`. Defines which **substantive**
CRs apply to which PRD-bundle leaf types and the PASS/FAIL format for
the writer's self-review archive.

> **Formal CRs are NOT in this table.** CR-PP01–CR-PP05, CR-PP15F
> (acceptance-criteria BDD format), and CR-FM01 (frontmatter) are
> enforced by the per-artifact `scripts/check-*.sh` for the writer's
> leaf type (see `generate/writer-subagent.md` "Formal pre-check"
> table) as a hard gate before the writer ACKs (guide §4 + §4.1).
> Failures there are auto-fixed in place by the writer without
> creating issue files. The table below covers only the substantive
> CRs the writer self-reviews after formal PASS.

---

## CR Applicability Table (substantive only)

| Leaf type | Applicable CRs |
|-----------|----------------|
| `README.md` | CR-PP06, CR-PP07, CR-PP08, CR-PP09, CR-PP10, CR-PP11, CR-PP12, CR-PP13 |
| `journeys/J-NNN.md` | CR-PP16, CR-PP21, CR-PP34, CR-PP14 |
| `features/F-NNN.md` | CR-PP07, CR-PP12, CR-PP14, CR-PP15, CR-PP17, CR-PP18, CR-PP19, CR-PP20, CR-PP24, CR-PP25, CR-PP26, CR-PP29, CR-PP31, CR-PP32, CR-PP38, CR-PP39 |
| `architecture.md` (index) | CR-PP14 |
| `architecture/design-tokens.md` | CR-PP23 |
| `architecture/coding-conventions.md` | CR-PP40 |
| `architecture/test-isolation.md` | CR-PP41 |
| `architecture/security.md` | CR-PP43 |
| `architecture/dev-workflow.md` | CR-PP42 |
| `architecture/observability.md` | CR-PP47 |
| `architecture/performance.md` | CR-PP48 |
| `architecture/navigation.md` | CR-PP33 |
| `architecture/accessibility.md` | CR-PP28 |
| `architecture/i18n.md` | CR-PP30 |
| `architecture/deployment.md` | CR-PP50 |
| `architecture/ai-agent-config.md` | CR-PP51 |
| `architecture/backward-compat.md` | CR-PP44 |
| `architecture/git-strategy.md` | CR-PP45 |
| `architecture/code-review.md` | CR-PP46 |

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
