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
| `domain_consultant` | 1 write | `.review/round-<N>/clarification.yml` |

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

# per-issue-reviser-subagent — Reviser Role for {{SKILL_NAME}}

<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->

**Role**: `reviser` (`R` in trace_id). Scoped to ONE artifact leaf per dispatch. Reads all open
issues for that leaf, applies fixes, and writes the revised leaf.

<!-- TODO: describe domain-specific revision discipline for {{SKILL_NAME}}'s artifacts -->
<!-- TODO: specify regression-protection protocol for this artifact type -->
<!-- TODO: describe skeleton-protection protocol -->
<!-- TODO: list any domain-specific forbidden revision patterns -->

### Revision Discipline

- Fix ONLY what the issue text describes. Do not make unrequested improvements.
- Read every issue body before applying any fix.
- Preserve unrelated content exactly.
- **FORBIDDEN** to touch skeleton paths (`scripts/metrics-aggregate.sh`, `scripts/lib/aggregate.py`).
- **FORBIDDEN** to re-introduce previously resolved issues.
- **FORBIDDEN** to touch any file other than the one target leaf assigned by the orchestrator.

### ACK Format

```
OK trace_id=<trace_id> role=reviser linked_issues=<comma-separated IDs of issues being resolved>
```

Return this ACK as the **single and final line** of the Task return. Nothing after it.
