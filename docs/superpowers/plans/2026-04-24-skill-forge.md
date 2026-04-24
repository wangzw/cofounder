# skill-forge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `cofounder:skill-forge`, a generative skill that generates generative skills per `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md`.

**Architecture:** 8-role generative skill (orchestrator + 7 sub-agents) with a versioned `common/skeleton/` boilerplate tree (4 artifact variants: document/code/schema/hybrid). Writers only author ~7–9 domain-specific files per target skill; `scaffold.sh` copies the rest from the variant's skeleton. Validation = 24 review criteria (14 script + 10 LLM) + Appendix-B bootstrap self-generation as CI gate.

**Tech Stack:** Bash ≥ 4.0 + Python ≥ 3.8 (std lib only; no `pyyaml`/`jq`/`slugify`), Markdown+YAML artifacts, Claude Code subagent dispatch via Task tool.

**Spec:** `docs/superpowers/specs/2026-04-24-skill-forge-design.md`

**Reference:** `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md` — sections called out per task.

---

## File Structure

All paths relative to repo root `/Users/wangzw/workspace/cofounder/`.

### Root files
- `skills/skill-forge/SKILL.md` — mode routing + core contract + orchestrator body (Snippet B + C embedded inline, per guide §21.1)

### Common
- `skills/skill-forge/common/config.yml` — §21.2 full field set
- `skills/skill-forge/common/review-criteria.md` — 24 CR entries (14 script + 10 LLM)
- `skills/skill-forge/common/domain-glossary.md` — ≥7 disambiguation_required terms
- `skills/skill-forge/common/snippets.md` — pinned Snippet C + Snippet D text (single source of truth for grep-based checks)
- `skills/skill-forge/common/skeleton/shared-scripts-manifest.yml` — sha256 pins for metrics-aggregate.sh + lib/aggregate.py
- `skills/skill-forge/common/skeleton/document/` — full §7.1 boilerplate tree for document artifacts
- `skills/skill-forge/common/skeleton/code/` — variant for source-code artifacts
- `skills/skill-forge/common/skeleton/schema/` — variant for API/schema artifacts
- `skills/skill-forge/common/skeleton/hybrid/` — variant for mixed artifacts
- `skills/skill-forge/common/templates/skill-md-template.md` — template writer writes into
- `skills/skill-forge/common/templates/review-criteria-template.md`
- `skills/skill-forge/common/templates/writer-subagent-template.md`
- `skills/skill-forge/common/templates/cross-reviewer-template.md`
- `skills/skill-forge/common/templates/artifact-template.md`

### Scripts — tier 1 (verbatim copies)
- `skills/skill-forge/scripts/metrics-aggregate.sh` — verbatim from `~/Documents/mind/raw/guide/attachments/metrics-aggregate/`
- `skills/skill-forge/scripts/lib/aggregate.py` — verbatim

### Scripts — tier 2 (standard per guide)
- `skills/skill-forge/scripts/git-precheck.sh` — §21.0 three-tool check + `git init` fallback
- `skills/skill-forge/scripts/prepare-input.sh` — §6.1 prompt expansion
- `skills/skill-forge/scripts/glossary-probe.sh` — §6.2 trigger condition 2
- `skills/skill-forge/scripts/run-checkers.sh` — §12.5 phase A + B
- `skills/skill-forge/scripts/commit-delivery.sh` — §8.3 annotated-tag commit
- `skills/skill-forge/scripts/prune-traces.sh` — §8.8 retention
- `skills/skill-forge/scripts/extract-criteria.sh` — YAML block extractor
- `skills/skill-forge/scripts/check-criteria-consistency.sh` — §13.1 self-consistency
- `skills/skill-forge/scripts/check-index-consistency.sh` — §7.5 index alignment
- `skills/skill-forge/scripts/check-changelog-consistency.sh` — §10.4 changelog ↔ versions

### Scripts — tier 3 (skill-forge-specific)
- `skills/skill-forge/scripts/scaffold.sh` — copies `common/skeleton/<variant>/` → `<target>/`
- `skills/skill-forge/scripts/check-skill-structure.sh` — CR-S03+S04
- `skills/skill-forge/scripts/check-ipc-footer.sh` — CR-S08
- `skills/skill-forge/scripts/check-dispatch-log-snippet.sh` — CR-S09
- `skills/skill-forge/scripts/check-trace-id-format.sh` — CR-S10
- `skills/skill-forge/scripts/check-config-schema.sh` — CR-S06+S11
- `skills/skill-forge/scripts/check-scaffold-sha.sh` — CR-S12
- `skills/skill-forge/scripts/check-dependencies.sh` — CR-S14
- `skills/skill-forge/scripts/build-depgraph.sh` — §8.5 depgraph for target's own leaves

### Sub-agent prompts
- `skills/skill-forge/generate/from-scratch.md`
- `skills/skill-forge/generate/new-version.md`
- `skills/skill-forge/generate/domain-consultant-subagent.md`
- `skills/skill-forge/generate/planner-subagent.md`
- `skills/skill-forge/generate/writer-subagent.md`
- `skills/skill-forge/generate/in-generate-review.md`
- `skills/skill-forge/review/index.md`
- `skills/skill-forge/review/cross-reviewer-subagent.md`
- `skills/skill-forge/review/adversarial-reviewer-subagent.md`
- `skills/skill-forge/revise/index.md`
- `skills/skill-forge/revise/per-issue-reviser-subagent.md`
- `skills/skill-forge/shared/summarizer-subagent.md`
- `skills/skill-forge/shared/judge-subagent.md`

### Tests
- `skills/skill-forge/tests/bootstrap/input.md`
- `skills/skill-forge/tests/bootstrap/expected/directory-manifest.txt`
- `skills/skill-forge/tests/bootstrap/expected/structural-checks.txt`
- `skills/skill-forge/tests/unit/test-scaffold.sh`
- `skills/skill-forge/tests/unit/test-trace-id-regex.sh`
- `skills/skill-forge/tests/unit/test-config-schema.sh`
- `skills/skill-forge/tests/run-tests.sh`

### Project integration
- `CLAUDE.md` — add skill-forge to pipeline paragraph

---

## Task 1: Initialize skill-forge directory structure

**Files:**
- Create: `skills/skill-forge/` and all subdirectories (empty `.gitkeep` placeholders)

- [ ] **Step 1: Create directory tree**

Run:
```bash
cd /Users/wangzw/workspace/cofounder
mkdir -p skills/skill-forge/{common/{skeleton/{document,code,schema,hybrid},templates},scripts/lib,generate,review,revise,shared,tests/{bootstrap/expected,unit}}
touch skills/skill-forge/{common/skeleton/document,common/skeleton/code,common/skeleton/schema,common/skeleton/hybrid,common/templates,scripts,scripts/lib,generate,review,revise,shared,tests/bootstrap,tests/bootstrap/expected,tests/unit}/.gitkeep
```

- [ ] **Step 2: Verify tree**

Run:
```bash
find skills/skill-forge -type d | sort
```

Expected: 14 directories matching the file structure above.

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/
git commit -m "feat(skill-forge): scaffold directory structure"
```

---

## Task 2: Copy metrics-aggregate verbatim + pin sha

**Files:**
- Create: `skills/skill-forge/scripts/metrics-aggregate.sh`
- Create: `skills/skill-forge/scripts/lib/aggregate.py`
- Create: `skills/skill-forge/common/skeleton/shared-scripts-manifest.yml`

- [ ] **Step 1: Copy the two files verbatim**

```bash
cp ~/Documents/mind/raw/guide/attachments/metrics-aggregate/metrics-aggregate.sh skills/skill-forge/scripts/
cp ~/Documents/mind/raw/guide/attachments/metrics-aggregate/lib/aggregate.py skills/skill-forge/scripts/lib/
chmod +x skills/skill-forge/scripts/metrics-aggregate.sh
rm -f skills/skill-forge/scripts/.gitkeep skills/skill-forge/scripts/lib/.gitkeep
```

- [ ] **Step 2: Compute and pin sha256**

Run:
```bash
SHA_SH=$(sha256sum skills/skill-forge/scripts/metrics-aggregate.sh | awk '{print $1}')
SHA_PY=$(sha256sum skills/skill-forge/scripts/lib/aggregate.py | awk '{print $1}')
echo "metrics-aggregate.sh: $SHA_SH"
echo "aggregate.py: $SHA_PY"
```

Expected current shas (from 2026-04-24 snapshot):
- `metrics-aggregate.sh`: `70d2c3dad1d974ea2804002959465b29e1ca513d412acc59a04e5c812fc2a19f`
- `lib/aggregate.py`: `5a470b4b21b6257d7e2caf5ba64c38b96200bf92d4e2018c848b73c13d9e605f`

If the attachment has been updated since, use the fresh shas — that's the point of the pin.

- [ ] **Step 3: Write manifest**

Create `skills/skill-forge/common/skeleton/shared-scripts-manifest.yml`:

```yaml
# sha256 pins for verbatim-copied scripts from attachments/metrics-aggregate/
# Source: ~/Documents/mind/raw/guide/attachments/metrics-aggregate/
# Updated: 2026-04-24
# Check enforced by scripts/check-scaffold-sha.sh (CR-S12)
files:
  scripts/metrics-aggregate.sh:
    sha256: <paste SHA_SH from Step 2>
  scripts/lib/aggregate.py:
    sha256: <paste SHA_PY from Step 2>
