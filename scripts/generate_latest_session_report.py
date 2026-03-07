#!/usr/bin/env python3

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
from pathlib import Path
from typing import Any


DEFAULT_RAW_LOG = Path("/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl")
DEFAULT_CANONICAL_BUNDLE = Path(
    "/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events_canonical.json"
)
EVENT_SCHEMA_NAME = "holdem.play_event"
CURRENT_EVENT_SCHEMA_VERSION = 4
MIN_READABLE_EVENT_SCHEMA_VERSION = 2
SUPPORTED_EVENT_SCHEMA_VERSIONS = {2, 3, 4}
EVENT_MIGRATION_CONTRACT = "holdem.play_event_migration.v1"


def _parse_ts(value: Any) -> dt.datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return dt.datetime.fromtimestamp(float(value), tz=dt.timezone.utc)
    if not isinstance(value, str):
        return None

    try:
        if value.endswith("Z"):
            return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return dt.datetime.fromisoformat(value)
    except ValueError:
        return None


def _fmt_float(value: float, decimals: int = 1) -> str:
    # Keep "-0.0" from showing up due to float noise.
    if abs(value) < 1e-9:
        value = 0.0
    return f"{value:.{decimals}f}"


def _fmt_int(value: Any) -> str:
    if value is None:
        return ""
    try:
        return str(int(value))
    except (TypeError, ValueError):
        return str(value)


