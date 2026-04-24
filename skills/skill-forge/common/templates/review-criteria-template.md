# Template: review-criteria.md — Shape Reference for Writer

This template is READ by the writer sub-agent when authoring the target skill's
`common/review-criteria.md`. It describes what a fully-filled criteria file looks like and
what each CR entry must contain.

---

## Shape Reference

```markdown
# Review Criteria — <skill-name>

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks — the prose is for human readers only. All
`conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via
CR-L04 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**.
Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

---

## Structural Criteria (Script-Type)

---

## CR-<domain>01 <slug>

<Human-readable description: one to three sentences. State the requirement, what is checked,
and why a violation matters. Do NOT include the YAML here.>

```yaml
- id: CR-<domain>01
  name: "<slug>"
  version: 1.0.0
  checker_type: script            # MUST be: script | llm | hybrid
  script_path: scripts/<name>.sh  # required for checker_type: script; omit for llm
  severity: critical              # critical | error | warning
  conflicts_with: []              # v1 default: always []
  priority: 1                     # 1=critical, 2=error, 3=warning (mirror severity)
  incremental_skip: full_scan     # full_scan | per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-<domain>10 <slug>

<Human-readable description.>

```yaml
- id: CR-<domain>10
  name: "<slug>"
  version: 1.0.0
  checker_type: llm               # no script_path for llm-type
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
```

---

## Content Requirements

Each CR entry MUST contain:

| Field | Rule |
|-------|------|
| `id` | Format `CR-<DOMAIN><NN>` where DOMAIN is a 2–4 letter code unique to the skill (e.g. `DL`, `API`, `SCH`) |
| `name` | Kebab-case slug matching the H2 heading |
| `version` | `1.0.0` for all v1 criteria |
| `checker_type` | One of `script`, `llm`, or `hybrid` — NO other values (CR-S07 hard check) |
| `severity` | One of `critical`, `error`, `warning` |
| `conflicts_with` | Always `[]` in v1 |
| `priority` | Integer mirror of severity: critical→1, error→2, warning→3 |
| `incremental_skip` | `full_scan` for structure checks; `per_file` for content checks |
| `script_path` | Required if `checker_type: script`; OMIT if `checker_type: llm` |

Draw from `clarification.yml`:
- `clarification.domain_code` → DOMAIN prefix for CR IDs
- `clarification.review_criteria[]` → list of domain-specific criteria to author
- `clarification.artifact_variant` → determines which structural checks are relevant

---

## Positive Example — decision-log skill (3 CRs)

```markdown
# Review Criteria — decision-log

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks. All `conflicts_with` fields are [] in v1.

---

## Structural Criteria (Script-Type)

---

## CR-DL01 frontmatter-completeness

Every decision file MUST have frontmatter with `decision_id`, `status`, `date`, and `deciders`
keys. A decision without these fields cannot be indexed or queried by the summarizer.

```yaml
- id: CR-DL01
  name: "frontmatter-completeness"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-DL02 rationale-non-trivial

The `Rationale` section of a decision file MUST explain WHY the chosen option was selected over
alternatives — not just restate the decision title. A trivial rationale (e.g. "we chose X because
it is better") provides no audit value.

```yaml
- id: CR-DL02
  name: "rationale-non-trivial"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-DL03 action-items-have-assignees

If a decision file has an `Action Items` section, each action item MUST have a named assignee
and a due date. Unassigned action items are never actioned, defeating the purpose of the log.

```yaml
- id: CR-DL03
  name: "action-items-have-assignees"
  version: 1.0.0
  checker_type: hybrid
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
```

---

## Negative Example — common mistakes (with CR annotations)

**Anti-pattern A — missing `severity` field** → CR-S07 fires:

```yaml
- id: CR-DL04
  name: "alternatives-listed"
  version: 1.0.0
  checker_type: llm
  # severity: MISSING — CR-S07 fires; check-criteria-yaml.sh will reject this entry
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

**Anti-pattern B — invalid `checker_type` value** → CR-S07 fires:

```yaml
- id: CR-DL05
  name: "schema-valid"
  version: 1.0.0
  checker_type: validator    # WRONG: only script | llm | hybrid are valid
  script_path: scripts/check-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

**Anti-pattern C — two CRs listing each other in `conflicts_with` with different severities** → CR-L04 fires:

```yaml
- id: CR-DL06
  name: "decision-is-final"
  checker_type: llm
  severity: critical
  conflicts_with: [CR-DL07]   # conflicts with a warning-severity criterion
  ...

- id: CR-DL07
  name: "decision-allows-revision"
  checker_type: llm
  severity: warning
  conflicts_with: [CR-DL06]   # mutual reference with mismatched severity → oscillation risk
  ...
# CR-L04 flags this pair; judge can never reach `converged` when both fire simultaneously
```

---

## How to Fill

1. Read `clarification.yml` field `domain_code` to form the CR ID prefix (e.g. `DL` for decision-log).
2. Read `clarification.review_criteria` list — each entry becomes one H2 + YAML block.
3. Separate script-type criteria into the "Structural" section and llm/hybrid into "Semantic".
4. Confirm every entry has all required fields before writing; missing `severity` causes CR-S07.
5. Keep `conflicts_with: []` for all entries in v1 — oscillation pairs are handled by CR-L04, not hard-coded here.