```

Fill in the actual shas from Step 2.

- [ ] **Step 4: Smoke-test the copied scripts run**

Run:
```bash
skills/skill-forge/scripts/metrics-aggregate.sh --help 2>&1 | head -5
```

Expected: usage text with at least `--diagnose` and `--review-dir` mentioned. Exit 0 or 1 is fine (help output).

- [ ] **Step 5: Commit**

```bash
git add skills/skill-forge/scripts/metrics-aggregate.sh skills/skill-forge/scripts/lib/aggregate.py skills/skill-forge/common/skeleton/shared-scripts-manifest.yml
git rm -f skills/skill-forge/scripts/.gitkeep skills/skill-forge/scripts/lib/.gitkeep skills/skill-forge/common/skeleton/.gitkeep 2>/dev/null || true
git commit -m "feat(skill-forge): copy metrics-aggregate verbatim from attachments, pin sha256"
```

---

## Task 3: Write `common/snippets.md` (pinned Snippet C + D text)

**Files:**
- Create: `skills/skill-forge/common/snippets.md`

This is the single source of truth for the Snippet C (orchestrator dispatch-log + trace_id injection) and Snippet D (sub-agent IPC contract) text. `check-ipc-footer.sh` and `check-dispatch-log-snippet.sh` grep for fingerprints defined here.

- [ ] **Step 1: Write the file**

Author `skills/skill-forge/common/snippets.md` with two sections:

1. **Snippet C — Orchestrator dispatch contract** — adapted from `~/Documents/mind/raw/guide/attachments/metrics-aggregate/SKILL-INTEGRATION.md` Snippet C, updated for guide §3.9 two-event (launched + completed) model (the attachment's single-event phrasing predates §3.9; the spec treats both). Must include:
   - Trace_id format rule: `R<round>-<role-letter>-<nnn>` with role-letter table C/P/W/V/R/S/J
   - `launched` event JSON schema with required fields (trace_id, role, tier, model, delivery_id, dispatched_at, prompt_hash)
   - `completed` event JSON schema (trace_id, role, ack_status, linked_issues, returned_at, writer-only self_review_status + fail_count)
   - `trace_id:` marker on first line of sub-agent user prompt
   - Grep-fingerprint line: `<!-- snippet-c-fingerprint: dispatch-log-v1 -->`

2. **Snippet D — Sub-agent IPC contract** — updated for guide §3.9 "direct Write + ACK" model (not the attachment's HTML-footer model — the attachment predates §3.9's hard constraint that artifact leaves MUST NOT contain HTML metrics footers). Must include:
   - "Write to final path in your own sub-session" directive
   - "Task return is ONE LINE ACK" directive
   - ACK format: `OK trace_id=<id> role=<role> linked_issues=<...>` or `FAIL trace_id=<id> reason=<short>`
   - Writer-only fields: `self_review_status=<FULL_PASS|PARTIAL>` `fail_count=<N>`
   - FORBIDDEN: writing `<!-- metrics-footer -->` or any HTML-comment envelope into artifact leaves
   - FORBIDDEN: including generation content in Task return
   - Grep-fingerprint line: `<!-- snippet-d-fingerprint: ipc-ack-v1 -->`

Both fingerprints go at the top of their snippet's heading so check scripts can grep deterministically.

- [ ] **Step 2: Verify fingerprints unique**

Run:
```bash
grep -c 'snippet-c-fingerprint' skills/skill-forge/common/snippets.md
grep -c 'snippet-d-fingerprint' skills/skill-forge/common/snippets.md
```

Expected: `1` for each.

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/common/snippets.md
git commit -m "feat(skill-forge): pin Snippet C/D text with grep fingerprints"
```

---

## Task 4: Write `common/config.yml`

**Files:**
- Create: `skills/skill-forge/common/config.yml`

- [ ] **Step 1: Author the file**

Start from guide §21.2 complete field set. Minimum required top-level keys:

```yaml
skill_version: 0.1.0
review_criteria_version: 1.0.0
artifact_template_version: 1.0.0

convergence:
  max_iterations: 5
  converged_warning_threshold: 5
  accepted_verdicts: [converged]
  retriable_verdicts: [progressing]
  abort_verdicts: [oscillating, diverging, stalled]

model_tier_defaults:
  orchestrator:      balanced
  domain_consultant: heavy
  planner:           heavy
  writer:            balanced
  reviewer:          heavy
  reviser:           balanced
  summarizer:        light
  judge:             light

model_mapping:
  heavy:    claude-opus-4-5
  balanced: claude-sonnet-4-5
  light:    claude-haiku-4-5

pricing:
  models:
    claude-opus-4:    {input_per_1m: 15.0, output_per_1m: 75.0, cache_read_per_1m: 1.50, cache_creation_per_1m: 18.75}
    claude-sonnet-4:  {input_per_1m: 3.0,  output_per_1m: 15.0, cache_read_per_1m: 0.30, cache_creation_per_1m: 3.75}
    claude-haiku-4:   {input_per_1m: 0.8,  output_per_1m: 4.0,  cache_read_per_1m: 0.08, cache_creation_per_1m: 1.0}

priority_order: [quality, cost, performance]

adversarial_review:
  triggered_by: [critical]
  tier: heavy

domain_consultant:
  trigger:
    on_interactive_flag: true
    on_glossary_disambiguation: true
    on_sparse_input: true
    min_words_without_consultant: 50

delivery_commit:
  tag_enabled: true
  tag_slug_max_len: 40
  tag_date_fallback: "%Y%m%d"
  tag_force_overwrite: false

retention:
  traces_retention_rounds: 20
  insights_recent_count: 10

regression_gate:
  diverging_threshold: 3
  max_injected_resolved: 20
  recent_rounds_window: 5

retry_policy:
  transient_max_retries: 3
  backoff_ms: [1000, 3000, 10000]
  schema_retry_upgrade_tier: true

partial_failure_policy:
  generate_phase: continue_with_failures
  review_phase: abort_round
  revise_phase: continue_with_failures
  max_failure_rate: 0.3

hitl:
  auto_approve: []
  require_approval:
    - plan_approval
    - force_continue
    - regression_justification
    - stalled_release

tool_permissions:
  orchestrator:      {filesystem: "read-all + write-state + write-dispatch-log", network: false, execute: "allow-scripts", user-interaction: false}
  domain_consultant: {filesystem: "read-review-input + read-artifact-readme-only + read-domain-glossary + read-skeleton-readme + write-review-clarification", network: false, execute: false, user-interaction: true}
  planner:           {filesystem: "read-artifact + read-review-readme-only + read-review-input + read-review-clarification + write-round-plan", network: false, execute: false, user-interaction: false}
  writer:            {filesystem: "read-artifact + read-round-issues + read-review-clarification + write-target-domain-files + write-round-self-review", network: false, execute: false, user-interaction: false}
  reviewer:          {filesystem: "read-artifact + read-review + write-round-issues", network: false, execute: "allow-scripts", user-interaction: false}
  reviser:           {filesystem: "read-artifact + read-review + write-target-domain-files + write-round-revision", network: false, execute: false, user-interaction: false}
  summarizer:
    filesystem: "read-artifact + read-review + write-artifact-index + write-artifact-changelog + write-review-versions + write-review-round-index + write-review-metrics-readme"
    network: false
    execute: "allow-scripts"
    user-interaction: false
  judge:             {filesystem: "read-review-readme + read-round-index + read-round-issues-frontmatter + write-round-verdict", network: false, execute: false, user-interaction: false}

incremental_review:
  enabled: true
  force_full_every_n_rounds: 5
  depgraph: on
  coverage_gap_verdict: stalled
```

- [ ] **Step 2: Validate YAML**

Run:
```bash
python3 -c "
import sys
# hand-parsed (no pyyaml per §21.0); use json as structural check
with open('skills/skill-forge/common/config.yml') as f:
    s = f.read()
required = ['skill_version','convergence','model_tier_defaults','model_mapping','pricing','priority_order','adversarial_review','domain_consultant','delivery_commit','retention','regression_gate','retry_policy','partial_failure_policy','hitl','tool_permissions','incremental_review']
missing = [k for k in required if f'\n{k}:' not in '\n'+s]
if missing:
    print('MISSING:', missing); sys.exit(1)
print('OK — all top-level keys present')
"
```

Expected: `OK — all top-level keys present`

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/common/config.yml
git rm -f skills/skill-forge/common/.gitkeep 2>/dev/null || true
git commit -m "feat(skill-forge): add common/config.yml with §21.2 field set"
```

---

## Task 5: Write `common/review-criteria.md` (24 CR entries)

**Files:**
- Create: `skills/skill-forge/common/review-criteria.md`

- [ ] **Step 1: Author the file**

Format: one H2 section per criterion; each H2 contains (a) human-readable description, (b) ```yaml code block with the criterion YAML per guide §12.3.

Exact 24 criteria listed in spec §5.1 and §5.2 — CR-S01..CR-S14 (script) + CR-L01..CR-L10 (LLM).

Template for each:

````markdown
## CR-S01 skill-md-frontmatter

SKILL.md MUST have frontmatter with `name`, `version`, `description` keys; `description` ≤ 1024 chars; `description` MUST start with "Use when" per guide §21.1.

```yaml
- id: CR-S01
  name: "skill-md-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: error
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```
````

Repeat for all 24. For LLM criteria, `checker_type: llm` and `script_path:` omitted. All `conflicts_with: []` in v1 (spec §5 explicitly empty to avoid oscillation).

- [ ] **Step 2: Verify all 24 entries present**

Run:
```bash
grep -c '^  id: CR-' skills/skill-forge/common/review-criteria.md
```

Expected: `24`

- [ ] **Step 3: Verify each entry has required fields**

Run:
```bash
python3 -c "
import re
with open('skills/skill-forge/common/review-criteria.md') as f:
    s = f.read()
# extract all yaml blocks
blocks = re.findall(r'\`\`\`yaml\n(.*?)\n\`\`\`', s, re.DOTALL)
required = ['id:', 'name:', 'version:', 'checker_type:', 'severity:']
ok = True
for i, b in enumerate(blocks):
    for f in required:
        if f not in b:
            print(f'block {i} missing {f}'); ok=False
print('OK' if ok else 'FAIL')
"
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add skills/skill-forge/common/review-criteria.md
git commit -m "feat(skill-forge): add review-criteria.md with 24 CR entries (14 script + 10 LLM)"
```

---

## Task 6: Write `common/domain-glossary.md`

**Files:**
- Create: `skills/skill-forge/common/domain-glossary.md`

- [ ] **Step 1: Author the file**

Format per guide §6.2: entries flagged `disambiguation_required: true` trigger the domain-consultant via `glossary-probe.sh` grep matches.

Content: the 7 terms from spec §3.2 plus conversational variants as grep hooks. Each entry:

```markdown
## generative skill | workflow skill

**Disambiguation required.** Users often use "skill" loosely. Generative skills produce artifacts from sparse input (PRD, design, wiki); workflow skills orchestrate deterministic steps (lint, deploy). Maps to very different scaffolds.

```yaml
- term: "generative skill"
  aliases: ["生成式 skill", "content-generating skill", "artifact skill"]
  disambiguation_required: true
  definition: "Produces artifacts from sparse user input, e.g., a PRD or design doc"

- term: "workflow skill"
  aliases: ["workflow", "工作流 skill", "procedural skill"]
  disambiguation_required: true
  definition: "Orchestrates deterministic steps; no generation or quality judgment involved"
```
```

Full set to author:
1. `generative skill` / `workflow skill`
2. `delivery` / `version` / `semver` / `release` / `major version`
3. `cross-reviewer` / `adversarial-reviewer`
4. `artifact` / `output` / `制品`
5. `leaf` / `叶子` / `leaf file`
6. `sub-agent` / `role` / `agent`
7. `checker_type` / `script` / `llm` / `hybrid`

- [ ] **Step 2: Verify parse**

Run:
```bash
grep -c 'disambiguation_required: true' skills/skill-forge/common/domain-glossary.md
```

