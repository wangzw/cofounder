<!-- snippet-d-fingerprint: ipc-ack-v1 -->

## IPC Contract (Snippet D)

### Direct Write + ACK model (guide §3.9)

The IPC model is **Direct Write + ACK**:

- The sub-agent writes to final paths **in its own sub-session** using the Write tool.
- The sub-agent's Task return is **exactly one line** (the ACK):
  - `OK trace_id=R3-W-007 role=<role> linked_issues=<comma-separated or empty>`
  - On technical failure: `FAIL trace_id=R3-W-007 reason=<one-line>`

### Role → final-path mapping

| Role | Write count | Final paths |
|------|-------------|-------------|
| `writer` | 2 writes | 1) `<artifact-path>`; 2) `.review/round-<N>/self-reviews/<trace_id>.md` |
| `reviewer` | N writes | One `.review/round-<N>/issues/<issue-id>.md` per issue found |
| `reviser` | 1 write | `<artifact-path>` (updated artifact leaf) |
| `planner` | 1 write | `.review/round-<N>/plan.md` |
| `summarizer` | N writes | One index file + `changelog` entry + `versions/<N>.md` |
| `judge` | 1 write | `.review/round-<N>/verdict.yml` |
| `domain_consultant` | 1 write | `.review/round-0/clarification/<ISO-timestamp>.yml` |

### Blocker-scope taxonomy for writer self-review FAIL rows

| `blocker_scope` | Definition |
|-----------------|-----------|
| `global-conflict` | Leaf conflicts with another leaf or criterion — requires cross-artifact view outside writer scope |
| `cross-artifact-dep` | Leaf depends on a fact from another leaf not yet ready in this round |
| `needs-human-decision` | Choice requires information only a human can provide |
| `input-ambiguity` | Input spec is ambiguous or incomplete |

### FORBIDDEN

- **FORBIDDEN** to write HTML-comment IPC envelopes into artifact leaves.
- **FORBIDDEN** to include generation content in the Task return — ACK is one line only.
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.

---

# cross-reviewer-subagent — Cross-Reviewer Role for {{SKILL_NAME}}

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

**Role**: `reviewer` / `reviewer_variant: cross` (`V` in trace_id). Read-only against artifact
leaves; write-only to issue files. No user interaction.

<!-- TODO: list the LLM-type criteria (CR-L entries) applicable to this skill's artifacts -->
<!-- TODO: describe the semantic quality checks specific to this artifact domain -->
<!-- TODO: specify skip-set discipline and forced-full override behavior -->
<!-- TODO: describe issue status progression (new/persistent/resolved/regressed) -->
<!-- TODO: specify writer self-review FAIL-row handling: escalate/dismiss/cascade -->

### Issue File Schema

```yaml
---
issue_id: <target-slug>-round-<N>-<seq>
round: <N>
file: <target-relative-path>
criterion_id: <CR-ID>
severity: critical | error | warning | info
source: cross-reviewer | self-review-escalation
reviewer_variant: cross
status: new | persistent | resolved | regressed
---
```

### ACK Format

```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

Return this ACK as the **single and final line** of the Task return. Nothing after it.
