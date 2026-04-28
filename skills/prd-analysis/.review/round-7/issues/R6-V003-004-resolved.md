---
id: R6-V003-004
round: 7
file: scripts/lib/aggregate.py
criterion_id: CR-L11
severity: warning
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V003-004 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is regex-vs-canonical-CR-S10 cross-reference, not the narrow conflicts_with pair check): aggregate.py `TRACE_ID_RE` used permissive `[A-Za-z]` while check-trace-id-format.sh used canonical `[CPWVRSJ]`.

Round-7 verification: aggregate.py line 241 now uses `TRACE_ID_RE = re.compile(r"\btrace_id:\s*(R\d+-[CPWVRSJ]-\d{3})(?!\d)")` — matches CR-S10 canonical pattern and check-trace-id-format.sh's VALID_RE. Drift is documented in shared-scripts-manifest.yml (lines 4-5: "TRACE_ID_RE tightened from `[A-Za-z]-\d+` to canonical `[CPWVRSJ]-\d{3}` per CR-S10 / R6-V003-004"). CR-L11 cross-reference consistency restored.