Expected: ≥ 7

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/common/domain-glossary.md
git commit -m "feat(skill-forge): add domain-glossary.md with 7 disambig-required term groups"
```

---

## Task 7: Write `scripts/git-precheck.sh` (TDD)

**Files:**
- Create: `skills/skill-forge/tests/unit/test-git-precheck.sh`
- Create: `skills/skill-forge/scripts/git-precheck.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/skill-forge/tests/unit/test-git-precheck.sh`:

```bash
#!/usr/bin/env bash
# test-git-precheck.sh — unit tests for git-precheck.sh
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/git-precheck.sh"

# Test 1: exists + executable
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Test 2: checks all three of git/bash/python3
grep -q 'command -v git' "$SCRIPT" || { echo "FAIL: missing git check"; exit 1; }
grep -q 'BASH_VERSINFO' "$SCRIPT" || { echo "FAIL: missing bash ≥4 check"; exit 1; }
grep -q 'python3' "$SCRIPT" || { echo "FAIL: missing python3 check"; exit 1; }

# Test 3: dry-run in current repo succeeds
cd "$(dirname "$SCRIPT")/.." && "$SCRIPT" >/dev/null 2>&1 \
  || { echo "FAIL: precheck failed in a valid git repo"; exit 1; }

echo "PASS test-git-precheck.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
chmod +x skills/skill-forge/tests/unit/test-git-precheck.sh
skills/skill-forge/tests/unit/test-git-precheck.sh
```

Expected: FAIL with "not executable" or missing script.

- [ ] **Step 3: Write `git-precheck.sh`**

Create `skills/skill-forge/scripts/git-precheck.sh`:

```bash
#!/usr/bin/env bash
# git-precheck.sh — bootstrap precheck per guide §21.0 + §8.3
# Verifies: git ≥ 2.0, bash ≥ 4.0, python3 ≥ 3.8
# Then: ensures cwd is a git repo (auto-init if not)
set -euo pipefail

command -v git >/dev/null 2>&1 || { echo "FATAL: git not installed" >&2; exit 1; }

GIT_VER=$(git --version | awk '{print $3}')
[[ "$GIT_VER" =~ ^([0-9]+)\. ]] && [ "${BASH_REMATCH[1]}" -ge 2 ] \
  || { echo "FATAL: git ≥ 2.0 required, found $GIT_VER" >&2; exit 1; }

[ "${BASH_VERSINFO[0]}" -ge 4 ] \
  || { echo "FATAL: bash ≥ 4.0 required, found $BASH_VERSION (macOS default is 3.2; brew install bash)" >&2; exit 1; }

python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || { echo "FATAL: python3 ≥ 3.8 required" >&2; exit 1; }

# Ensure cwd is a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "INFO: not a git repo; auto-running 'git init'" >&2
  git init >&2
  git add -A >&2
  git -c user.name=skill-forge -c user.email=skill-forge@local commit -m "init: skill-forge bootstrap" >&2
fi

echo "OK precheck passed (git $GIT_VER, bash $BASH_VERSION, python3 $(python3 --version | awk '{print $2}'))"
```

- [ ] **Step 4: Run test**

```bash
chmod +x skills/skill-forge/scripts/git-precheck.sh
skills/skill-forge/tests/unit/test-git-precheck.sh
```

Expected: `PASS test-git-precheck.sh`

- [ ] **Step 5: Commit**

```bash
git add skills/skill-forge/scripts/git-precheck.sh skills/skill-forge/tests/unit/test-git-precheck.sh
git commit -m "feat(skill-forge): add git-precheck.sh with three-tool precheck + auto git init"
```

---

## Task 8: Write `scripts/prepare-input.sh` and `scripts/glossary-probe.sh`

**Files:**
- Create: `skills/skill-forge/scripts/prepare-input.sh`
- Create: `skills/skill-forge/scripts/glossary-probe.sh`

- [ ] **Step 1: Write `prepare-input.sh`**

Per guide §6.1. Signature: `prepare-input.sh <user-prompt> <review-dir>`. Behavior:

1. Write `<review-dir>/round-0/input.md` with a `# User Prompt` section containing the verbatim prompt
2. Scan prompt for `@<path>` file refs, `http(s)://` URLs, and attachment paths; expand each under a `# Expanded References` section (each expansion is a `## <ref>` subheading with inline content)
3. Write `<review-dir>/round-0/input-meta.yml` with `word_count`, `has_code_block`, `has_structured_lists`, `expanded_references`

Use only std tools (grep, awk, sed, curl). For `@<path>` resolve relative to repo root. For URLs, fetch with `curl -sSL --max-time 10` and inline the body (if any fetch fails, note in input-meta.yml under `fetch_errors:` rather than abort).

- [ ] **Step 2: Write `glossary-probe.sh`**

Per guide §6.2 trigger condition 2. Signature: `glossary-probe.sh <review-dir> <glossary-path>`. Behavior:

1. Read `<review-dir>/round-0/input.md`
2. Parse `<glossary-path>` for all terms with `disambiguation_required: true` (including aliases)
3. For each matching term found in input.md, note the line number
4. Read `input-meta.yml` for `word_count`; compute `sparse_input: <bool>` against config `min_words_without_consultant: 50`
5. Write `<review-dir>/round-0/trigger-flags.yml` per §6.2 schema

- [ ] **Step 3: Smoke-test**

```bash
mkdir -p /tmp/prep-test
chmod +x skills/skill-forge/scripts/prepare-input.sh skills/skill-forge/scripts/glossary-probe.sh
skills/skill-forge/scripts/prepare-input.sh "I want a skill that processes decision logs" /tmp/prep-test
cat /tmp/prep-test/round-0/input.md
cat /tmp/prep-test/round-0/input-meta.yml
skills/skill-forge/scripts/glossary-probe.sh /tmp/prep-test skills/skill-forge/common/domain-glossary.md
cat /tmp/prep-test/round-0/trigger-flags.yml
rm -rf /tmp/prep-test
```

Expected: `input.md` has `# User Prompt` section; `input-meta.yml` has `word_count:` ≈ 8; `trigger-flags.yml` shows `sparse_input: true`.

- [ ] **Step 4: Commit**

```bash
git add skills/skill-forge/scripts/prepare-input.sh skills/skill-forge/scripts/glossary-probe.sh
git commit -m "feat(skill-forge): add prepare-input.sh + glossary-probe.sh for Round 0"
```

---

## Task 9: Write `scripts/check-skill-structure.sh` (CR-S03 + CR-S04) — TDD

**Files:**
- Create: `skills/skill-forge/tests/unit/test-check-skill-structure.sh`
- Create: `skills/skill-forge/scripts/check-skill-structure.sh`
- Create: `skills/skill-forge/tests/unit/fixtures/complete-skill/` (valid target skill tree)
- Create: `skills/skill-forge/tests/unit/fixtures/missing-generate/` (incomplete — missing `generate/`)

- [ ] **Step 1: Build fixture trees**

```bash
mkdir -p skills/skill-forge/tests/unit/fixtures/complete-skill/{common,scripts,generate,review,revise,shared}
touch skills/skill-forge/tests/unit/fixtures/complete-skill/SKILL.md
for f in generate/domain-consultant-subagent.md generate/planner-subagent.md generate/writer-subagent.md review/cross-reviewer-subagent.md review/adversarial-reviewer-subagent.md revise/per-issue-reviser-subagent.md shared/summarizer-subagent.md shared/judge-subagent.md; do
  touch skills/skill-forge/tests/unit/fixtures/complete-skill/$f
done

mkdir -p skills/skill-forge/tests/unit/fixtures/missing-generate/{common,scripts,review,revise,shared}
touch skills/skill-forge/tests/unit/fixtures/missing-generate/SKILL.md
```

- [ ] **Step 2: Write the failing test**

Create `skills/skill-forge/tests/unit/test-check-skill-structure.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/check-skill-structure.sh"
FIX="$(dirname "$0")/fixtures"

# valid fixture → exit 0
"$SCRIPT" "$FIX/complete-skill" >/dev/null 2>&1 \
  || { echo "FAIL: complete-skill rejected"; exit 1; }

# missing generate → exit 1 with issue mentioning 'generate'
OUT=$("$SCRIPT" "$FIX/missing-generate" 2>&1 || true)
echo "$OUT" | grep -q 'generate' \
  || { echo "FAIL: missing-generate not reported"; exit 1; }

echo "PASS test-check-skill-structure.sh"
```

```bash
chmod +x skills/skill-forge/tests/unit/test-check-skill-structure.sh
skills/skill-forge/tests/unit/test-check-skill-structure.sh  # expect fail
```

- [ ] **Step 3: Implement**

Create `skills/skill-forge/scripts/check-skill-structure.sh`:

```bash
#!/usr/bin/env bash
# check-skill-structure.sh — CR-S03 (directory-skeleton) + CR-S04 (subagent-inventory)
# Usage: check-skill-structure.sh <target-skill-dir>
# Exit: 0=pass, 1=issues found (JSON array to stdout), 2=script error
set -euo pipefail
TARGET="${1:?usage: check-skill-structure.sh <target-skill-dir>}"
[ -d "$TARGET" ] || { echo "FATAL: $TARGET not a directory" >&2; exit 2; }

ISSUES=()

# CR-S03: required directories
for d in common scripts generate review revise shared; do
  if [ ! -d "$TARGET/$d" ]; then
    ISSUES+=("{\"criterion_id\":\"CR-S03\",\"file\":\"$d/\",\"severity\":\"critical\",\"description\":\"missing required directory '$d'\",\"suggested_fix\":\"mkdir -p $TARGET/$d\"}")
  fi
done

# CR-S04: required sub-agent prompts
declare -a REQUIRED=(
  "generate/domain-consultant-subagent.md"
  "generate/planner-subagent.md"
  "generate/writer-subagent.md"
  "review/cross-reviewer-subagent.md"
  "review/adversarial-reviewer-subagent.md"
  "revise/per-issue-reviser-subagent.md"
  "shared/summarizer-subagent.md"
  "shared/judge-subagent.md"
)

for f in "${REQUIRED[@]}"; do
  if [ ! -f "$TARGET/$f" ]; then
    ISSUES+=("{\"criterion_id\":\"CR-S04\",\"file\":\"$f\",\"severity\":\"critical\",\"description\":\"missing required sub-agent prompt '$f'\",\"suggested_fix\":\"author $f per guide §5.2\"}")
  fi
done

# SKILL.md must exist (orchestrator prompt inline)
if [ ! -f "$TARGET/SKILL.md" ]; then
  ISSUES+=('{"criterion_id":"CR-S04","file":"SKILL.md","severity":"critical","description":"SKILL.md missing (orchestrator prompt must live here)","suggested_fix":"author SKILL.md per guide §21.1"}')
fi

if [ ${#ISSUES[@]} -eq 0 ]; then
  echo "[]"
  exit 0
else
  python3 -c "import json; print(json.dumps([$(IFS=,; echo "${ISSUES[*]}")], indent=2))"
  exit 1
fi
```

