# In-Generate Self-Review Checklist — system-design

Referenced by `generate/writer-subagent.md`. Defines which **substantive**
CRs apply to which design-bundle leaf types and the PASS/FAIL format for
the writer's self-review archive.

> **Formal CRs are NOT in this table.** CR-SD01..CR-SD19 and
> CR-SDFM01..CR-SDFM03 are enforced by the per-artifact
> `scripts/check-*.sh` for the writer's leaf type (see
> `generate/writer-subagent.md` "Formal pre-check" table) as a hard
> gate before the writer ACKs (guide §4 + §4.1). Failures there are
> auto-fixed in place by the writer without creating issue files. The
> table below covers only the substantive CRs the writer self-reviews
> after formal PASS.

---

## CR Applicability Table (substantive only)

| Leaf type | Applicable CRs |
|-----------|----------------|
| `README.md` | CR-SD-DESIGN02, CR-SD-DESIGN05, CR-SD-DESIGN07 |
| `modules/M-NNN-*.md` | CR-SD-DESIGN01, CR-SD-DESIGN02, CR-SD-DESIGN03, CR-SD-DESIGN04, CR-SD-DESIGN06, CR-SD-DESIGN07, CR-SD-DESIGN08 |
| `api/API-NNN-*.md` | CR-SD-DESIGN05, CR-SD-DESIGN06, CR-SD-DESIGN08 |

Why these mappings:

- README owns the cross-module concerns: dependency-direction-rationale
  (CR-SD-DESIGN02) lives in Interaction Protocols + Module Deps narrative,
  api-versioning-strategy (CR-SD-DESIGN05) is the bundle-wide policy, and
  observability-coverage (CR-SD-DESIGN07) at the bundle level checks that
  every module's emitted metric/log/span is summarized in the analytics
  coverage section.
- Module specs own per-module substantive correctness: cohesion (DESIGN01),
  dependency-direction (DESIGN02 again, locally), boundary-justification
  (DESIGN03), data-model-normalization (DESIGN04), failure-modes (DESIGN06),
  observability (DESIGN07), security-considerations (DESIGN08).
- API specs own surface-level concerns: versioning-strategy (DESIGN05),
  failure-modes (DESIGN06), security (DESIGN08).

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
