"""run-state.json reader/writer and ready-set computation.

Single source of truth for autoforge's event-driven scheduler state.
Shell wrappers (run-state-init.sh, run-state-update.sh) call into this
module; checkers (check-scheduler-state.sh) read it directly.

Schema version 1. Bump VERSION and add a migration if the on-disk
shape changes.
"""
from __future__ import annotations

import json
import os

VERSION = 1

# Tier and tier-1 special handling are computed once at init time.
# Subsequent operations are pure state transitions.

PLAN_STATES = {"pending", "planning", "planned", "revising"}
EXEC_STATES = {
    "pending", "ready", "running", "approved",
    "integrating", "merged", "cancelled", "needs_patch", "failed",
}


def _topological_tier(modules: list[dict]) -> dict[str, int]:
    """Return module-id -> tier (1-indexed BFS layer over the dep DAG)."""
    by_id = {m["id"]: m for m in modules}
    tier: dict[str, int] = {}

    def resolve(mid: str, seen: set[str]) -> int:
        if mid in tier:
            return tier[mid]
        if mid in seen:
            raise ValueError(f"cycle in module DAG involving {mid}")
        seen = seen | {mid}
        deps = by_id[mid].get("deps", [])
        if not deps:
            tier[mid] = 1
        else:
            for d in deps:
                if d not in by_id:
                    raise ValueError(f"module {mid!r} has dep {d!r} which is not in the module list")
            tier[mid] = 1 + max(resolve(d, seen) for d in deps)
        return tier[mid]

    for m in modules:
        resolve(m["id"], set())
    return tier


def _closure(modules: list[dict]) -> dict[str, list[str]]:
    """Transitive deps for each module, in topological order.

    Delegates to _topological_tier first so any cycle raises a descriptive
    ValueError before this function starts its own walk.
    """
    # Cycle detection is fully handled by _topological_tier; any cycle
    # raises ValueError with a clear message before we recurse below.
    _topological_tier(modules)
    by_id = {m["id"]: m for m in modules}
    closure: dict[str, list[str]] = {}

    def resolve(mid: str) -> list[str]:
        if mid in closure:
            return closure[mid]
        out: list[str] = []
        seen: set[str] = set()
        for d in by_id[mid].get("deps", []):
            if d not in by_id:
                raise ValueError(f"module {mid!r} has dep {d!r} which is not in the module list")
            for sub in resolve(d):
                if sub not in seen:
                    seen.add(sub)
                    out.append(sub)
            if d not in seen:
                seen.add(d)
                out.append(d)
        closure[mid] = out
        return out

    for m in modules:
        resolve(m["id"])
    return closure


def create_initial_state(modules: list[dict], *, scheduler: dict | None = None) -> dict:
    """Build a fresh run-state.json document from a Module Index.

    `modules`: list of dicts each having `id` (str) and `deps` (list[str]).
    `scheduler`: optional override for caps; defaults match config.yml.
    """
    scheduler = scheduler or {
        "max_planners": 3,
        "max_modules": 6,
        "idle_timeout_minutes": 30,
        "status_commit_every_k": 5,
        "status_commit_every_seconds": 60,
    }
    tiers = _topological_tier(modules)
    closures = _closure(modules)
    out_modules: dict[str, dict] = {}
    for m in modules:
        mid = m["id"]
        out_modules[mid] = {
            "deps": list(m.get("deps", [])),
            "closure": closures[mid],
            "tier": tiers[mid],
            "plan_status": "pending",
            "exec_status": "pending",
            "agent_handle": None,
            "retry_history": [],
            "report_paths": {},
        }
    return {
        "version": VERSION,
        "scheduler": scheduler,
        "modules": out_modules,
        "inflight": {"planners": [], "modules": [], "integration_testers": []},
        "human_gates": {
            "G0_approved": False,
            "G1_skeleton_approved": False,
            "G3_acceptance_approved": False,
        },
        "revisions": [],
        "current_revision": None,
        "frozen_at": None,
        "last_event_at": None,
    }


def load_state(path: str) -> dict:
    """Load and return the run-state document at `path`. Propagates FileNotFoundError / json.JSONDecodeError."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_state(path: str, state: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def ready_set_planning(state: dict) -> list[str]:
    """Modules whose plan_status=pending AND closure.all(plan_status=planned).

    Sorted by tier asc, then by module id (stable).
    """
    modules = state["modules"]
    ready: list[tuple[int, str]] = []
    for mid, m in modules.items():
        if m["plan_status"] != "pending":
            continue
        if all(modules[d]["plan_status"] == "planned" for d in m["closure"]):
            ready.append((m["tier"], mid))
    ready.sort()
    return [mid for _, mid in ready]


def ready_set_execution(state: dict) -> list[str]:
    """Modules whose plan_status=planned AND exec_status in {pending, needs_patch}
    AND closure.all(exec_status=merged).

    Priority order: needs_patch > pending; then tier asc; then module id.
    """
    modules = state["modules"]
    ready: list[tuple[int, int, str]] = []
    for mid, m in modules.items():
        if m["plan_status"] != "planned":
            continue
        exec_status = m["exec_status"]
        if exec_status not in ("pending", "needs_patch"):
            continue
        if not all(modules[d]["exec_status"] == "merged" for d in m["closure"]):
            continue
        priority = 0 if exec_status == "needs_patch" else 1
        ready.append((priority, m["tier"], mid))
    ready.sort()
    return [mid for _, _, mid in ready]


def filter_modules_by_scope(state: dict, scope: str) -> list[str]:
    """Return module ids matching a --scope argument.

    Supported scopes:
      - 'all' (default)
      - 'tier-N' (e.g. 'tier-1')
      - 'module-M-NNN' (e.g. 'module-M-007')
    """
    modules = state["modules"]
    if scope == "all":
        return list(modules.keys())
    if scope.startswith("tier-"):
        try:
            n = int(scope.removeprefix("tier-"))
        except ValueError:
            raise ValueError(f"invalid scope: {scope}")
        return [mid for mid, m in modules.items() if m["tier"] == n]
    if scope.startswith("module-"):
        mid = scope.removeprefix("module-")
        if mid not in modules:
            raise ValueError(f"scope module not in state: {mid}")
        return [mid]
    raise ValueError(f"unknown scope: {scope}")