- [ ] **Step 4: Run test**

```bash
chmod +x skills/skill-forge/scripts/check-skill-structure.sh
skills/skill-forge/tests/unit/test-check-skill-structure.sh
```

Expected: `PASS test-check-skill-structure.sh`

- [ ] **Step 5: Commit**

```bash
git add skills/skill-forge/scripts/check-skill-structure.sh skills/skill-forge/tests/unit/test-check-skill-structure.sh skills/skill-forge/tests/unit/fixtures/
git commit -m "feat(skill-forge): add check-skill-structure.sh for CR-S03/S04 with TDD fixtures"
```

---

## Task 10: Write `scripts/check-ipc-footer.sh` (CR-S08) — TDD

**Files:**
- Create: `skills/skill-forge/tests/unit/test-check-ipc-footer.sh`
- Create: `skills/skill-forge/scripts/check-ipc-footer.sh`
- Extend fixtures: `tests/unit/fixtures/complete-skill/{generate,review,revise,shared}/*.md` get the fingerprint; one fixture `tests/unit/fixtures/missing-footer/` does not.

- [ ] **Step 1: Extend fixture**

Add the fingerprint line `<!-- snippet-d-fingerprint: ipc-ack-v1 -->` to the top of each subagent prompt in `complete-skill/` (8 files). Leave `missing-footer/` (copy of complete-skill minus one prompt's fingerprint) for the negative case.

```bash
cp -r skills/skill-forge/tests/unit/fixtures/complete-skill skills/skill-forge/tests/unit/fixtures/missing-footer
for f in skills/skill-forge/tests/unit/fixtures/complete-skill/{generate,review,revise,shared}/*.md; do
  echo '<!-- snippet-d-fingerprint: ipc-ack-v1 -->' > "$f.tmp" && cat "$f" >> "$f.tmp" && mv "$f.tmp" "$f"
done
# Leave missing-footer/ without any fingerprints
```

- [ ] **Step 2: Write failing test**

`skills/skill-forge/tests/unit/test-check-ipc-footer.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/check-ipc-footer.sh"
FIX="$(dirname "$0")/fixtures"

"$SCRIPT" "$FIX/complete-skill" >/dev/null 2>&1 || { echo "FAIL: complete-skill rejected"; exit 1; }
OUT=$("$SCRIPT" "$FIX/missing-footer" 2>&1 || true)
echo "$OUT" | grep -q 'snippet-d-fingerprint' || { echo "FAIL: missing-footer not reported"; exit 1; }
echo "PASS test-check-ipc-footer.sh"
```

- [ ] **Step 3: Implement**

`skills/skill-forge/scripts/check-ipc-footer.sh`:

```bash
#!/usr/bin/env bash
# check-ipc-footer.sh — CR-S08 (every sub-agent prompt contains Snippet D fingerprint)
set -euo pipefail
TARGET="${1:?usage: check-ipc-footer.sh <target-skill-dir>}"
ISSUES=()
for f in "$TARGET"/generate/*-subagent.md "$TARGET"/review/*-subagent.md "$TARGET"/revise/*-subagent.md "$TARGET"/shared/*-subagent.md; do
  [ -f "$f" ] || continue
  if ! grep -q '<!-- snippet-d-fingerprint: ipc-ack-v1 -->' "$f"; then
    rel="${f#$TARGET/}"
    ISSUES+=("{\"criterion_id\":\"CR-S08\",\"file\":\"$rel\",\"severity\":\"critical\",\"description\":\"missing snippet-d-fingerprint IPC contract\",\"suggested_fix\":\"prepend Snippet D from common/snippets.md\"}")
  fi
done
if [ ${#ISSUES[@]} -eq 0 ]; then echo "[]"; exit 0
else python3 -c "import json; print(json.dumps([$(IFS=,; echo "${ISSUES[*]}")], indent=2))"; exit 1
fi
```

- [ ] **Step 4: Run test + commit**

```bash
chmod +x skills/skill-forge/scripts/check-ipc-footer.sh skills/skill-forge/tests/unit/test-check-ipc-footer.sh
skills/skill-forge/tests/unit/test-check-ipc-footer.sh  # expect PASS
git add skills/skill-forge/scripts/check-ipc-footer.sh skills/skill-forge/tests/unit/test-check-ipc-footer.sh skills/skill-forge/tests/unit/fixtures/
git commit -m "feat(skill-forge): add check-ipc-footer.sh for CR-S08"
```

---

## Task 11: Write `scripts/check-dispatch-log-snippet.sh` (CR-S09) — TDD

**Files:**
- Create: `skills/skill-forge/tests/unit/test-check-dispatch-log-snippet.sh`
- Create: `skills/skill-forge/scripts/check-dispatch-log-snippet.sh`
- Extend fixtures: add snippet-c-fingerprint to `complete-skill/SKILL.md`

- [ ] **Step 1: Extend fixture**

```bash
echo '<!-- snippet-c-fingerprint: dispatch-log-v1 -->' > skills/skill-forge/tests/unit/fixtures/complete-skill/SKILL.md
```

Create `skills/skill-forge/tests/unit/fixtures/missing-snippet-c/` (copy of complete-skill with a SKILL.md lacking the fingerprint):

```bash
cp -r skills/skill-forge/tests/unit/fixtures/complete-skill skills/skill-forge/tests/unit/fixtures/missing-snippet-c
echo 'no fingerprint here' > skills/skill-forge/tests/unit/fixtures/missing-snippet-c/SKILL.md
```

- [ ] **Step 2: Write test**

`skills/skill-forge/tests/unit/test-check-dispatch-log-snippet.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/check-dispatch-log-snippet.sh"
FIX="$(dirname "$0")/fixtures"
"$SCRIPT" "$FIX/complete-skill" >/dev/null 2>&1 || { echo "FAIL"; exit 1; }
OUT=$("$SCRIPT" "$FIX/missing-snippet-c" 2>&1 || true)
echo "$OUT" | grep -q 'snippet-c' || { echo "FAIL: not reported"; exit 1; }
echo "PASS"
```

- [ ] **Step 3: Implement**

`skills/skill-forge/scripts/check-dispatch-log-snippet.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:?usage: <target-skill-dir>}"
SKILL_MD="$TARGET/SKILL.md"
[ -f "$SKILL_MD" ] || { echo '[{"criterion_id":"CR-S09","file":"SKILL.md","severity":"critical","description":"SKILL.md missing"}]'; exit 1; }
if grep -q '<!-- snippet-c-fingerprint: dispatch-log-v1 -->' "$SKILL_MD"; then
  echo "[]"; exit 0
else
  echo '[{"criterion_id":"CR-S09","file":"SKILL.md","severity":"critical","description":"missing snippet-c-fingerprint (dispatch-log contract)","suggested_fix":"embed Snippet C from common/snippets.md in SKILL.md orchestrator body"}]'
  exit 1
fi
```

- [ ] **Step 4: Run + commit**

```bash
chmod +x skills/skill-forge/scripts/check-dispatch-log-snippet.sh skills/skill-forge/tests/unit/test-check-dispatch-log-snippet.sh
skills/skill-forge/tests/unit/test-check-dispatch-log-snippet.sh  # PASS
git add skills/skill-forge/scripts/check-dispatch-log-snippet.sh skills/skill-forge/tests/unit/test-check-dispatch-log-snippet.sh skills/skill-forge/tests/unit/fixtures/
git commit -m "feat(skill-forge): add check-dispatch-log-snippet.sh for CR-S09"
```

---

## Task 12: Write `scripts/check-trace-id-format.sh` (CR-S10) — TDD

**Files:**
- Create: `skills/skill-forge/tests/unit/test-trace-id-regex.sh`
- Create: `skills/skill-forge/scripts/check-trace-id-format.sh`

- [ ] **Step 1: Write test with positive + negative fixtures inline**

`skills/skill-forge/tests/unit/test-trace-id-regex.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/check-trace-id-format.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# positive — valid formats
cat > "$TMP/good.md" <<'EOF'
trace_id: R3-W-007
trace_id: R1-P-001
trace_id: R12-C-042
EOF

"$SCRIPT" "$TMP/good.md" >/dev/null 2>&1 || { echo "FAIL: good.md rejected"; exit 1; }

# negative — malformed
cat > "$TMP/bad.md" <<'EOF'
trace_id: R-W-7
trace_id: round3-W-007
trace_id: R3-X-001
EOF

OUT=$("$SCRIPT" "$TMP/bad.md" 2>&1 || true)
echo "$OUT" | grep -q 'CR-S10' || { echo "FAIL: bad.md not reported"; exit 1; }

echo "PASS test-trace-id-regex.sh"
```

- [ ] **Step 2: Implement**

`skills/skill-forge/scripts/check-trace-id-format.sh`:

```bash
#!/usr/bin/env bash
# check-trace-id-format.sh — CR-S10: validate trace_id occurrences match R<N>-<role-letter>-<nnn>
# Usage: <target-skill-dir-or-file>
# Role letters: C P W V R S J (per guide §3.5)
set -euo pipefail
TARGET="${1:?usage}"
ISSUES=()
if [ -d "$TARGET" ]; then
  FILES=$(find "$TARGET" \( -name '*.md' -o -name '*.sh' \) -type f)
else
  FILES="$TARGET"
fi
for f in $FILES; do
  while IFS= read -r line; do
    id="${line##*trace_id: }"; id="${id%% *}"; id="${id%,}"
    if [[ ! "$id" =~ ^R[0-9]+-[CPWVRSJ]-[0-9]{3}$ ]]; then
      rel="${f#$TARGET/}"
      ISSUES+=("{\"criterion_id\":\"CR-S10\",\"file\":\"$rel\",\"severity\":\"error\",\"description\":\"invalid trace_id format '$id' (expected R<N>-<role-letter>-<nnn> with role letter in [CPWVRSJ])\",\"suggested_fix\":\"fix per guide §3.5\"}")
    fi
  done < <(grep -oE 'trace_id: R[^[:space:],]*' "$f" 2>/dev/null || true)
done

if [ ${#ISSUES[@]} -eq 0 ]; then echo "[]"; exit 0
else python3 -c "import json; print(json.dumps([$(IFS=,; echo "${ISSUES[*]}")], indent=2))"; exit 1
fi
```

- [ ] **Step 3: Run + commit**

```bash
chmod +x skills/skill-forge/scripts/check-trace-id-format.sh skills/skill-forge/tests/unit/test-trace-id-regex.sh
skills/skill-forge/tests/unit/test-trace-id-regex.sh  # PASS
git add skills/skill-forge/scripts/check-trace-id-format.sh skills/skill-forge/tests/unit/test-trace-id-regex.sh
git commit -m "feat(skill-forge): add check-trace-id-format.sh for CR-S10"
```

---

## Task 13: Write `scripts/check-config-schema.sh` (CR-S06 + CR-S11) — TDD

**Files:**
- Create: `skills/skill-forge/tests/unit/test-config-schema.sh`
- Create: `skills/skill-forge/scripts/check-config-schema.sh`

- [ ] **Step 1: Write test**

`skills/skill-forge/tests/unit/test-config-schema.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/check-config-schema.sh"
# Use skill-forge's own config as a positive fixture
"$SCRIPT" "$(dirname "$0")/../../" >/dev/null 2>&1 || { echo "FAIL: own config rejected"; exit 1; }

# Negative: a config missing tool_permissions
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/common"
cat > "$TMP/common/config.yml" <<'EOF'
skill_version: 0.1.0
convergence: {max_iterations: 5}
EOF
OUT=$("$SCRIPT" "$TMP" 2>&1 || true)
echo "$OUT" | grep -q 'tool_permissions' || { echo "FAIL: missing key not reported"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Implement**

`skills/skill-forge/scripts/check-config-schema.sh`:

```bash
#!/usr/bin/env bash
# CR-S06 (config-schema completeness) + CR-S11 (tool_permissions covers 8 roles)
set -euo pipefail
TARGET="${1:?usage: <target-skill-dir>}"
CONFIG="$TARGET/common/config.yml"
[ -f "$CONFIG" ] || { echo '[{"criterion_id":"CR-S06","file":"common/config.yml","severity":"error","description":"config.yml missing"}]'; exit 1; }

python3 - <<PYEOF
import re, json, sys
with open("$CONFIG") as f: s = f.read()

required_keys = ['skill_version','convergence','model_tier_defaults','model_mapping','pricing','priority_order','adversarial_review','domain_consultant','delivery_commit','retention','regression_gate','retry_policy','partial_failure_policy','hitl','tool_permissions','incremental_review']
required_roles = ['orchestrator','domain_consultant','planner','writer','reviewer','reviser','summarizer','judge']
issues = []
for k in required_keys:
    if not re.search(rf'(?m)^{re.escape(k)}:', s):
        issues.append({"criterion_id":"CR-S06","file":"common/config.yml","severity":"error","description":f"missing top-level key '{k}' per guide §21.2","suggested_fix":f"add '{k}:' section"})

# tool_permissions sub-keys (CR-S11)
tp_block = re.search(r'(?m)^tool_permissions:\n((?:  .*\n)+)', s)
if tp_block:
    body = tp_block.group(1)
    for r in required_roles:
        if not re.search(rf'(?m)^  {re.escape(r)}:', body):
            issues.append({"criterion_id":"CR-S11","file":"common/config.yml","severity":"error","description":f"tool_permissions missing role '{r}'","suggested_fix":f"add '{r}:' entry"})
    # user-interaction: true only on domain_consultant
    user_interaction_true = re.findall(r'(?m)^  (\w+):.*user-interaction: true', body)
    for r in user_interaction_true:
        if r != 'domain_consultant':
            issues.append({"criterion_id":"CR-S11","file":"common/config.yml","severity":"error","description":f"role '{r}' has user-interaction: true (only domain_consultant may)","suggested_fix":"set user-interaction: false"})

if not issues: print("[]"); sys.exit(0)
print(json.dumps(issues, indent=2)); sys.exit(1)
PYEOF
```

- [ ] **Step 3: Run + commit**

```bash
chmod +x skills/skill-forge/scripts/check-config-schema.sh skills/skill-forge/tests/unit/test-config-schema.sh
skills/skill-forge/tests/unit/test-config-schema.sh  # PASS
git add skills/skill-forge/scripts/check-config-schema.sh skills/skill-forge/tests/unit/test-config-schema.sh
git commit -m "feat(skill-forge): add check-config-schema.sh for CR-S06 + CR-S11"
```

---

## Task 14: Write remaining check-*.sh scripts (S07, S12, S13, S14 + standard S01/S02/S05)

**Files:**
- Create: `skills/skill-forge/scripts/check-frontmatter.sh` (CR-S01)
- Create: `skills/skill-forge/scripts/check-mode-routing.sh` (CR-S02)
- Create: `skills/skill-forge/scripts/check-scripts-inventory.sh` (CR-S05)
- Create: `skills/skill-forge/scripts/check-criteria-yaml.sh` (CR-S07)
- Create: `skills/skill-forge/scripts/check-scaffold-sha.sh` (CR-S12)
- Create: `skills/skill-forge/scripts/check-artifact-pyramid.sh` (CR-S13)
- Create: `skills/skill-forge/scripts/check-dependencies.sh` (CR-S14)

Each follows the same shape as Tasks 9–13: exit `0` + `[]` or exit `1` + JSON issues array.

- [ ] **Step 1: Author all 7 check scripts**

For each: ≤ 50 lines of bash or embedded python3. Key behaviors:

- `check-frontmatter.sh`: parse SKILL.md frontmatter, assert `name/version/description` present, description starts with "Use when" and ≤ 1024 chars
- `check-mode-routing.sh`: parse SKILL.md, assert a `## Mode Routing` section with a table having rows for Generate/Review/Revise/Diagnose
- `check-scripts-inventory.sh`: assert each of the 13 required scripts in spec §6.1 exists and is executable
- `check-criteria-yaml.sh`: extract YAML blocks from `common/review-criteria.md`, assert each has `id/name/version/checker_type/severity` + `checker_type ∈ {script,llm,hybrid}`
- `check-scaffold-sha.sh`: read `common/skeleton/shared-scripts-manifest.yml`, compute current sha256 of the two files, report mismatches
- `check-artifact-pyramid.sh`: assert `common/templates/artifact-template.md` exists; if it references a single-file structure (no subdirs in its example tree), flag CR-S13 error
- `check-dependencies.sh`: parse generated `git-precheck.sh`, assert all three of git/bash/python3 checks present

- [ ] **Step 2: Write unit tests for each**

For each script, add a `skills/skill-forge/tests/unit/test-<name>.sh` following the same positive+negative fixture pattern as Task 9.

- [ ] **Step 3: Run all**

```bash
for t in skills/skill-forge/tests/unit/test-check-*.sh; do chmod +x "$t"; "$t" || exit 1; done
```

Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
chmod +x skills/skill-forge/scripts/check-*.sh
git add skills/skill-forge/scripts/check-*.sh skills/skill-forge/tests/unit/test-check-*.sh skills/skill-forge/tests/unit/fixtures/
git commit -m "feat(skill-forge): add remaining check-*.sh scripts for CR-S01/S02/S05/S07/S12/S13/S14"
```

---

## Task 15: Write `scripts/extract-criteria.sh` + `check-criteria-consistency.sh` + `check-index-consistency.sh` + `check-changelog-consistency.sh`

**Files:**
- Create: `skills/skill-forge/scripts/extract-criteria.sh`
- Create: `skills/skill-forge/scripts/check-criteria-consistency.sh`
- Create: `skills/skill-forge/scripts/check-index-consistency.sh`
- Create: `skills/skill-forge/scripts/check-changelog-consistency.sh`

- [ ] **Step 1: Author each per guide §12/§13/§7.5/§10.4**

- `extract-criteria.sh <target>`: stdout = JSON array of all criteria YAML blocks (used by other scripts)
- `check-criteria-consistency.sh <target>`: detect CRs that appear in mutual `conflicts_with` (symmetric) but with different severities — §13.1 self-consistency
- `check-index-consistency.sh <target>`: verify every leaf under the artifact is listed in its parent's `index.md` and vice versa — §7.5
- `check-changelog-consistency.sh <target>`: verify every entry in target's `CHANGELOG.md` has a matching `.review/versions/<N>.md` with identical `delivery_id`, `change_summary`, `affected_leaves`

- [ ] **Step 2: Unit tests**

Add at minimum a happy-path test for each in `tests/unit/`.

- [ ] **Step 3: Commit**

```bash
chmod +x skills/skill-forge/scripts/extract-criteria.sh skills/skill-forge/scripts/check-criteria-consistency.sh skills/skill-forge/scripts/check-index-consistency.sh skills/skill-forge/scripts/check-changelog-consistency.sh
git add skills/skill-forge/scripts/extract-criteria.sh skills/skill-forge/scripts/check-criteria-consistency.sh skills/skill-forge/scripts/check-index-consistency.sh skills/skill-forge/scripts/check-changelog-consistency.sh skills/skill-forge/tests/unit/
git commit -m "feat(skill-forge): add criteria/index/changelog consistency checkers"
```

---

## Task 16: Write `scripts/build-depgraph.sh`

**Files:**
- Create: `skills/skill-forge/scripts/build-depgraph.sh`

- [ ] **Step 1: Implement per guide §8.5 condition 4**

For document-type targets: parse `[[wikilinks]]` between leaves; for code: parse imports. For v1 skill-forge, only document variant is fully fleshed; others emit an empty graph with `depgraph: off` semantics.

Output: `<target>/.review/round-<N>/depgraph.yml` per guide schema.

- [ ] **Step 2: Commit**

```bash
chmod +x skills/skill-forge/scripts/build-depgraph.sh
git add skills/skill-forge/scripts/build-depgraph.sh
git commit -m "feat(skill-forge): add build-depgraph.sh for §8.5 condition 4"
```

---

## Task 17: Write `scripts/run-checkers.sh` (phase A + phase B)

**Files:**
- Create: `skills/skill-forge/scripts/run-checkers.sh`
- Create: `skills/skill-forge/tests/unit/test-run-checkers.sh`

- [ ] **Step 1: Implement per guide §12.5**

```
run-checkers.sh <target-skill-dir> <round-N>
  phase A:
    - hash all artifact leaves → <target>/.review/round-<N>/manifest.yml
    - run build-depgraph.sh → <target>/.review/round-<N>/depgraph.yml (if depgraph: on)
    - read round-(N-1)/manifest + round-(N-1)/issues/*.md frontmatter
    - compute skip-set per §8.5 conditions 1+2+3 (+4 if depgraph available)
    - write <target>/.review/round-<N>/skip-set.yml per §12.5.1 schema
  phase B:
    - run every check-*.sh in parallel; collect stdout JSON arrays
    - filter single-file checkers by skip-set (per_file criteria)
    - full_scan criteria run on all leaves
    - aggregate to <target>/.review/round-<N>/issues/*.md files (one per issue)
```

- [ ] **Step 2: Test end-to-end**

Create a minimal fixture target under `tests/unit/fixtures/minimal-target/` and run `run-checkers.sh` against it.

- [ ] **Step 3: Commit**

```bash
chmod +x skills/skill-forge/scripts/run-checkers.sh skills/skill-forge/tests/unit/test-run-checkers.sh
git add skills/skill-forge/scripts/run-checkers.sh skills/skill-forge/tests/unit/
git commit -m "feat(skill-forge): add run-checkers.sh with phase A+B per §12.5"
```

---

## Task 18: Write `scripts/scaffold.sh`

**Files:**
- Create: `skills/skill-forge/scripts/scaffold.sh`
- Create: `skills/skill-forge/tests/unit/test-scaffold.sh`

- [ ] **Step 1: Implement**

Signature: `scaffold.sh <variant> <target-path> <clarification-yml>`. Behavior:

1. Validate `<variant>` ∈ `{document, code, schema, hybrid}`
2. If `<target-path>` exists: verify every file matches (sha256) skeleton; on drift exit 2 with drift report
3. If `<target-path>` does not exist: `cp -r common/skeleton/<variant>/ <target-path>/`
4. Substitute `{{placeholders}}` in copied files (e.g., `{{SKILL_NAME}}`, `{{ARTIFACT_ROOT}}`, `{{SKILL_VERSION}}`) from `<clarification-yml>` fields R-001..R-007
5. Never substitute in `scripts/metrics-aggregate.sh` or `scripts/lib/aggregate.py` (those are sha-pinned)

Use Python3 `string.Template.safe_substitute` for substitution.

- [ ] **Step 2: Test**

`skills/skill-forge/tests/unit/test-scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(dirname "$0")/../../scripts/scaffold.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/clarification.yml" <<'EOF'
skill_name: test-skill
artifact_root: docs/raw/test/
skill_version: 0.1.0
EOF

# test with document variant (we'll build this in Task 21)
# for now just assert script exists + is executable
[ -x "$SCRIPT" ] || { echo "FAIL: not executable"; exit 1; }
"$SCRIPT" --help 2>&1 | grep -q variant || { echo "FAIL: no --help"; exit 1; }
echo "PASS"
```

- [ ] **Step 3: Commit**

```bash
chmod +x skills/skill-forge/scripts/scaffold.sh skills/skill-forge/tests/unit/test-scaffold.sh
git add skills/skill-forge/scripts/scaffold.sh skills/skill-forge/tests/unit/
git commit -m "feat(skill-forge): add scaffold.sh for variant-tree copy with placeholder substitution"
```

---

## Task 19: Write `scripts/commit-delivery.sh` and `scripts/prune-traces.sh`

**Files:**
- Create: `skills/skill-forge/scripts/commit-delivery.sh`
- Create: `skills/skill-forge/scripts/prune-traces.sh`

- [ ] **Step 1: Author `commit-delivery.sh` per guide §8.3**

```bash
#!/usr/bin/env bash
# Usage: commit-delivery.sh <target-skill-dir> <delivery-id> <change-summary>
# - git add <target>/ <target>/.review/
# - git commit -m "feat(skill-forge): delivery-<N>: <summary>"  (cofounder conventional-commit scope)
# - slug = python3 re-based slugify of <summary>[:40]
# - slug empty → YYYYMMDD fallback
# - git tag -a delivery-<N>-<slug> -m "<summary>"   (NEVER -f)
set -euo pipefail
TARGET="${1:?}"; N="${2:?}"; SUMMARY="${3:?}"

SLUG=$(python3 -c '
import sys, re
s = sys.argv[1][:40].lower()
s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
print(s)
' "$SUMMARY")
[ -z "$SLUG" ] && SLUG=$(date +%Y%m%d)
TAG="delivery-${N}-${SLUG}"

git add "$TARGET/" "$TARGET/.review/" 2>/dev/null || true
git commit -m "feat(skill-forge): delivery-${N}: ${SUMMARY}"
git tag -a "$TAG" -m "$SUMMARY"  # deliberately no -f per guide §8.3
echo "OK tag $TAG"
```

- [ ] **Step 2: Author `prune-traces.sh` per guide §8.8**

```bash
#!/usr/bin/env bash
# Usage: prune-traces.sh <target-skill-dir> <retention-rounds>
# - delete <target>/.review/traces/round-N/*.yml for N < (current_round - retention)
# - KEEP dispatch-log.jsonl in pruned rounds (never delete)
set -euo pipefail
TARGET="${1:?}"; RETENTION="${2:-20}"
CURRENT=$(ls -d "$TARGET"/.review/round-*/ 2>/dev/null | sed 's/.*round-//;s/\/$//' | sort -n | tail -1)
[ -z "$CURRENT" ] && exit 0
CUTOFF=$((CURRENT - RETENTION))
[ $CUTOFF -lt 1 ] && exit 0
for d in "$TARGET"/.review/traces/round-*/; do
  n=$(echo "$d" | sed 's/.*round-//;s/\/$//')
  if [ "$n" -le "$CUTOFF" ]; then
    find "$d" -name '*.yml' -type f -delete
  fi
