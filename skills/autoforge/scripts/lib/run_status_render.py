"""Render run-status.md and DAG mermaid from a run-state.json document.

Pure: state in, markdown out. No I/O.
"""
from __future__ import annotations

from run_state import ready_set_planning, ready_set_execution  # type: ignore

# Status -> mermaid classDef name. Keep this list in sync with EXEC_STATES
# in run_state.py.
_STATUS_TO_CLASS = {
    "pending": "pending",
    "ready": "ready",
    "running": "running",
    "approved": "approved",
    "integrating": "integrating",
    "merged": "merged",
    "cancelled": "cancelled",
    "needs_patch": "needs_patch",
    "failed": "failed",
}

_CLASS_DEFS = """  classDef pending fill:#eee,stroke:#999
  classDef ready fill:#fc9,stroke:#c60
  classDef running fill:#9cf,stroke:#06c
  classDef approved fill:#cf9,stroke:#690
  classDef integrating fill:#9fc,stroke:#069
  classDef merged fill:#9f9,stroke:#060
  classDef cancelled fill:#ccc,stroke:#666
  classDef needs_patch fill:#f99,stroke:#c00
  classDef failed fill:#f66,stroke:#900"""


def _count_by_status(modules: dict) -> dict[str, int]:
    out: dict[str, int] = {}
    for m in modules.values():
        s = m["exec_status"]
        out[s] = out.get(s, 0) + 1
    return out


def render_dag_mermaid(state: dict) -> str:
    """Render a mermaid flowchart with nodes colored by exec_status."""
    modules = state["modules"]
    lines: list[str] = ["```mermaid", "flowchart LR"]
    for mid, m in sorted(modules.items()):
        cls = _STATUS_TO_CLASS.get(m["exec_status"], "pending")
        if not m["deps"]:
            lines.append(f"  {mid}:::{cls}")
        for d in m["deps"]:
            d_cls = _STATUS_TO_CLASS.get(modules[d]["exec_status"], "pending")
            lines.append(f"  {d}:::{d_cls} --> {mid}:::{cls}")
    lines.append(_CLASS_DEFS)
    lines.append("```")
    return "\n".join(lines)


def render_status_md(state: dict) -> str:
    """Render run-status.md from current state."""
    sched = state["scheduler"]
    modules = state["modules"]
    inflight = state["inflight"]
    p_cap = sched["max_planners"]
    m_cap = sched["max_modules"]
    rp = ready_set_planning(state)
    re_ = ready_set_execution(state)
    by_status = _count_by_status(modules)

    # Tier rollup: per tier, count modules by exec_status.
    tiers: dict[int, dict[str, int]] = {}
    for m in modules.values():
        t = tiers.setdefault(m["tier"], {})
        t[m["exec_status"]] = t.get(m["exec_status"], 0) + 1

    out: list[str] = []
    out.append(f"# Autoforge Run Status\n")
    out.append(f"## Snapshot @ {state.get('last_event_at') or '(never)'}\n")
    out.append(
        f"In-flight Planners: {len(inflight['planners'])} / {p_cap} cap"
    )
    for mid in inflight["planners"]:
        out.append(f"  - {mid}")
    out.append("")
    out.append(
        f"In-flight Modules: {len(inflight['modules'])} / {m_cap} cap"
    )
    for mid in inflight["modules"]:
        out.append(f"  - {mid}  ({modules[mid]['exec_status']})")
    out.append("")
    out.append(
        f"In-flight Integration Testers: {len(inflight['integration_testers'])}"
    )
    for mid in inflight["integration_testers"]:
        out.append(f"  - {mid}")
    out.append("")
    out.append(f"Ready (planning): {rp}")
    out.append(f"Ready (execution): {re_}")
    out.append("")
    out.append("Tier progress:")
    for tier in sorted(tiers):
        parts = ", ".join(f"{k}={v}" for k, v in sorted(tiers[tier].items()))
        out.append(f"  Tier {tier}: {parts}")
    out.append("")
    out.append("Totals by status: " + ", ".join(
        f"{k}={v}" for k, v in sorted(by_status.items())
    ))
    out.append("")
    if state.get("current_revision"):
        out.append(f"Current revision: {state['current_revision']}")
    else:
        out.append("Current revision: none")
    out.append("")
    out.append("## DAG\n")
    out.append(render_dag_mermaid(state))
    return "\n".join(out) + "\n"