def _int_or_none(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _float_or_none(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _time_only(ts: str) -> str:
    # "2026-03-02T10:41:23Z" -> "10:41:23Z"
    if not ts:
        return ""
    if "T" in ts:
        return ts.split("T", 1)[1]
    return ts


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            events.append(obj)
    return events


def _normalize_play_event(event: dict[str, Any]) -> dict[str, Any]:
    env = event.get("envelope") if isinstance(event.get("envelope"), dict) else {}
    schema_v = _int_or_none(event.get("schema_version"))
    if schema_v is None:
        schema_v = _int_or_none(env.get("schema_version"))
    if schema_v is None:
        raise ValueError("missing schema_version")
    if schema_v < MIN_READABLE_EVENT_SCHEMA_VERSION or schema_v not in SUPPORTED_EVENT_SCHEMA_VERSIONS:
        raise ValueError(f"unsupported schema_version={schema_v}")

    schema_name = event.get("schema_name") or env.get("schema_name")
    if schema_name is not None and schema_name != EVENT_SCHEMA_NAME:
        raise ValueError(f"unexpected schema_name={schema_name}")

    normalized = dict(event)
    normalized_env = dict(env)
    normalized["schema_name"] = EVENT_SCHEMA_NAME
    normalized["migration_contract"] = EVENT_MIGRATION_CONTRACT
    normalized["min_reader_schema_version"] = MIN_READABLE_EVENT_SCHEMA_VERSION
    normalized["compatibility_mode"] = "backward_additive"
    normalized_env["schema_name"] = EVENT_SCHEMA_NAME
    normalized_env["migration_contract"] = EVENT_MIGRATION_CONTRACT
    normalized_env["min_reader_schema_version"] = MIN_READABLE_EVENT_SCHEMA_VERSION
    normalized_env["compatibility_mode"] = "backward_additive"
    normalized["envelope"] = normalized_env
    normalized["_source_schema_version"] = schema_v
    normalized["_normalized_schema_version"] = CURRENT_EVENT_SCHEMA_VERSION
    normalized["_migration_applied"] = schema_v != CURRENT_EVENT_SCHEMA_VERSION

    if normalized.get("equivalence_tolerance") is not None:
        normalized.setdefault("equivalence_pct", 0.10)
        normalized.setdefault("equivalence_abs_floor", 5.0)
        best = _float_or_none(normalized.get("equivalence_best_ev_used"))
        worst = _float_or_none(normalized.get("equivalence_worst_ev_used"))
        if normalized.get("equivalence_span_used") is None and best is not None and worst is not None:
            normalized["equivalence_span_used"] = max(0.0, best - worst)

    return normalized


def _latest_session_id(events: list[dict[str, Any]]) -> tuple[str, dt.datetime]:
    latest_by_session: dict[str, dt.datetime] = {}
    for e in events:
        sid = e.get("session_id") or (e.get("envelope") or {}).get("session_id")
        ts = _parse_ts(e.get("ts"))
        if not sid or ts is None:
            continue
        cur = latest_by_session.get(sid)
        if cur is None or ts > cur:
            latest_by_session[sid] = ts

    if not latest_by_session:
        raise SystemExit("No session_id+ts pairs found in raw log.")

    sid, last_ts = max(latest_by_session.items(), key=lambda kv: kv[1])
    return sid, last_ts


def generate_report(events: list[dict[str, Any]], sid: str) -> str:
    raw_session_events = [
        e for e in events if (e.get("session_id") or (e.get("envelope") or {}).get("session_id")) == sid
    ]
    if not raw_session_events:
        raise SystemExit(f"No events found for session_id={sid}")

    session_events: list[dict[str, Any]] = []
    for e in raw_session_events:
        try:
            session_events.append(_normalize_play_event(e))
        except ValueError as exc:
            raise SystemExit(f"Unsupported or invalid play log schema for session_id={sid}: {exc}") from exc

    ts_list = [_parse_ts(e.get("ts")) for e in session_events if _parse_ts(e.get("ts")) is not None]
    if not ts_list:
        raise SystemExit(f"No parseable timestamps for session_id={sid}")

    start_ts = min(ts_list)
    end_ts = max(ts_list)

    decisions = [e for e in session_events if e.get("event") == "decision_lock"]
    undos = sum(1 for e in session_events if e.get("event") == "undo")
    busts = sum(1 for e in session_events if e.get("event") == "user_bust")

    # Session integrity checks
    schema_versions: set[int] = set()
    migrated_event_count = 0
    schema_ok = True
    for e in session_events:
        schema_v = _int_or_none(e.get("_source_schema_version"))
        env = e.get("envelope") or {}
        env_schema_v = _int_or_none(env.get("schema_version"))
        if isinstance(schema_v, int):
            schema_versions.add(schema_v)
        if e.get("_migration_applied"):
            migrated_event_count += 1
        if not (
            isinstance(schema_v, int)
            and schema_v in SUPPORTED_EVENT_SCHEMA_VERSIONS
            and e.get("schema_name") == EVENT_SCHEMA_NAME
            and env.get("schema_name") == EVENT_SCHEMA_NAME
            and env_schema_v == schema_v
            and env.get("migration_contract") == EVENT_MIGRATION_CONTRACT
            and _int_or_none(env.get("min_reader_schema_version")) == MIN_READABLE_EVENT_SCHEMA_VERSION
            and isinstance(env.get("event_version"), int)
        ):
            schema_ok = False

    schema_versions_label = ", ".join(str(v) for v in sorted(schema_versions)) if schema_versions else "(none)"
    seqs = [e.get("seq") for e in session_events if isinstance(e.get("seq"), int)]
    seq_strict = all(a < b for a, b in zip(seqs, seqs[1:])) if len(seqs) >= 2 else True
    seq_matches = all((e.get("envelope") or {}).get("seq") == e.get("seq") for e in session_events)

    # Decision stats
    decision_count = len(decisions)
    regrets = [float(e.get("regret") or 0.0) for e in decisions]
    tolerances = [float(e.get("equivalence_tolerance") or 0.0) for e in decisions]
    near_opt = sum(
        1
        for e in decisions
        if float(e.get("regret") or 0.0) <= float(e.get("equivalence_tolerance") or 0.0)
    )
    total_regret = sum(regrets)
    avg_regret = (total_regret / decision_count) if decision_count else 0.0
    undo_rate = (undos / decision_count) if decision_count else 0.0
    total_session_realized_pnl_delta = sum(float(e.get("session_realized_pnl_delta") or 0.0) for e in decisions)
    avg_session_realized_pnl_delta = (
        total_session_realized_pnl_delta / decision_count if decision_count else 0.0
    )
    last_session_realized_pnl = 0.0
    for e in decisions:
        val = e.get("session_realized_pnl")
        if isinstance(val, (int, float)):
            last_session_realized_pnl = float(val)

    # Hands in session (as seen by decisions). This matches the "hands with decisions" framing.
    hand_ids = sorted({int(e.get("hand_id")) for e in decisions if isinstance(e.get("hand_id"), int)})

    # Street breakdown
    by_street: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for e in decisions:
        by_street[str(e.get("street") or "")].append(e)

    street_order = {"preflop": 0, "flop": 1, "turn": 2, "river": 3}
    streets_sorted = sorted(by_street.items(), key=lambda kv: street_order.get(kv[0], 99))

    street_rows: list[tuple[str, int, float, float, float]] = []
    for street, lst in streets_sorted:
        r = [float(x.get("regret") or 0.0) for x in lst]
        n = len(lst)
        near = sum(
            1
            for x in lst
            if float(x.get("regret") or 0.0) <= float(x.get("equivalence_tolerance") or 0.0)
        )
        street_rows.append((street, n, (near / n) if n else 0.0, (sum(r) / n) if n else 0.0, sum(r)))

    # Nuance: find a street whose regret is dominated by one decision.
    dominance_note: str | None = None
    for street, lst in streets_sorted:
        if len(lst) < 2:
            continue
        r = sorted((float(x.get("regret") or 0.0) for x in lst), reverse=True)
        total = sum(r)
        if total <= 0:
            continue
        if r[0] >= 0.5 * total:
            rest = total - r[0]
            dominance_note = (
                f"Important nuance: {street} is dominated by 1 decision.\n\n"
                f"- {street.capitalize()} worst regret: `{_fmt_float(r[0])}`\n"
                f"- {street.capitalize()} regret excluding the worst: `{_fmt_float(rest)}` across {len(r) - 1} decisions"
                f" (`{_fmt_float(rest / (len(r) - 1))}` avg)\n"
            )
            break

    # Top costly decisions
    top = sorted(decisions, key=lambda e: float(e.get("regret") or 0.0), reverse=True)[:10]

    # Sizing / action tendencies
    chosen_ctr = collections.Counter(e.get("chosen_action") for e in decisions)
    best_ctr = collections.Counter(e.get("best_action") for e in decisions)
    actions = sorted(set(chosen_ctr) | set(best_ctr))
    deltas: list[tuple[int, str, int, int]] = []
    for a in actions:
        c = int(chosen_ctr.get(a, 0))
        b = int(best_ctr.get(a, 0))
        if c == b:
            continue
        deltas.append((abs(c - b), a or "", c, b))
    deltas.sort(reverse=True)
    deltas = deltas[:6]

    generated_date = dt.datetime.now().date().isoformat()

    md: list[str] = []
    md.append("# Latest Session Analysis (local)")
    md.append("")
    md.append(f"- Generated: {generated_date}")
    md.append(f"- Raw log snapshot cutoff: `{end_ts.isoformat().replace('+00:00', 'Z')}`")
    md.append(f"- Canonical bundle: `{DEFAULT_CANONICAL_BUNDLE}`")
    md.append(f"- Raw audit log: `{DEFAULT_RAW_LOG}`")
    md.append("")

    md.append("## Session Snapshot")
    md.append("")
    md.append(f"- Session id: `{sid}`")
    md.append(
        f"- Time range: `{start_ts.isoformat().replace('+00:00', 'Z')}` → `{end_ts.isoformat().replace('+00:00', 'Z')}`"
    )
    md.append(f"- Hands: `{len(hand_ids)}` (hands with decisions)")
    md.append(f"- Decisions: `{decision_count}`")
    md.append(f"- Near-optimal (regret <= tolerance): `{near_opt}/{decision_count}` (`{_fmt_float((near_opt / decision_count) * 100.0) if decision_count else '0.0'}%`)")
    md.append(f"- Total regret: `{_fmt_float(total_regret)}` chips")
    md.append(f"- Avg regret: `{_fmt_float(avg_regret)}` chips/decision")
    md.append(f"- Session realized P&L: `{_fmt_float(last_session_realized_pnl)}` chips")
    md.append(
        f"- Realized P&L delta / decision: `{_fmt_float(avg_session_realized_pnl_delta)}` chips"
    )
    md.append(f"- Busts: `{busts}`")
    md.append(f"- Undos: `{undos}` (undo rate `{_fmt_float(undo_rate * 100.0)}%`)")
    md.append("")

    md.append("## Log Integrity Checks")
    md.append("")
    md.append("For this session:")
    md.append("")
    md.append(
        f"- Migration contract: `{EVENT_MIGRATION_CONTRACT}`. Readable source schemas: `{MIN_READABLE_EVENT_SCHEMA_VERSION}`-`{CURRENT_EVENT_SCHEMA_VERSION}`"
        f" (seen: `{schema_versions_label}`), normalized in-memory to `{CURRENT_EVENT_SCHEMA_VERSION}`."
        + ("" if schema_ok else " (FAILED)")
    )
    md.append(f"- Migrated records during analysis: `{migrated_event_count}/{len(session_events)}`.")
    md.append(
        f"- `seq` was strictly increasing and matched `envelope.seq`."
        + ("" if (seq_strict and seq_matches) else " (FAILED)")
    )
    md.append("")

    md.append("## Street Breakdown (Where The EV Was Lost)")
    md.append("")
    md.append("| Street | Decisions | Near-opt | Avg regret | Total regret |")
    md.append("|---|---:|---:|---:|---:|")
    for street, n, near_rate, avg_r, total_r in street_rows:
        md.append(
            f"| {street or '(unknown)'} | {n} | {_fmt_float(near_rate * 100.0)}% | {_fmt_float(avg_r)} | {_fmt_float(total_r)} |"
        )
    md.append("")
    if dominance_note:
        md.append(dominance_note.rstrip())
        md.append("")

    md.append("## Top Costly Decisions (By Regret)")
    md.append("")
    md.append("| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |")
    md.append("|---|---:|---|---|---|---:|---:|---:|---:|---:|")
    for e in top:
        md.append(
            "| {ts} | {hand} | {street} | {chosen} | {best} | {regret} | {tol} | {pot} | {to_call} | {stack} |".format(
                ts=_time_only(str(e.get("ts") or "")),
                hand=_fmt_int(e.get("hand_id")),
                street=str(e.get("street") or ""),
                chosen=str(e.get("chosen_action") or ""),
                best=str(e.get("best_action") or ""),
                regret=_fmt_float(float(e.get("regret") or 0.0)),
                tol=_fmt_float(float(e.get("equivalence_tolerance") or 0.0)),
                pot=_fmt_int(e.get("pot")),
                to_call=_fmt_int(e.get("to_call")),
                stack=_fmt_int(e.get("user_stack")),
            )
        )
    md.append("")

    md.append("## Sizing Tendencies (Chosen vs Best)")
    md.append("")
    if not deltas:
        md.append("Chosen action counts matched best-action counts exactly in this snapshot.")
    else:
        md.append("Biggest gaps in this session:")
        md.append("")
        for _, action, c, b in deltas:
            tag = "overused" if c > b else "underused"
            md.append(f"- `{action}`: chosen {c} vs best {b} ({tag})")
    md.append("")

    md.append("## Coaching Takeaways (What To Do Differently Next 10 Hands)")
    md.append("")
    if not decisions:
        md.append("No decisions found in this session snapshot.")
        return "\n".join(md).rstrip() + "\n"

    worst = max(decisions, key=lambda e: float(e.get("regret") or 0.0))
    worst_regret = float(worst.get("regret") or 0.0)
    worst_street = str(worst.get("street") or "")
    worst_chosen = str(worst.get("chosen_action") or "")
    worst_best = str(worst.get("best_action") or "")

    i = 1
    if worst_best == "fold" and worst_chosen != "fold":
        md.append(f"{i}. **When best is `fold`, treat it as a hard stop.**")
        md.append(f"   - Biggest leak was `{worst_chosen}` vs `fold` on {worst_street} (lost `{_fmt_float(worst_regret)}` EV).")
        i += 1
        md.append("")

    if "overbet" in " ".join(chosen_ctr.keys()):
        md.append(f"{i}. **Don’t default to overbets; force a comparison against standard sizes.**")
        md.append("   - Overbets tend to be high-variance and are often not robust unless clearly best in the EV map.")
        i += 1
        md.append("")

    if worst_chosen in {"check/call", "check"} and worst_best.startswith("raise"):
        md.append(f"{i}. **If the model wants a raise, don’t settle for `check/call`.**")
        md.append(f"   - Your worst spot was passive: `{worst_chosen}` vs `{worst_best}` on {worst_street}.")
        i += 1
        md.append("")

    if undos:
        md.append(f"{i}. **Undo is fine; use it to protect EV, not to chase perfection.**")
        md.append(f"   - You used `undo` {undos} time(s). If you undo, immediately re-check `{worst_best}` vs 1 alternative and commit.")
        i += 1
        md.append("")

    if busts:
        md.append(f"{i}. **Bust review: don’t let a single non-equivalent decision decide the stack.**")
        md.append("   - Tag the biggest-regret hand(s), replay them, and set a goal of 0 busts from non-equivalent actions next session.")
        i += 1
        md.append("")

    # If we didn't add anything (rare), add a generic line.
    if i == 1:
        md.append("1. **Keep the focus on your top-1 regret decision.**")
        md.append("   - Fixing the single worst leak usually improves the session more than polishing many small spots.")
        md.append("")

    return "\n".join(md).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate reports/latest_session_analysis.md from HoldemPOC raw logs.")
    parser.add_argument("--raw-log", type=Path, default=DEFAULT_RAW_LOG, help="Path to play_events.jsonl")
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output markdown file path (default: <repo>/reports/latest_session_analysis.md)",
    )
    parser.add_argument(
        "--session-id",
        type=str,
        default=None,
        help="Analyze a specific session id instead of the latest.",
    )
    args = parser.parse_args()

    events = _load_jsonl(args.raw_log)
    if args.session_id:
        sid = args.session_id
        last_ts = None
    else:
        sid, last_ts = _latest_session_id(events)

    report = generate_report(events, sid)

    repo_root = Path(__file__).resolve().parents[1]
    out_path: Path = args.out if args.out is not None else (repo_root / "reports" / "latest_session_analysis.md")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(report)

    if last_ts is not None:
        print(f"Wrote {out_path} for latest session {sid} (cutoff {last_ts.isoformat()}).")
    else:
        print(f"Wrote {out_path} for session {sid}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