done
echo "OK pruned rounds ≤ $CUTOFF"
```

- [ ] **Step 3: Commit**

```bash
chmod +x skills/skill-forge/scripts/commit-delivery.sh skills/skill-forge/scripts/prune-traces.sh
git add skills/skill-forge/scripts/commit-delivery.sh skills/skill-forge/scripts/prune-traces.sh
git commit -m "feat(skill-forge): add commit-delivery.sh + prune-traces.sh"
```

---

## Task 20: Write SKILL.md (orchestrator + mode routing + Snippet B/C embedded)

**Files:**
- Create: `skills/skill-forge/SKILL.md`

- [ ] **Step 1: Author SKILL.md per guide §21.1**

Required sections:

1. **Frontmatter**:
   ```yaml
   ---
   name: skill-forge
   version: 0.1.0
   description: |
     Use when the user wants to create a new generative skill (a Claude Code skill that produces artifacts from sparse intent) or evolve an existing one. Triggers: /cofounder:skill-forge, "create a skill", "generate a skill", "new generative skill", "make a skill that ...".
   ---
   ```

2. **Mode Routing table** per spec §2 + guide §21.1 + Snippet A

3. **Bootstrap Precheck** section per §21.1:
   ```markdown
   ## Bootstrap Precheck

   Every mode (including `--diagnose`) MUST call `scripts/git-precheck.sh` as the first action. Fail → exit; do not enter generate/review/revise.
   ```

4. **Core Contract** section — orchestrator-as-pure-dispatch statement; hard dependency declaration (git/bash/python3 per §21.0); skeleton immutability rule

5. **Orchestrator body** — inline this:
   - The Snippet C text verbatim from `common/snippets.md` (fingerprint: `dispatch-log-v1`)
   - The permitted-actions table (dispatch / fan-out / verdict-based decision / bookkeeping)
   - FORBIDDEN actions list (reading leaves, summarizing, computing verdicts, etc.)

6. **`--diagnose` Mode** implementation per Snippet B (pure script, no subagent dispatch)

7. **Model Tiers** section pointing to `common/config.yml`

8. **Configuration & Subagent Files** section pointing to `generate/`, `review/`, `revise/`, `shared/`

- [ ] **Step 2: Verify fingerprint present**

```bash
grep -q 'snippet-c-fingerprint: dispatch-log-v1' skills/skill-forge/SKILL.md
```

Expected: exit 0.

- [ ] **Step 3: Verify own checks pass**

```bash
skills/skill-forge/scripts/check-dispatch-log-snippet.sh skills/skill-forge/
skills/skill-forge/scripts/check-frontmatter.sh skills/skill-forge/
skills/skill-forge/scripts/check-mode-routing.sh skills/skill-forge/
```

Expected: all print `[]` and exit 0.

- [ ] **Step 4: Commit**

```bash
git add skills/skill-forge/SKILL.md
git commit -m "feat(skill-forge): add SKILL.md with mode routing + orchestrator body + Snippet B/C"
```

---

## Task 21: Write `generate/` sub-agent prompts (5 files)

**Files:**
- Create: `skills/skill-forge/generate/from-scratch.md`
- Create: `skills/skill-forge/generate/new-version.md`
- Create: `skills/skill-forge/generate/domain-consultant-subagent.md`
- Create: `skills/skill-forge/generate/planner-subagent.md`
- Create: `skills/skill-forge/generate/writer-subagent.md`
- Create: `skills/skill-forge/generate/in-generate-review.md`

Each sub-agent prompt file follows the same shape:
- First line: `<!-- snippet-d-fingerprint: ipc-ack-v1 -->`
- Then: Snippet D IPC contract verbatim from `common/snippets.md`
- Then: role-specific instructions

- [ ] **Step 1: `from-scratch.md`**

Mode-specific instructions for Generate with no target existing. Orchestrator reads this at mode entry. Contents: Round 0 flow per spec §7.1 (prepare-input → glossary-probe → consultant → planner → HITL → scaffold → writer fan-out → review → revise → converged).

- [ ] **Step 2: `new-version.md`**

Per spec §7.2. Reads existing target `README.md` + `CHANGELOG.md` + last-converged resolved issues. Forced full cross-review on first round (§10.2).

- [ ] **Step 3: `domain-consultant-subagent.md`** — per guide §6.2 + spec §3

Key contents:
- Starts with Snippet D fingerprint
- Role declaration: `role: domain_consultant` — only role with `user-interaction: true`
- Input contract: reads `.review/round-0/input.md` + `input-meta.yml` + `common/domain-glossary.md` + optionally `<target>/README.md` (NewVersion) + `common/skeleton/<variant>/README.md` (once R-002 resolved)
- Output contract: writes `.review/clarification/<timestamp>.yml` with R-001..R-007 resolved (exact schema from spec §3.1)
- Multi-turn loop: ask one question at a time until all ambiguous requirements → confirmed/deferred, OR user says `/proceed` / `/abort`
- Variant branching: after R-002 resolved, read `common/skeleton/<variant>/README.md` and replay summary to user
- ACK: `OK trace_id=<id> role=domain_consultant linked_issues=<ids>`
- FORBIDDEN: writing to artifact paths; including dialogue in Task return

- [ ] **Step 4: `planner-subagent.md`** — per guide §5 + spec §4

Key contents:
- Snippet D fingerprint header
- Dual mode: from-scratch → writes `{add: [...]}` plan over ~7–9 domain files; new-version → writes `{delete, modify, add, keep}` plan
- Input: `clarification.yml` + (new-version) existing target README + last-converged `.review/versions/<N>.md`
- Output: write `.review/round-<N>/plan.md` with the plan as YAML + rationale
- ACK: `OK trace_id=<id> role=planner linked_issues=<ids>`

- [ ] **Step 5: `writer-subagent.md`** — per guide §11.2 + spec §4

Key contents:
- Snippet D fingerprint header — MUST include the exact ACK model and blocker_scope taxonomy
- Input: `clarification.yml` + corresponding template from `common/templates/` + (new-version) target's `README.md`
- Output: 2 Writes per dispatch: (a) target file at final path, (b) `.review/round-<N>/self-reviews/<trace_id>.md` with PASS/FAIL checklist
- Blocker-scope taxonomy: list all 4 values (`global-conflict`, `cross-artifact-dep`, `needs-human-decision`, `input-ambiguity`) per CR-L09
- Self-review criteria: every CR that applies to the file being written
- Scope-in vs scope-out FAIL handling per guide §11.2
- ACK: `OK trace_id=<id> role=writer linked_issues=<ids> self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>`

- [ ] **Step 6: `in-generate-review.md`**

Per guide §11.2. The embedded self-review checklist writer ingests. For each CR that applies to the file being written, a one-line PASS/FAIL format with blocker_scope when FAIL.

- [ ] **Step 7: Verify fingerprints present in all 5 subagent files**

```bash
for f in generate/domain-consultant-subagent.md generate/planner-subagent.md generate/writer-subagent.md; do
  grep -q 'snippet-d-fingerprint: ipc-ack-v1' "skills/skill-forge/$f" || { echo "FAIL: $f"; exit 1; }
