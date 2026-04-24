# Domain Glossary

This glossary drives automated disambiguation in `glossary-probe.sh`. The script greps each term and its aliases against `input.md`; on a hit it writes `trigger-flags.yml` with `glossary_hit: true`, which causes the orchestrator to invoke the domain-consultant before proceeding to the planner. New terms are added here as the skill matures and new ambiguity patterns are observed in production inputs.

All entries carry `disambiguation_required: true`. Terms are grouped by the ambiguity cluster — one H2 per cluster.

---

## `generative skill` vs `workflow skill`

**Why disambiguate.** Users often say "skill" loosely. Generative skills produce artifacts from sparse input (PRD, design, wiki); workflow skills orchestrate deterministic steps (lint, deploy, release). These map to entirely different scaffolds — getting this wrong at Round 0 propagates to every writer downstream and requires a full restart.

```yaml
- term: "generative skill"
  aliases: ["生成式 skill", "content-generating skill", "artifact skill", "generative workflow"]
  disambiguation_required: true
  definition: "Produces artifacts from sparse user input (e.g. PRD, design, wiki page). Uses the 8-role pattern (orchestrator + 7 subagents) with iterative review/revise rounds. See guide §1."

- term: "workflow skill"
  aliases: ["workflow", "工作流 skill", "procedural skill", "deterministic skill", "scripted skill"]
  disambiguation_required: true
  definition: "Orchestrates deterministic steps; no generation or quality judgment involved. Does not use the review/revise round loop. Examples: lint, deploy, release-tag."
```

---

## `delivery` vs `version` vs `semver` vs `release`

**Why disambiguate.** The guide uses the term "delivery" for the monotonic integer counter that increments on each accepted convergence. Users colloquially say "v1", "version 2", "release", or "bump" — none of these are synonyms in this system. Confusing delivery with semantic versioning causes incorrect tag generation and broken regression history.

```yaml
- term: "delivery"
  aliases: ["semantic version", "semver", "release", "release v2", "release v3", "major version", "minor version", "v1", "bump version", "version bump", "bump major", "bump minor", "版本", "发布"]
  disambiguation_required: true
  definition: "In this skill system, 'delivery' is a monotonic integer counter (D001, D002, ...) that increments each time the convergence judge emits 'converged' and the artifact is committed. It is NOT semantic versioning. Users who say 'v1' or 'release' mean delivery in this context."
```

---

## `cross-reviewer` vs `adversarial-reviewer`

**Why disambiguate.** These two names refer to the same reviewer role variant but have been used inconsistently in different versions of the guide. Using the wrong name in a prompt file causes the orchestrator's role-dispatch table to miss the adversarial path, silently skipping adversarial review for critical-severity issues.

```yaml
- term: "adversarial reviewer"
  aliases: ["cross-reviewer", "adversarial-reviewer", "cross reviewer", "devil's advocate reviewer", "red-team reviewer", "对抗评审", "交叉评审"]
  disambiguation_required: true
  definition: "The reviewer role variant triggered when any issue has severity=critical. Configured via config.yml adversarial_review.triggered_by. The canonical name is 'adversarial reviewer'; 'cross-reviewer' is a deprecated alias from earlier guide versions."
```

---

## `artifact` vs `output` vs `制品`

**Why disambiguate.** "Output" is too generic — it could mean a script's stdout, a single file, or the entire artifact directory tree. In this skill system, "artifact" always refers to the concrete directory structure under `docs/raw/` (or equivalent), including the pyramid index. Pinning users to this definition prevents confusion when they ask "where is the output?" or try to point the next skill at the wrong path.

```yaml
- term: "artifact"
  aliases: ["output", "制品", "生成物", "result", "deliverable", "generated output", "artifact directory"]
  disambiguation_required: true
  definition: "The concrete multi-file directory tree produced by a generative skill run. Always structured as a pyramid: README.md index + subdirectories (journeys/, features/, modules/, etc.). Lives under docs/raw/{skill}/{date-slug}/. A single file is NOT an artifact — it is a leaf."
```

---

## `leaf` vs `leaf file` vs `叶子`

**Why disambiguate.** The guide uses "leaf" to mean a single bounded file at the bottom of the artifact pyramid (e.g., `features/F-001-auth.md`). Users may say "leaf" to mean any small file, or use 叶子 without knowing the 300-line size constraint. Misidentifying a non-leaf as a leaf causes the artifact-pyramid checker to produce false negatives.

```yaml
- term: "leaf"
  aliases: ["leaf file", "叶子", "叶子文件", "leaf node", "atomic file", "single spec file"]
  disambiguation_required: true
  definition: "A single file at the bottom of the artifact pyramid that represents one bounded unit (one feature, one module, one journey). MUST be self-contained and MUST NOT exceed 300 lines. The README.md index is NOT a leaf — it is the pyramid root."
```

---

## `sub-agent` vs `role` vs `agent`

**Why disambiguate.** "Agent" is overloaded — it can mean the Claude Code agent running the skill, a sub-agent spawned via Task tool, or a conceptual role in the round loop. In this skill system, "sub-agent" specifically means a Claude Code sub-session spawned by the orchestrator via the Task tool to execute one role's work. "Role" means the logical function (writer, reviewer, etc.) which maps 1:1 to a sub-agent prompt file.

```yaml
- term: "sub-agent"
  aliases: ["subagent", "agent", "sub agent", "worker agent", "role agent", "子 agent", "子agent", "子代理"]
  disambiguation_required: true
  definition: "A Claude Code sub-session spawned by the orchestrator via the Task tool to execute exactly one role's work in a round. Each sub-agent reads its prompt file, performs its work, writes output to a final path, and returns exactly one ACK line."

- term: "role"
  aliases: ["agent role", "worker role", "round role", "角色"]
  disambiguation_required: true
  definition: "The logical function assigned to a sub-agent: orchestrator, domain_consultant, planner, writer, reviewer, reviser, summarizer, or judge. Each role has a dedicated prompt file and tool_permissions entry in config.yml."
```

---

## `checker_type: script` vs `checker_type: llm` vs `checker_type: hybrid`

**Why disambiguate.** Choosing the wrong checker_type has downstream consequences: script-type criteria run in the reviewer's shell execution context (fast, deterministic); llm-type criteria are evaluated by the LLM reviewer (slower, handles semantics); hybrid runs both. Misclassifying a structural rule as llm-type makes it unreliable; misclassifying a semantic rule as script-type makes it unenforceable.

```yaml
- term: "checker_type: script"
  aliases: ["script checker", "shell checker", "automated checker", "deterministic checker", "脚本检查"]
  disambiguation_required: true
  definition: "A review criterion enforced by a shell script in scripts/. Suitable for structural, syntactic, and presence/absence checks that have deterministic pass/fail outcomes. Must have a script_path field pointing to an executable script."

- term: "checker_type: llm"
  aliases: ["llm checker", "semantic checker", "AI checker", "language model checker", "LLM 检查", "语义检查"]
  disambiguation_required: true
  definition: "A review criterion evaluated by the LLM reviewer sub-agent. Suitable for semantic, stylistic, and intent-level checks that cannot be mechanically scripted. Does NOT have a script_path field."

- term: "checker_type: hybrid"
  aliases: ["hybrid checker", "combined checker", "mixed checker", "混合检查"]
  disambiguation_required: true
  definition: "A review criterion that runs a script check first (for fast structural validation) and then an LLM check (for semantic nuance). Must have both a script_path and LLM evaluation instructions. Use sparingly — only when neither script nor LLM alone is sufficient."
```
