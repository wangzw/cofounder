#!/usr/bin/env python3
"""
aggregate.py — python core for metrics-aggregate.sh.

Reads:
  - <review-dir>/traces/round-<N>/dispatch-log.jsonl         (role/tier/trace_id)
  - <harness-dir>/**/*.jsonl                                 (usage events)
  - <config.yml>                                             (pricing, tier mapping)

Writes:
  - <review-dir>/metrics/round-<N>.metrics.yml
  - <review-dir>/metrics/delivery-<N>.metrics.yml
  - <review-dir>/metrics/since-<iso>.metrics.yml
  (<review-dir>/metrics/README.md trend rendering is the summarizer's job —
   this script intentionally does not touch it; see guide §G.4.)

JOIN strategy (two-tier, documented in README):
  1. Primary: prompts sent by orchestrator include a marker `trace_id: R<N>-<R>-<nnn>`
     in the user message. Assistant usage events that follow that user turn (until
     the next trace-tagged user turn) are attributed to that trace.
  2. Fallback: if no trace_id markers are found, match events by model + timestamp
     window [dispatched_at, returned_at] from dispatch-log.

Zero external deps (stdlib only). YAML emitted by a small hand-rolled writer —
the output schema is a flat subset (strings, ints, floats, lists of scalars,
nested dicts) which is trivial to serialize safely.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Set, Tuple

# ---------- util ----------

def parse_iso(s: str) -> _dt.datetime:
    # Accept "Z" suffix
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return _dt.datetime.fromisoformat(s)


def warn(msg: str) -> None:
    print(f"warn: {msg}", file=sys.stderr)


def die(code: int, msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


# ---------- minimal YAML writer ----------
# Handles our flat schema only: dict | list | str | int | float | bool | None.
# Strings are quoted with double quotes when they contain special chars.

_SAFE_STR = re.compile(r"^[A-Za-z0-9_./:+@-]+$")

def _yaml_scalar(v) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float):
            # Avoid scientific notation for small numbers; round to 6 dp
            return f"{v:.6f}".rstrip("0").rstrip(".") or "0"
        return str(v)
    s = str(v)
    if s == "" or not _SAFE_STR.match(s) or s.lower() in ("true", "false", "null", "yes", "no"):
        esc = s.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{esc}"'
    return s


def yaml_dump(obj, indent: int = 0) -> str:
    pad = "  " * indent
    lines: List[str] = []
    if isinstance(obj, dict):
        if not obj:
            return "{}\n"
        for k, v in obj.items():
            key = _yaml_scalar(k)
            if isinstance(v, dict) and v:
                lines.append(f"{pad}{key}:")
                lines.append(yaml_dump(v, indent + 1).rstrip("\n"))
            elif isinstance(v, list) and v:
                lines.append(f"{pad}{key}:")
                for item in v:
                    if isinstance(item, dict):
                        sub = yaml_dump(item, indent + 2).rstrip("\n").splitlines()
                        # first line gets "- ", rest indented
                        if sub:
                            lines.append(f"{pad}  - {sub[0].lstrip()}")
                            for sl in sub[1:]:
                                lines.append(sl)
                        else:
                            lines.append(f"{pad}  - {{}}")
                    else:
                        lines.append(f"{pad}  - {_yaml_scalar(item)}")
            elif isinstance(v, list):
                lines.append(f"{pad}{key}: []")
            elif isinstance(v, dict):
                lines.append(f"{pad}{key}: {{}}")
            else:
                lines.append(f"{pad}{key}: {_yaml_scalar(v)}")
    else:
        lines.append(f"{pad}{_yaml_scalar(obj)}")
    return "\n".join(lines) + "\n"


# ---------- minimal YAML reader (config only) ----------
# Supports what config.example.yml uses: nested dicts, scalars, simple lists.
# Deliberately tiny — if your config is fancier, swap in pyyaml.

def yaml_load(path: str) -> dict:
    if not path or not os.path.isfile(path):
        return {}
    root: Dict = {}
    stack: List[Tuple[int, object]] = [(-1, root)]
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            indent = len(line) - len(line.lstrip(" "))
            body = line.strip()
            # pop stack to current indent
            while stack and stack[-1][0] >= indent:
                stack.pop()
            parent = stack[-1][1] if stack else root
            if body.startswith("- "):
                val = _parse_scalar(body[2:].strip())
                if not isinstance(parent, list):
                    # We hit a `- value` line but the current parent is a dict,
                    # not a list. The mini-reader only supports scalar-under-list
                    # when the parent is already a list (pre-created elsewhere).
                    # Top-level-list-under-key is not supported — warn loudly so
                    # the skill author knows to swap in pyyaml if they need it.
                    warn(f"yaml_load: dropped list item {val!r} (top-level-list "
                         f"under dict key is unsupported; use pyyaml if needed)")
                    continue
                parent.append(val)
                continue
            if ":" in body:
                key, _, rest = body.partition(":")
                key = key.strip()
                rest = rest.strip()
                if rest == "":
                    new: Dict = {}
                    if isinstance(parent, dict):
                        parent[key] = new
                    stack.append((indent, new))
                else:
                    v = _parse_scalar(rest)
                    if isinstance(parent, dict):
                        parent[key] = v
    return root


def _parse_scalar(s: str):
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]
    if s.startswith("'") and s.endswith("'"):
        return s[1:-1]
    if s in ("true", "True"):
        return True
    if s in ("false", "False"):
        return False
    if s in ("null", "~", "None", ""):
        return None
    try:
        if "." in s or "e" in s.lower():
            return float(s)
        return int(s)
    except ValueError:
        return s


# ---------- data ----------

@dataclass
class DispatchRecord:
    trace_id: str
    role: str
    tier: Optional[str]
    model: Optional[str]
    dispatched_at: _dt.datetime
    returned_at: _dt.datetime
    linked_issues: List[str] = field(default_factory=list)
    round: int = 0
    delivery_id: int = 0
    reviewer_variant: Optional[str] = None  # "cross" | "adversarial" when role == "reviewer"
    session_file: Optional[str] = None  # optional: harness JSONL path hint for fast-path scanning


@dataclass
class UsageEvent:
    timestamp: _dt.datetime
    model: str
    input_tokens: int
    output_tokens: int
    cache_read_tokens: int
    cache_creation_tokens: int
    trace_id_hint: Optional[str] = None  # from user-message marker if present
    session_file: str = ""


# ---------- loaders ----------

TRACE_ID_RE = re.compile(r"\btrace_id:\s*(R\d+-[A-Za-z]-\d+)")

def load_dispatch_log(review_dir: str, round_n: int) -> List[DispatchRecord]:
    p = os.path.join(review_dir, "traces", f"round-{round_n}", "dispatch-log.jsonl")
    if not os.path.isfile(p):
        return []
    out: List[DispatchRecord] = []
    with open(p, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            e = json.loads(line)
            out.append(DispatchRecord(
                trace_id=e["trace_id"],
                role=e["role"],
                tier=e.get("tier"),
                model=e.get("model"),
                dispatched_at=parse_iso(e["dispatched_at"]),
                returned_at=parse_iso(e["returned_at"]),
                linked_issues=list(e.get("linked_issues", [])),
                round=round_n,
                delivery_id=int(e.get("delivery_id", 0)),
                reviewer_variant=e.get("reviewer_variant"),
                session_file=e.get("session_file"),
            ))
    return out


def _extract_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for c in content:
            if isinstance(c, dict):
                if c.get("type") == "text":
                    parts.append(c.get("text", ""))
                elif "content" in c:
                    parts.append(_extract_text(c["content"]))
        return "\n".join(parts)
    return ""


def load_harness_events(
    harness_dir: str,
    session_file_hints: Optional[Set[str]] = None,
) -> List[UsageEvent]:
    """Load usage events from harness JSONL files.

    If `session_file_hints` is provided (non-empty set of absolute paths),
    only those files are scanned — this is the fast-path enabled by
    dispatch-log records carrying a `session_file` field (see SKILL-INTEGRATION
    Snippet C). If empty / None, falls back to `rglob("*.jsonl")` over
    `harness_dir` — the zero-coupling default.
    """
    events: List[UsageEvent] = []
    if session_file_hints:
        paths = [pathlib.Path(p) for p in session_file_hints if os.path.isfile(p)]
    else:
        paths = list(pathlib.Path(harness_dir).rglob("*.jsonl"))
    for p in paths:
        current_trace_hint: Optional[str] = None
        try:
            with open(p, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        e = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    t = e.get("type")
                    if t == "user":
                        txt = _extract_text((e.get("message") or {}).get("content"))
                        m = TRACE_ID_RE.search(txt)
                        if m:
                            current_trace_hint = m.group(1)
                        # A user turn WITHOUT a marker invalidates the prior hint —
                        # we don't want to leak a hint across unrelated turns.
                        else:
                            current_trace_hint = None
                    elif t == "assistant":
                        msg = e.get("message") or {}
                        usage = msg.get("usage") or {}
                        if not usage:
                            continue
                        ts_raw = e.get("timestamp") or msg.get("timestamp")
                        if not ts_raw:
                            continue
                        events.append(UsageEvent(
                            timestamp=parse_iso(ts_raw),
                            model=msg.get("model", ""),
                            input_tokens=int(usage.get("input_tokens", 0)),
                            output_tokens=int(usage.get("output_tokens", 0)),
                            cache_read_tokens=int(usage.get("cache_read_input_tokens", 0)),
                            cache_creation_tokens=int(usage.get("cache_creation_input_tokens", 0)),
                            trace_id_hint=current_trace_hint,
                            session_file=str(p),
                        ))
        except OSError:
            continue
    return events


# ---------- JOIN ----------

@dataclass
class AttributedEvent:
    trace_id: str
    event: UsageEvent


def join_events(
    dispatches: List[DispatchRecord],
    events: List[UsageEvent],
) -> Tuple[List[AttributedEvent], List[UsageEvent], List[DispatchRecord]]:
    """Returns (attributed, unmatched_events, unmatched_dispatches)."""
    by_trace: Dict[str, DispatchRecord] = {d.trace_id: d for d in dispatches}
    attributed: List[AttributedEvent] = []
    unmatched_events: List[UsageEvent] = []
    used_traces: set = set()

    # Pass 1: primary JOIN via explicit trace_id hint
    remaining: List[UsageEvent] = []
    for ev in events:
        if ev.trace_id_hint and ev.trace_id_hint in by_trace:
            attributed.append(AttributedEvent(ev.trace_id_hint, ev))
            used_traces.add(ev.trace_id_hint)
        else:
            remaining.append(ev)

    # Pass 2: fallback timestamp-window JOIN (only for remaining events)
    for ev in remaining:
        candidates = [
            d for d in dispatches
            if d.dispatched_at <= ev.timestamp <= d.returned_at
            and (not d.model or not ev.model or d.model == ev.model)
        ]
        if len(candidates) == 1:
            attributed.append(AttributedEvent(candidates[0].trace_id, ev))
            used_traces.add(candidates[0].trace_id)
        else:
            unmatched_events.append(ev)

    unmatched_dispatches = [d for d in dispatches if d.trace_id not in used_traces]
    return attributed, unmatched_events, unmatched_dispatches


# ---------- pricing ----------

@dataclass
class Pricing:
    # USD per 1M tokens
    input: float = 0.0
    output: float = 0.0
    cache_read: float = 0.0
    cache_creation: float = 0.0


def pricing_for(model: str, cfg: dict) -> Pricing:
    table = (cfg.get("pricing") or {}).get("models") or {}
    # Try exact model, then prefix match
    entry = table.get(model)
    if entry is None:
        for k, v in table.items():
            if model and model.startswith(k):
                entry = v
                break
    if not entry:
        return Pricing()
    return Pricing(
        input=float(entry.get("input_per_1m", 0.0)),
        output=float(entry.get("output_per_1m", 0.0)),
        cache_read=float(entry.get("cache_read_per_1m", 0.0)),
        cache_creation=float(entry.get("cache_creation_per_1m", 0.0)),
    )


def cost_for(ev: UsageEvent, p: Pricing) -> float:
    return (
        ev.input_tokens * p.input
        + ev.output_tokens * p.output
        + ev.cache_read_tokens * p.cache_read
        + ev.cache_creation_tokens * p.cache_creation
    ) / 1_000_000.0


# ---------- aggregation ----------

def aggregate(
    dispatches: List[DispatchRecord],
    attributed: List[AttributedEvent],
    cfg: dict,
    criterion_extractor: str = "",
) -> dict:
    by_trace_cost: Dict[str, float] = {}
    by_trace_tokens: Dict[str, Dict[str, int]] = {}
    by_role_agg: Dict[str, Dict[str, float]] = {}
    total_usd = 0.0

    # Latency per trace (from dispatch-log)
    latency_by_role: Dict[str, float] = {}
    calls_by_role: Dict[str, int] = {}
    for d in dispatches:
        latency = (d.returned_at - d.dispatched_at).total_seconds()
        latency_by_role[d.role] = latency_by_role.get(d.role, 0.0) + latency
        calls_by_role[d.role] = calls_by_role.get(d.role, 0) + 1

    for att in attributed:
        ev = att.event
        d = next((x for x in dispatches if x.trace_id == att.trace_id), None)
        if d is None:
            continue
        p = pricing_for(ev.model or d.model or "", cfg)
        usd = cost_for(ev, p)
        total_usd += usd

        by_trace_cost[att.trace_id] = by_trace_cost.get(att.trace_id, 0.0) + usd
        tk = by_trace_tokens.setdefault(att.trace_id, {
            "input": 0, "output": 0, "cache_read": 0, "cache_creation": 0,
        })
        tk["input"] += ev.input_tokens
        tk["output"] += ev.output_tokens
        tk["cache_read"] += ev.cache_read_tokens
        tk["cache_creation"] += ev.cache_creation_tokens

        role = d.role
        agg = by_role_agg.setdefault(role, {
            "input_tokens": 0, "output_tokens": 0,
            "cache_read_tokens": 0, "cache_creation_tokens": 0,
            "usd": 0.0,
        })
        agg["input_tokens"] += ev.input_tokens
        agg["output_tokens"] += ev.output_tokens
        agg["cache_read_tokens"] += ev.cache_read_tokens
        agg["cache_creation_tokens"] += ev.cache_creation_tokens
        agg["usd"] += usd

    # inject calls count
    for role, agg in by_role_agg.items():
        agg["calls"] = calls_by_role.get(role, 0)

    # by_criterion (via extractor hook)
    by_criterion: Dict[str, Dict[str, float]] = {}
    if criterion_extractor:
        for trace_id, usd in by_trace_cost.items():
            try:
                r = subprocess.run(
                    [criterion_extractor, trace_id],
                    capture_output=True, text=True, timeout=10,
                )
                if r.returncode != 0:
                    warn(f"criterion-extractor failed for {trace_id}: rc={r.returncode}")
                    continue
                for line in r.stdout.splitlines():
                    cid = line.strip()
                    if not cid:
                        continue
                    c = by_criterion.setdefault(cid, {"usd": 0.0, "trace_count": 0})
                    c["usd"] += usd
                    c["trace_count"] += 1
            except (subprocess.TimeoutExpired, OSError) as e:
                warn(f"criterion-extractor error: {e}")

    return {
        "total_usd": round(total_usd, 6),
        "by_role": {r: {k: (round(v, 6) if isinstance(v, float) else v) for k, v in agg.items()}
                    for r, agg in sorted(by_role_agg.items())},
        "by_criterion": {k: {kk: (round(vv, 6) if isinstance(vv, float) else vv) for kk, vv in v.items()}
                         for k, v in sorted(by_criterion.items())},
        "latency_by_role": {r: round(t, 3) for r, t in sorted(latency_by_role.items())},
        "trace_count": len(dispatches),
        "trace_cost": {k: round(v, 6) for k, v in sorted(by_trace_cost.items())},
    }


# ---------- scope resolution ----------

def resolve_rounds(review_dir: str, scope_key: str, scope_val: str) -> List[int]:
    trace_dir = os.path.join(review_dir, "traces")
    if not os.path.isdir(trace_dir):
        die(2, f"no traces dir: {trace_dir}")

    all_rounds = sorted(
        int(d.split("-", 1)[1]) for d in os.listdir(trace_dir)
        if re.match(r"^round-\d+$", d)
    )

    if scope_key == "round":
        n = int(scope_val)
        if n not in all_rounds:
            die(2, f"round {n} has no dispatch-log (available: {all_rounds})")
        return [n]
    if scope_key == "delivery":
        delivery = int(scope_val)
        matching = []
        for n in all_rounds:
            recs = load_dispatch_log(review_dir, n)
            if recs and any(r.delivery_id == delivery for r in recs):
                matching.append(n)
        if not matching:
            die(2, f"no rounds found for delivery {delivery}")
        return matching
    if scope_key == "since":
        # Naive impl: treat <sha> as timestamp cutoff if parseable, else all rounds.
        # In practice you'd call `git log <sha>..HEAD -- .review/traces/` — left as a
        # user-side extension to keep the reference impl dependency-free.
        try:
            cutoff = parse_iso(scope_val)
            matching = []
            for n in all_rounds:
                recs = load_dispatch_log(review_dir, n)
                if any(r.dispatched_at >= cutoff for r in recs):
                    matching.append(n)
            if not matching:
                die(2, f"no rounds found since {scope_val}")
            return matching
        except ValueError:
            die(2, f"--since with git-sha requires git integration (not in reference impl); pass an ISO timestamp instead, got: {scope_val}")
    die(1, f"unknown scope: {scope_key}")
    return []  # unreachable


def _build_traces(trace_cost: Dict[str, float], dispatches: List[DispatchRecord]) -> List[dict]:
    """Per-trace output rows. Includes optional `reviewer_variant` when non-null."""
    by_trace = {d.trace_id: d for d in dispatches}
    rows: List[dict] = []
    for tid, usd in sorted(trace_cost.items()):
        row: Dict = {"trace_id": tid, "usd": round(usd, 6)}
        d = by_trace.get(tid)
        if d and d.reviewer_variant:
            row["reviewer_variant"] = d.reviewer_variant
        rows.append(row)
    return rows


# ---------- main ----------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scope", required=True, help="round=N | delivery=N | since=<iso>")
    ap.add_argument("--review-dir", required=True)
    ap.add_argument("--harness-dir", required=True)
    ap.add_argument("--config", default="")
    ap.add_argument("--criterion-extractor", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    scope_key, _, scope_val = args.scope.partition("=")
    cfg = yaml_load(args.config) if args.config else {}

    rounds = resolve_rounds(args.review_dir, scope_key, scope_val)
    all_dispatches: List[DispatchRecord] = []
    for n in rounds:
        all_dispatches.extend(load_dispatch_log(args.review_dir, n))
    if not all_dispatches:
        die(2, "no dispatch records found in scope")

    # Fast-path: if any dispatch record carries an explicit `session_file`,
    # scan only those files instead of rglob-ing the whole harness dir.
    # Empty / missing hints fall back to the zero-coupling full scan.
    session_hints = {d.session_file for d in all_dispatches if d.session_file}
    events = load_harness_events(args.harness_dir, session_hints or None)
    attributed, unmatched_evs, unmatched_ds = join_events(all_dispatches, events)

    # JOIN health check
    unmatched_ratio = len(unmatched_ds) / max(1, len(all_dispatches))

    agg = aggregate(all_dispatches, attributed, cfg, args.criterion_extractor)

    out = {
        "generated_at": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "scope": {"key": scope_key, "value": scope_val, "rounds": rounds},
        "delivery_id": all_dispatches[0].delivery_id if all_dispatches else 0,
        "pricing_source": args.config or "none",
        "cost": {
            "total_usd": agg["total_usd"],
            "by_role": agg["by_role"],
            "by_criterion": agg["by_criterion"],
        },
        "latency_seconds": {
            "total": round(sum(agg["latency_by_role"].values()), 3),
            "by_role": agg["latency_by_role"],
        },
        "join_stats": {
            "dispatched_traces": len(all_dispatches),
            "unmatched_dispatches": len(unmatched_ds),
            "unmatched_events": len(unmatched_evs),
            "unmatched_ratio": round(unmatched_ratio, 4),
        },
        "traces": _build_traces(agg["trace_cost"], all_dispatches),
        "warnings": [],
    }

    if unmatched_ds:
        out["warnings"].append(
            f"{len(unmatched_ds)} dispatch record(s) had no matched harness events: "
            + ", ".join(d.trace_id for d in unmatched_ds[:5])
            + ("..." if len(unmatched_ds) > 5 else "")
        )
    if unmatched_ratio > 0.5:
        out["warnings"].append(
            f"JOIN failure: {unmatched_ratio:.0%} of dispatches unmatched — "
            "check harness-dir, trace_id markers, or timestamp clocks"
        )

    yaml_text = yaml_dump(out)

    if args.dry_run:
        sys.stdout.write(yaml_text)
        return 0 if unmatched_ratio <= 0.5 else 3

    metrics_dir = os.path.join(args.review_dir, "metrics")
    os.makedirs(metrics_dir, exist_ok=True)
    # Filenames use `.metrics.yml` suffix to stay out of summarizer's namespace:
    # summarizer writes `round-N.yml` (content+quality view) + `.review/versions/<N>.md`
    # (delivery content view); this script writes `round-N.metrics.yml` /
    # `delivery-N.metrics.yml` / `since-<iso>.metrics.yml` (cost+JOIN view).
    # See guide §3.2 / §3.3 / §10.4.
    if scope_key == "round":
        target = os.path.join(metrics_dir, f"round-{scope_val}.metrics.yml")
    elif scope_key == "delivery":
        target = os.path.join(metrics_dir, f"delivery-{scope_val}.metrics.yml")
    else:
        safe = re.sub(r"[^0-9A-Za-z._-]", "_", scope_val)[:40]
        target = os.path.join(metrics_dir, f"since-{safe}.metrics.yml")

    # Atomic write
    tmp = target + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(yaml_text)
    os.replace(tmp, target)
    print(f"wrote {target}", file=sys.stderr)

    return 0 if unmatched_ratio <= 0.5 else 3


if __name__ == "__main__":
    sys.exit(main())