done
```

Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add skills/skill-forge/generate/
git commit -m "feat(skill-forge): add generate/ sub-agent prompts (consultant, planner, writer, modes)"
```

---

## Task 22: Write `review/` and `revise/` sub-agent prompts (4 files)

**Files:**
- Create: `skills/skill-forge/review/index.md`
- Create: `skills/skill-forge/review/cross-reviewer-subagent.md`
- Create: `skills/skill-forge/review/adversarial-reviewer-subagent.md`
- Create: `skills/skill-forge/revise/index.md`
- Create: `skills/skill-forge/revise/per-issue-reviser-subagent.md`

All sub-agent prompts start with `<!-- snippet-d-fingerprint: ipc-ack-v1 -->` and include Snippet D from `common/snippets.md`.

- [ ] **Step 1: `review/index.md`**

Mode-entry file loaded when `--review` is invoked. Contains phase A + phase B orchestration description; reads `scripts/run-checkers.sh`.

- [ ] **Step 2: `review/cross-reviewer-subagent.md`** — per guide §11 + §12.5.1

Key contents:
- Snippet D fingerprint + text
- Input contract per §12.5.1: `.review/round-N/skip-set.yml` MUST be consumed; only read leaves in `cross_reviewer_focus`
- Handles writer self-review FAIL rows: for each FAIL, either (a) create an `source: self-review-escalation` issue or (b) create a `dismissed_writer_fail` record
- Output: one `.review/round-N/issues/<issue-id>.md` per issue (N Writes per dispatch)
- ACK: `OK trace_id=<id> role=reviewer linked_issues=<comma-separated issue IDs>`
- FORBIDDEN: writing to `cross_reviewer_skip` leaves (unless issuing `CR-META-skip-violation`)

