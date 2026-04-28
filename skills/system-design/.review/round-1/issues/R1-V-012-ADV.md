---
issue_id: R1-V-012-ADV
round: 1
file: common/domain-glossary.md
criterion_id: CR-L11
severity: suggestion
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Glossary missing key disambiguators: "module" vs "service", "API surface" vs "API contract", "Mode" overload

## Attack angle

Glossary ambiguity (attack vector 11). Several domain terms are used inconsistently across the prompt files; the glossary has aliases for most but not for the worst offenders.

## Evidence

`common/domain-glossary.md` defines `module` (line 13) with aliases `unit, service, component`. But the codebase uses these "aliases" as DIFFERENT concepts:

- "module" = a design unit producing one `modules/M-NNN-{slug}.md` file (correct per glossary).
- "service" = the writer-template (line 135) prescribes `interface {{ModuleName}}Service { ... }` — i.e. a Go-style "service" is the implementation OBJECT, not the design unit. A reader unfamiliar with the convention will conflate.
- "component" = the UI Architecture section (template line 416) uses "component" for React/Vue UI components — entirely different from a design module.

The glossary's `aliases: unit, service, component` is structurally wrong — these are NOT aliases for `module`. They are sibling concepts that happen to share words.

Other ambiguities:

1. **API surface vs API contract**:
   - "API surface" (glossary line 14) = the per-module table.
   - "API contract" (glossary line 27) = the file at `api/API-NNN-{slug}.md`.
   These are two different artifacts but the writer prompt and templates use both terms interchangeably (e.g. writer-subagent.md line 211 "API Contract" heading; line 158 "API Surface" table; line 217 "Owning module's API Surface table"; line 218 "owning api/API-NNN-*.md"). A naive reader cannot tell which is which.

2. **Mode**:
   - SKILL.md `Mode Routing` enumerates skill execution modes (generate, --review, --revise, --diagnose).
   - `module-template.md` UI Architecture's State Management section uses "Mode" for UI states (e.g. "edit mode" / "view mode").
   - `cross-reviewer-subagent.md` line 192-195 distinguishes "--review mode (end-user)" vs "generate-mode internal review" — the lowercase form.
   - Glossary line 26 defines "Mode" as skill execution mode but does not address the overload.

3. **Interface**:
   - Module template has a `## Interfaces` section (function signatures) and the README has an `## Interaction Protocols` table (cross-module deps).
   - "Interface Definition" appears in cross-reviewer-subagent.md line 244 as a normative section name.
   - Domain-glossary entry for `Module Interaction Protocols` (line 25) does not connect back to the module's `## Interfaces` section. A coding agent reading the glossary cannot tell if a module's "interface" is the public function signature OR the protocol row in README.

## Severity reasoning

`suggestion`: not a hard breakage. Domain terms drift over time and ambiguities surface as cross-reviewer false positives or false negatives. CR-L11 catches the worst cases but glossary is the canonical source of truth — fixing it has high leverage.

## Fix

1. Remove `service, component` from the `module` aliases. Add explicit cross-references:

   ```
   | `module` | A bounded unit of system design ... | unit |
   ```

   Add a new term `service interface (impl noun)` cross-referencing module:

   ```
   | `service interface` | The TypeScript/Go interface a module exposes — the implementation noun. Distinct from `module` (the design unit). A module may expose 0..N service interfaces. |  |
   ```

2. Disambiguate API:

   - Rename `API surface` → `API Surface (module table)` in glossary.
   - Add explicit "Distinct from `API contract file` (`api/API-*.md` standalone spec)" in both definitions.

3. Disambiguate Mode:

   - In glossary `Mode` definition, add: "Distinct from UI-level 'mode' (e.g. 'edit mode' / 'view mode' inside a frontend module's State Management section). When ambiguous, prefer `skill mode` for execution mode and `UI mode` for view-state."

4. Add new glossary row for `Interface`:

   ```
   | `Interface` | Polysemous: (1) a module's `## Interfaces` section listing public function signatures, (2) a row in README's `## Module Interaction Protocols` table describing cross-module call contracts. (1) is owned by the module file; (2) is owned by README. |
   ```

Adversarial scan estimate: at least 30 cross-reviewer findings on existing skills will resolve as glossary disambiguations rather than real CR-D02 inconsistencies. Cleaning this up reduces revise-loop noise.
