---
issue_id: R1-V-008-ADV
round: 1
file: common/templates/module-template.md
criterion_id: CR-D04
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Module template's data-model `{{placeholder}}` blocks land directly inside fenced JSON/code — L2 lint will fire on every freshly-written module

## Attack angle

Prompt-injection / placeholder leakage (attack vector 1 + idempotency vector 10). The module template embeds Mustache-style `{{...}}` placeholders inside fenced ```typescript and ```mermaid blocks. The L2 lint (CR-L2 placeholder-json) and the writer prompt's negative example specifically flag `{...}`-style placeholders inside fenced blocks. A writer that follows the template literally (which `writer-subagent.md` line 102 commands: "use as structural scaffold") and forgets to substitute every placeholder will ship a file that fails L2 → blocker on every initial generation.

## Evidence

`common/templates/module-template.md`:

- Lines 90-103 (typescript block):
  ```typescript
  export interface {{EntityName}} {
    id: string;              // format: "{{prefix}}_" + ULID, e.g. "{{prefix}}_01ARZ3NDEKTSV4RRFFQ69G5FAV"
    {{fieldName}}: {{FieldType}};
    ...
  }
  ```

- Lines 132-165 (typescript block) — same pattern, dozens of `{{...}}` tokens inside fenced code.

- Lines 200-202 (markdown table inside body):
  ```
  | `{{METHOD}}` | `{{/v1/resource/:id}}` | `{{header name or "bearer JWT" or "x-api-key"}}` ...
  ```

`common/review-criteria.md` CR-L2 (line 377):
> Placeholder tokens — `"..."`, `/* ... */`, `// ...`, a body that is literally `{}`, `"<placeholder>"`, `"TBD"`, `"TODO"`, `"snapshot of above"`, or `"items": [...]` as the sole content — MUST NOT appear inside any fenced code block belonging to a Request example or Response example in `api/API-*.md` or `modules/M-*.md`.

CR-L2 specifically scopes to "Request example or Response example" so it does NOT actually fire on the typescript blocks inside Data Models or Interfaces — but the writer prompt (writer-subagent.md line 230) generalizes:

> **L2 lint (FORBIDDEN inside ```json blocks):** `...`, `TODO`, `FIXME`, `<field>`, `<...>`. Use realistic example values — not placeholders.

If the L2 script enforces the writer-prompt scope (`<...>`, `TODO`, etc. anywhere in fenced JSON), a residual `{{prefix}}` after partial substitution still passes (Mustache `{{...}}` is not in the blocked-token list). But:

- Mustache placeholders in API contract examples (api-template.md, e.g. line 53 `| {{X-Custom-Header}} | {{Y\|N}}`) are inside table cells which are NOT fenced; safe.
- HOWEVER — if a writer does not re-flow the template's typescript signature into actual TypeScript with real type names, the resulting module file's Interface section is unimplementable: `{{ParamType}}: {{FieldType}}` is gibberish to a coding agent. CR-D04 (Implementability — TBD/TODO in normative sections) fires `error`.

## Adversarial angle

The cross-reviewer's CR-D04 sweep would catch un-substituted `{{...}}` tokens IF the reviewer reads typescript blocks as "normative sections". The current cross-reviewer prompt (lines 244-248) only enumerates "Interface Definition, Boundary Enforcement, NFR section, Module Interaction Protocols" as normative scope. **Data Models** is not listed. So a writer that leaves `{{EntityName}}` in the Data Models section silently passes both L2 (out of scope) and CR-D04 (out of scope). Coding agents downstream consume garbage.

## Severity reasoning

`important`: the production design will look plausible structurally, but contain unrealizable type signatures. Coding agents will either (a) treat `{{prefix}}` as a literal string and write code that compiles but is wrong, or (b) silently fail to compile. Either way the breakage is N steps downstream from the cause.

## Fix

1. Replace `{{...}}` placeholders in `module-template.md` fenced code blocks with realistic example values (Task entity, User entity, etc.) and add an inline comment "REPLACE this entire block with your module's real types — do not keep the example." Same pass for `api-template.md` JSON examples.

2. Expand CR-D04's scope in `cross-reviewer-subagent.md` (line 244) to include "Data Models" and "Architecture Position" alongside the current four sections.

3. Add a new structural lint `scripts/check-mustache-placeholders.sh`: grep for `{{[A-Za-z_].*}}` in `modules/M-*.md` and `api/API-*.md`. Any hit = blocker. Wire into `run-checkers.sh` and add a corresponding CR-L6 entry. This is the proper structural countermeasure.

4. Add to writer-subagent.md a "Pre-write checklist": "Before issuing the first Write call, grep your draft for `{{` and `}}`. If any remain, you have un-substituted template placeholders. Fix before calling Write."