- [ ] **Step 3: `review/adversarial-reviewer-subagent.md`** — per guide §11.3

Key contents:
- Snippet D fingerprint + text
- Triggered on critical/error CRs during in-generate phase (per `config.yml.adversarial_review.triggered_by`)
- Attack angles (generator-specific): look for orchestrator leaks (SKILL.md telling main agent to read leaves), soft language in reviewer prompts, missing IPC footers, trace_id format drift
- Output contract same as cross-reviewer; `source: adversarial-reviewer`; `reviewer_variant: adversarial` in dispatch-log

- [ ] **Step 4: `revise/index.md` + `revise/per-issue-reviser-subagent.md`** — per guide §11 + §14

Per-issue reviser key contents:
- Snippet D fingerprint + text
- Input: one issue file + the target leaf referenced in `issue.file` + **resolved issues history** (regression protection per §14.1, up to `regression_gate.max_injected_resolved`)
- Skeleton paths are tool-permission-denied; if issue points at a skeleton file, reviser must emit a `CR-META-skip-violation` meta-issue back, not attempt the fix
- Output: overwrite the target leaf with revised content
- ACK: `OK trace_id=<id> role=reviser linked_issues=<id of issue being resolved>`

- [ ] **Step 5: Verify**

```bash
for f in review/cross-reviewer-subagent.md review/adversarial-reviewer-subagent.md revise/per-issue-reviser-subagent.md; do
  grep -q 'snippet-d-fingerprint: ipc-ack-v1' "skills/skill-forge/$f" || { echo "FAIL: $f"; exit 1; }
done
```

- [ ] **Step 6: Commit**

```bash
git add skills/skill-forge/review/ skills/skill-forge/revise/
git commit -m "feat(skill-forge): add review/ + revise/ sub-agent prompts"
```

---

## Task 23: Write `shared/summarizer-subagent.md` and `shared/judge-subagent.md`

**Files:**
- Create: `skills/skill-forge/shared/summarizer-subagent.md`
- Create: `skills/skill-forge/shared/judge-subagent.md`

Both start with `<!-- snippet-d-fingerprint: ipc-ack-v1 -->` + Snippet D.

- [ ] **Step 1: `summarizer-subagent.md`** — per guide §10.4

Key contents:
- Snippet D + fingerprint
- Multiple-phase behavior: (a) per-round — write `<target>/.review/round-<N>/index.md` + update target-leaf index pages + round-N coverage field; (b) on converged — write `.review/versions/<N>.md` + integrally rewrite `<target>/CHANGELOG.md` (reverse chronological) + write `.review/metrics/README.md` trend row + call `commit-delivery.sh`
- ACK: `OK trace_id=<id> role=summarizer linked_issues=[]`

- [ ] **Step 2: `judge-subagent.md`** — per guide §15

Key contents:
- Snippet D + fingerprint
- Inputs (read only, per §15.2): `.review/round-N/index.md` frontmatter + `.review/round-N/issues/*.md` frontmatter (NOT bodies) + `.review/round-(N-k)/index.md` for the last `recent_rounds_window` rounds
- Outputs one of 5 verdicts per §15.1 + next_action
- Hard condition for converged: `sum(fail_count where role=writer) == 0` + `coverage_percent == 100` + no `critical`/`error` issues + zero regressed
- Writes `.review/round-N/verdict.yml`
- ACK: `OK trace_id=<id> role=judge linked_issues=[]`

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/shared/
git commit -m "feat(skill-forge): add shared/summarizer + shared/judge sub-agent prompts"
```

---

## Task 24: Build `common/skeleton/document/` variant tree

**Files:**
- Create: full tree under `skills/skill-forge/common/skeleton/document/` matching guide §7.1

The document variant is the baseline. Copy the structure we built for skill-forge itself (minus the skeleton directory — no recursion), with `{{placeholder}}` substitutions where domain-specific content is expected.

- [ ] **Step 1: Build tree**

Files that go in `common/skeleton/document/`:

```
SKILL.md                            # template with {{SKILL_NAME}}, {{SKILL_DESCRIPTION}}, {{ARTIFACT_ROOT}} placeholders
common/
  config.yml                        # copy of skill-forge's, swap model_tier_defaults per variant if needed
  review-criteria.md                # {{DOMAIN_FILL}} — writer authors
  domain-glossary.md                # {{DOMAIN_FILL}}
  templates/artifact-template.md    # {{DOMAIN_FILL}}
scripts/
  git-precheck.sh                   # verbatim from skill-forge's
  prepare-input.sh                  # verbatim
  glossary-probe.sh                 # verbatim
  run-checkers.sh                   # verbatim
  extract-criteria.sh               # verbatim
  check-frontmatter.sh              # verbatim
  check-index-consistency.sh        # verbatim
  check-criteria-consistency.sh     # verbatim
  check-changelog-consistency.sh    # verbatim
  build-depgraph.sh                 # verbatim
  commit-delivery.sh                # placeholder for target skill's scope; substitute {{SKILL_NAME}}
  prune-traces.sh                   # verbatim
  metrics-aggregate.sh              # verbatim (sha-pinned)
  lib/aggregate.py                  # verbatim (sha-pinned)
generate/
  from-scratch.md                   # standard shape, {{DOMAIN_FILL}} for domain logic
  new-version.md                    # same
  domain-consultant-subagent.md     # {{DOMAIN_FILL}} prompt authored by writer
  planner-subagent.md               # {{DOMAIN_FILL}}
  writer-subagent.md                # {{DOMAIN_FILL}}
  in-generate-review.md             # {{DOMAIN_FILL}}
review/
  index.md                          # standard
  cross-reviewer-subagent.md        # {{DOMAIN_FILL}}
  adversarial-reviewer-subagent.md  # {{DOMAIN_FILL}}
revise/
  index.md                          # standard
  per-issue-reviser-subagent.md     # {{DOMAIN_FILL}}
shared/
  summarizer-subagent.md            # standard
  judge-subagent.md                 # standard
```

Files marked `{{DOMAIN_FILL}}` contain the literal marker line `<!-- DOMAIN_FILL: see generate/writer-subagent.md for population -->` at the top; `scaffold.sh` leaves these alone (writers will write them entirely in the generate phase).

Files marked "verbatim" are copies of skill-forge's. Use a helper script to generate the skeleton:

```bash
mkdir -p skills/skill-forge/common/skeleton/document/{common/templates,scripts/lib,generate,review,revise,shared}

# Copy verbatim scripts
for s in git-precheck prepare-input glossary-probe run-checkers extract-criteria check-frontmatter check-index-consistency check-criteria-consistency check-changelog-consistency build-depgraph prune-traces metrics-aggregate; do
  cp skills/skill-forge/scripts/$s.sh skills/skill-forge/common/skeleton/document/scripts/ 2>/dev/null || true
done
cp skills/skill-forge/scripts/lib/aggregate.py skills/skill-forge/common/skeleton/document/scripts/lib/

# Author SKILL.md template with {{PLACEHOLDERS}}
# Author config.yml template with {{SKILL_NAME}} etc.
# Stub {{DOMAIN_FILL}} markers in domain-specific files
```

- [ ] **Step 2: Verify the skeleton would pass skill-forge's own checks (except DOMAIN_FILL ones)**

The document skeleton is a "template" — it's not a complete target skill. CR-L06 / CR-L07 / CR-L09 should fail on `{{DOMAIN_FILL}}` stubs (those are filled by writers). `scaffold.sh` must accept un-filled skeleton as valid starting state.

```bash
# after skeleton authored
skills/skill-forge/scripts/check-skill-structure.sh skills/skill-forge/common/skeleton/document/
```

Expected: `[]` (directory structure complete).

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/common/skeleton/document/
git commit -m "feat(skill-forge): add common/skeleton/document variant tree"
```

---

## Task 25: Build `common/skeleton/code/`, `schema/`, `hybrid/` variants (deltas)

**Files:**
- Create: `skills/skill-forge/common/skeleton/code/` (deltas from `document/`)
- Create: `skills/skill-forge/common/skeleton/schema/` (deltas from `document/`)
- Create: `skills/skill-forge/common/skeleton/hybrid/` (deltas from `document/`)

Per guide Appendix F, the variants share most of `document/`'s structure but differ in:

| Variant | Key deltas |
|---|---|
| code | `run-checkers.sh` includes compile/lint CRs (tsc/ruff/golangci-lint); `artifact-template.md` shows `__init__.py` / barrel file patterns; CR-S02 leaf limit stays 300 lines but judges function/class boundaries not sections |
| schema | Reviewer prompts include breaking-change detection; `CHANGELOG.md` format has per-version compat notes; run-checkers includes `jsonschema validate` |
| hybrid | All three variants' checkers run; per-file-type routing in `run-checkers.sh` |

- [ ] **Step 1: Author each variant's deltas**

Start from `document/` as base, then author variant-specific files:
- `code/`: replace `check-frontmatter.sh` with `check-lint.sh` wrapper (invokes tool based on detected language); update `artifact-template.md` example
- `schema/`: add `check-breaking-changes.sh` stub; update `CHANGELOG.md` template in skeleton
- `hybrid/`: extended `run-checkers.sh` with file-type dispatch

For v1, each variant can be partially fleshed — the skeleton tree exists and is complete structurally, but checker scripts can be stubs that emit `[]` (allowing skill-forge to generate non-document skills that a user then fleshes out manually).

- [ ] **Step 2: Verify all 4 variants have complete structural trees**

```bash
for v in document code schema hybrid; do
  skills/skill-forge/scripts/check-skill-structure.sh skills/skill-forge/common/skeleton/$v/ > /dev/null 2>&1 || { echo "FAIL: $v"; exit 1; }
done
```

- [ ] **Step 3: Commit**

```bash
git add skills/skill-forge/common/skeleton/
git commit -m "feat(skill-forge): add code/schema/hybrid variant skeletons (deltas from document)"
```

---

## Task 26: Write templates in `common/templates/`

**Files:**
- Create: `skills/skill-forge/common/templates/skill-md-template.md`
- Create: `skills/skill-forge/common/templates/review-criteria-template.md`
- Create: `skills/skill-forge/common/templates/writer-subagent-template.md`
- Create: `skills/skill-forge/common/templates/cross-reviewer-template.md`
- Create: `skills/skill-forge/common/templates/artifact-template.md`

These are the templates the writer-subagent ingests when filling `{{DOMAIN_FILL}}` markers.

- [ ] **Step 1: Author each template**

Each template has:
- A "shape reference" section — what the output file's structure must look like
- "Content requirements" — what to fill in (data flow, clarification.yml fields to use)
- ≥ 1 positive example + ≥ 1 negative example per CR-L06

- [ ] **Step 2: Commit**

```bash
git add skills/skill-forge/common/templates/
git commit -m "feat(skill-forge): add writer templates for the 5 domain-fill files"
```

---

## Task 27: Write bootstrap fixture and `tests/run-tests.sh`

**Files:**
- Create: `skills/skill-forge/tests/bootstrap/input.md`
- Create: `skills/skill-forge/tests/run-tests.sh`

- [ ] **Step 1: Author `tests/bootstrap/input.md`** per spec §8.1:

```markdown
# Bootstrap Test Fixture

/cofounder:skill-forge "I want a skill that generates generative Claude Code skills from sparse user intent. The artifact is a skill directory at skills/<name>/ following the 8-role generative-skill guide. Input is the user's description of the target skill's purpose and artifact domain. Supports 4 artifact variants: document, code, schema, hybrid. Reviews the generated skill against ~24 structural and semantic criteria."
```

- [ ] **Step 2: Author `tests/run-tests.sh`**:

```bash
#!/usr/bin/env bash
# run-tests.sh — zero-deps test harness
# Usage: ./run-tests.sh [--unit | --bootstrap | all]
# Env: REGEN=1 to rewrite expected/ golden files
set -euo pipefail
MODE="${1:-unit}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "$MODE" = "unit" ] || [ "$MODE" = "all" ]; then
  echo "=== Unit tests ==="
  for t in "$HERE"/unit/test-*.sh; do
    echo "  $t"; "$t" || exit 1
  done
fi

if [ "$MODE" = "bootstrap" ] || [ "$MODE" = "all" ]; then
  echo "=== Bootstrap test (generates a skill and compares) ==="
  # TODO(task 28): implement full bootstrap harness invoking skill-forge
  echo "  bootstrap harness pending (Task 28)"
fi

echo "ALL OK"
```

- [ ] **Step 3: Run the unit-test suite**

```bash
chmod +x skills/skill-forge/tests/run-tests.sh
skills/skill-forge/tests/run-tests.sh unit
```

Expected: every `test-*.sh` passes.

- [ ] **Step 4: Commit**

```bash
git add skills/skill-forge/tests/
git commit -m "feat(skill-forge): add bootstrap fixture + run-tests.sh harness"
```

---

## Task 28: End-to-end bootstrap validation

**Files:**
- Create: `skills/skill-forge/tests/bootstrap/expected/directory-manifest.txt`
- Create: `skills/skill-forge/tests/bootstrap/expected/structural-checks.txt`

This task validates the whole skill works. Requires skill-forge to be runnable via the Claude Code harness.

- [ ] **Step 1: Run skill-forge on the bootstrap fixture**

```bash
cd /Users/wangzw/workspace/cofounder
claude --plugin-dir . -p "$(cat skills/skill-forge/tests/bootstrap/input.md)"
```

Target expected at something like `skills/skill-forge-generated/`.

- [ ] **Step 2: Capture golden**

```bash
find skills/skill-forge-generated/ -type f | sort > skills/skill-forge/tests/bootstrap/expected/directory-manifest.txt
skills/skill-forge/scripts/run-checkers.sh skills/skill-forge-generated/ 1 > skills/skill-forge/tests/bootstrap/expected/structural-checks.txt
```

- [ ] **Step 3: Assert convergence metrics**

Read `.review/metrics/delivery-1.metrics.yml` and assert:
- `rounds_to_convergence ≤ 3`
- `cost.total_usd ≤ 0.5`
- No `oscillating` / `diverging` verdict in the `round-N.yml` sequence

- [ ] **Step 4: Self-review validates**

```bash
claude --plugin-dir . -p "/cofounder:skill-forge --review --target skills/skill-forge"
```

Expected verdict: `converged`. If not, iterate (revise the prompts that fail).

- [ ] **Step 5: Commit golden files**

```bash
git add skills/skill-forge/tests/bootstrap/expected/
git commit -m "test(skill-forge): capture bootstrap golden files (directory-manifest + structural-checks)"
```

---

## Task 29: Update `CLAUDE.md` with skill-forge in the pipeline

**Files:**
- Modify: `CLAUDE.md:13-24` (the pipeline paragraph)

- [ ] **Step 1: Edit CLAUDE.md**

Add skill-forge to the Pipeline section. Current pipeline:

```
Idea → /cofounder:prd-analysis → /cofounder:system-design → /cofounder:autoforge → /cofounder:go-to-market → Market-Ready Business
```

skill-forge is orthogonal (a meta-skill). Add a section below the main pipeline:

```markdown
## Meta-Skill

`/cofounder:skill-forge` is a generative skill that generates new generative skills per the generative-skill design guide. It is orthogonal to the main pipeline — use it when you want to add a new skill to cofounder (or anywhere else) that produces artifacts from sparse input.

Triggers: `/cofounder:skill-forge "I want a skill that ..."`, `/cofounder:skill-forge --review --target skills/<name>`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: register skill-forge as meta-skill in CLAUDE.md pipeline"
```

---

## Self-Review

Running the self-review checklist:

**1. Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §1.1 directory shape | Task 1 |
| §1.2 scaffolding + writer scope | Tasks 18, 24, 26 |
| §2 CLI modes | Task 20 (SKILL.md mode routing) |
| §3 domain-consultant scope + glossary | Tasks 6, 21 |
| §4 roles + permissions | Tasks 4, 20–23 |
| §5 24 criteria | Task 5 |
| §6.1 tier-1 scripts | Task 2 |
| §6.1 tier-2 scripts | Tasks 7, 8, 15, 16, 17, 19 |
| §6.1 tier-3 scripts | Tasks 9–14 |
| §7.1 FromScratch flow | Tasks 20, 21 (SKILL.md + from-scratch.md) |
| §7.2 NewVersion flow | Task 21 (new-version.md) |
| §8 self-bootstrap CI | Tasks 27, 28 |
| §9 open items | Resolved: (1) skeleton variants in Tasks 24–25; (2) Snippet D text in Task 3; (3) glossary seeds in Task 6; (4) writer templates in Task 26; (5) golden regen in Task 28 |

All spec sections covered.

**2. Placeholder scan:**

- "TBD" / "TODO": only `TODO(task 28)` in Task 27 Step 2 — intentional forward-reference to Task 28 where the bootstrap harness is fleshed out.
- Task 24/25 say "can be stubs" for non-document variants — this is an explicit scope call-out (stubs are valid v1 output; users flesh out later), not a placeholder.
- Task 26 step 1 says "Author each template" without inline content — this is the one weak spot, but template authoring requires the variant trees to exist first; the template shape is defined in spec §9 open item 4, and each writer template's requirements are pinned by CR-L06/L07/L09.

**3. Type consistency:**

- `trace_id` format `R<N>-<role-letter>-<nnn>` with letters `C/P/W/V/R/S/J` is consistent across Tasks 3, 12, 21, 22.
- `<!-- snippet-c-fingerprint: dispatch-log-v1 -->` and `<!-- snippet-d-fingerprint: ipc-ack-v1 -->` consistent across Tasks 3, 10, 11, 20, 21, 22, 23.
- `{{placeholder}}` substitution (Task 18 scaffold.sh) consistent with Task 24/25 skeleton markers.
- Role names underscore-form (`domain_consultant`, `tool_permissions`) in config.yml vs hyphen-form (`domain-consultant-subagent.md`) in file names — matches guide's naming convention §3.8.

No inconsistencies found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-24-skill-forge.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
