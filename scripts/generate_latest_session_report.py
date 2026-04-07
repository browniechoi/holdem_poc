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


def _bool_or_none(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    return None


def _decision_best_confidence(event: dict[str, Any]) -> str | None:
    value = event.get("best_confidence")
    if not isinstance(value, str):
        return None
    value = value.strip().lower()
    return value or None


def _decision_has_clear_best(event: dict[str, Any]) -> bool:
    explicit = _bool_or_none(event.get("is_clear_best"))
    if explicit is not None:
        return explicit
    # Older logs did not encode confidence metadata. Preserve backward compatibility by
    # treating them as clear-best unless the event explicitly says otherwise.
    return True


def _decision_best_stderr(event: dict[str, Any]) -> float | None:
    return _float_or_none(event.get("best_ev_stderr"))


def _top_line_label(event: dict[str, Any]) -> str:
    if _decision_has_clear_best(event):
        return str(event.get("best_action") or "")
    confidence = _decision_best_confidence(event)
    if confidence:
        return f"unclear ({confidence}-confidence)"
    return "unclear"


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


def _session_ids_by_end_ts(events: list[dict[str, Any]]) -> list[str]:
    latest_by_session: dict[str, dt.datetime] = {}
    for e in events:
        sid = e.get("session_id") or (e.get("envelope") or {}).get("session_id")
        ts = _parse_ts(e.get("ts"))
        if not sid or ts is None:
            continue
        cur = latest_by_session.get(sid)
        if cur is None or ts > cur:
            latest_by_session[sid] = ts
    return [sid for sid, _ in sorted(latest_by_session.items(), key=lambda kv: kv[1])]


def _previous_session_id(events: list[dict[str, Any]], sid: str) -> str | None:
    ordered = _session_ids_by_end_ts(events)
    try:
        idx = ordered.index(sid)
    except ValueError:
        return None
    if idx <= 0:
        return None
    return ordered[idx - 1]


def _decision_summary(decisions: list[dict[str, Any]], undos: int, busts: int) -> dict[str, Any]:
    decision_count = len(decisions)
    total_regret = sum(float(e.get("regret") or 0.0) for e in decisions)
    near_opt = sum(
        1
        for e in decisions
        if float(e.get("regret") or 0.0) <= float(e.get("equivalence_tolerance") or 0.0)
    )
    avg_regret = (total_regret / decision_count) if decision_count else 0.0
    undo_rate = (undos / decision_count) if decision_count else 0.0
    confidence_metadata_count = sum(
        1
        for e in decisions
        if e.get("is_clear_best") is not None
        or e.get("best_confidence") is not None
        or e.get("best_ev_stderr") is not None
    )
    clear_best_count = sum(1 for e in decisions if _decision_has_clear_best(e))
    stderr_values = [value for e in decisions if (value := _decision_best_stderr(e)) is not None]
    avg_best_stderr = (sum(stderr_values) / len(stderr_values)) if stderr_values else None
    last_session_realized_pnl = 0.0
    for e in decisions:
        val = e.get("session_realized_pnl")
        if isinstance(val, (int, float)):
            last_session_realized_pnl = float(val)
    return {
        "decision_count": decision_count,
        "near_opt_count": near_opt,
        "near_opt_rate": (near_opt / decision_count) if decision_count else 0.0,
        "total_regret": total_regret,
        "avg_regret": avg_regret,
        "undo_count": undos,
        "undo_rate": undo_rate,
        "bust_count": busts,
        "confidence_metadata_count": confidence_metadata_count,
        "clear_best_count": clear_best_count,
        "clear_best_rate": (clear_best_count / decision_count) if decision_count else 0.0,
        "avg_best_stderr": avg_best_stderr,
        "session_realized_pnl": last_session_realized_pnl,
    }


def _street_summary_rows(decisions: list[dict[str, Any]]) -> list[tuple[str, int, float, float, float]]:
    by_street: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for e in decisions:
        by_street[str(e.get("street") or "")].append(e)

    street_order = {"preflop": 0, "flop": 1, "turn": 2, "river": 3}
    streets_sorted = sorted(by_street.items(), key=lambda kv: street_order.get(kv[0], 99))

    street_rows: list[tuple[str, int, float, float, float]] = []
    for street, lst in streets_sorted:
        regrets = [float(x.get("regret") or 0.0) for x in lst]
        n = len(lst)
        near = sum(
            1
            for x in lst
            if float(x.get("regret") or 0.0) <= float(x.get("equivalence_tolerance") or 0.0)
        )
        street_rows.append((street, n, (near / n) if n else 0.0, (sum(regrets) / n) if n else 0.0, sum(regrets)))
    return street_rows


def _action_mismatch_rows(
    decisions: list[dict[str, Any]],
) -> tuple[list[tuple[int, str, int, int]], list[dict[str, Any]], collections.Counter[Any], collections.Counter[Any]]:
    chosen_ctr = collections.Counter(e.get("chosen_action") for e in decisions)
    best_ctr = collections.Counter(e.get("best_action") for e in decisions)
    actions = sorted(set(chosen_ctr) | set(best_ctr))

    deltas: list[tuple[int, str, int, int]] = []
    details: list[dict[str, Any]] = []
    for action in actions:
        chosen_count = int(chosen_ctr.get(action, 0))
        best_count = int(best_ctr.get(action, 0))
        if chosen_count != best_count:
            deltas.append((abs(chosen_count - best_count), action or "", chosen_count, best_count))

        chosen_decisions = [e for e in decisions if e.get("chosen_action") == action]
        total_regret_when_chosen = sum(float(e.get("regret") or 0.0) for e in chosen_decisions)
        avg_regret_when_chosen = (
            total_regret_when_chosen / len(chosen_decisions) if chosen_decisions else 0.0
        )
        non_equivalent_when_chosen = sum(
            1
            for e in chosen_decisions
            if float(e.get("regret") or 0.0) > max(0.01, float(e.get("equivalence_tolerance") or 0.0))
        )
        top_example = max(chosen_decisions, key=lambda e: float(e.get("regret") or 0.0), default=None)
        details.append(
            {
                "action": action or "",
                "chosen_count": chosen_count,
                "best_count": best_count,
                "delta": chosen_count - best_count,
                "total_regret_when_chosen": total_regret_when_chosen,
                "avg_regret_when_chosen": avg_regret_when_chosen,
                "non_equivalent_when_chosen": non_equivalent_when_chosen,
                "top_example": top_example,
            }
        )

    deltas.sort(reverse=True)
    details.sort(
        key=lambda item: (
            abs(int(item["delta"])),
            float(item["total_regret_when_chosen"]),
            float(item["avg_regret_when_chosen"]),
        ),
        reverse=True,
    )
    return deltas[:6], details, chosen_ctr, best_ctr


def _session_summary_for_sid(events: list[dict[str, Any]], sid: str) -> dict[str, Any] | None:
    raw_session_events = [
        e for e in events if (e.get("session_id") or (e.get("envelope") or {}).get("session_id")) == sid
    ]
    if not raw_session_events:
        return None
    session_events: list[dict[str, Any]] = []
    for e in raw_session_events:
        try:
            session_events.append(_normalize_play_event(e))
        except ValueError:
            continue
    decisions = [e for e in session_events if e.get("event") == "decision_lock"]
    undos = sum(1 for e in session_events if e.get("event") == "undo")
    busts = sum(1 for e in session_events if e.get("event") == "user_bust")
    summary = _decision_summary(decisions, undos, busts)
    summary["session_id"] = sid
    return summary


def generate_report(
    events: list[dict[str, Any]],
    sid: str,
    *,
    generated_date: str | None = None,
    raw_log_label: str | None = None,
    canonical_bundle_label: str | None = None,
) -> str:
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
    current_summary = _decision_summary(decisions, undos, busts)
    decision_count = int(current_summary["decision_count"])
    near_opt = int(current_summary["near_opt_count"])
    total_regret = float(current_summary["total_regret"])
    avg_regret = float(current_summary["avg_regret"])
    undo_rate = float(current_summary["undo_rate"])
    confidence_metadata_count = int(current_summary["confidence_metadata_count"])
    confidence_metadata_available = confidence_metadata_count > 0
    clear_best_count = int(current_summary["clear_best_count"])
    clear_best_rate = float(current_summary["clear_best_rate"])
    avg_best_stderr = _float_or_none(current_summary["avg_best_stderr"])
    total_session_realized_pnl_delta = sum(float(e.get("session_realized_pnl_delta") or 0.0) for e in decisions)
    avg_session_realized_pnl_delta = (
        total_session_realized_pnl_delta / decision_count if decision_count else 0.0
    )
    last_session_realized_pnl = float(current_summary["session_realized_pnl"])

    # Hands in session (as seen by decisions). This matches the "hands with decisions" framing.
    hand_ids = sorted({int(e.get("hand_id")) for e in decisions if isinstance(e.get("hand_id"), int)})

    # Street breakdown
    street_rows = _street_summary_rows(decisions)

    # Nuance: find a street whose regret is dominated by one decision.
    dominance_note: str | None = None
    by_street: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for e in decisions:
        by_street[str(e.get("street") or "")].append(e)
    street_order = {"preflop": 0, "flop": 1, "turn": 2, "river": 3}
    streets_sorted = sorted(by_street.items(), key=lambda kv: street_order.get(kv[0], 99))
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
    deltas, action_details, chosen_ctr, best_ctr = _action_mismatch_rows(decisions)
    previous_sid = _previous_session_id(events, sid)
    previous_summary = _session_summary_for_sid(events, previous_sid) if previous_sid else None

    generated_date = generated_date or dt.datetime.now().date().isoformat()
    raw_log_label = raw_log_label or str(DEFAULT_RAW_LOG)
    canonical_bundle_label = canonical_bundle_label or str(DEFAULT_CANONICAL_BUNDLE)

    md: list[str] = []
    md.append("# Latest Session Analysis (local)")
    md.append("")
    md.append(f"- Generated: {generated_date}")
    md.append(f"- Raw log snapshot cutoff: `{end_ts.isoformat().replace('+00:00', 'Z')}`")
    md.append(f"- Canonical bundle: `{canonical_bundle_label}`")
    md.append(f"- Raw audit log: `{raw_log_label}`")
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
    if confidence_metadata_available:
        md.append(
            f"- Supported clear-best decisions: `{clear_best_count}/{decision_count}` (`{_fmt_float(clear_best_rate * 100.0)}%`)"
        )
    if confidence_metadata_available and avg_best_stderr is not None:
        md.append(f"- Avg best-line standard error: `±{_fmt_float(avg_best_stderr)}` chips")
    md.append(f"- Session realized P&L: `{_fmt_float(last_session_realized_pnl)}` chips")
    md.append(
        f"- Realized P&L delta / decision: `{_fmt_float(avg_session_realized_pnl_delta)}` chips"
    )
    md.append(f"- Busts: `{busts}`")
    md.append(f"- Undos: `{undos}` (undo rate `{_fmt_float(undo_rate * 100.0)}%`)")
    md.append("")

    md.append("## Trend vs Previous Session")
    md.append("")
    if previous_summary is None:
        md.append("No prior session with parseable timestamps was available for comparison.")
    else:
        near_delta = float(current_summary["near_opt_rate"]) - float(previous_summary["near_opt_rate"])
        avg_regret_delta = float(current_summary["avg_regret"]) - float(previous_summary["avg_regret"])
        pnl_delta = float(current_summary["session_realized_pnl"]) - float(previous_summary["session_realized_pnl"])
        clear_best_delta = float(current_summary["clear_best_rate"]) - float(previous_summary["clear_best_rate"])
        md.append(f"- Previous session id: `{previous_summary['session_id']}`")
        md.append(
            f"- Near-opt rate: `{_fmt_float(float(previous_summary['near_opt_rate']) * 100.0)}%` -> `{_fmt_float(float(current_summary['near_opt_rate']) * 100.0)}%`"
            f" (`{_fmt_float(near_delta * 100.0, 1)}` pts)"
        )
        if confidence_metadata_available and int(previous_summary.get("confidence_metadata_count") or 0) > 0:
            md.append(
                f"- Clear-best support rate: `{_fmt_float(float(previous_summary['clear_best_rate']) * 100.0)}%` -> `{_fmt_float(float(current_summary['clear_best_rate']) * 100.0)}%`"
                f" (`{_fmt_float(clear_best_delta * 100.0, 1)}` pts)"
            )
        md.append(
            f"- Avg regret: `{_fmt_float(float(previous_summary['avg_regret']))}` -> `{_fmt_float(float(current_summary['avg_regret']))}`"
            f" (`{_fmt_float(avg_regret_delta)}`)"
        )
        md.append(
            f"- Session realized P&L: `{_fmt_float(float(previous_summary['session_realized_pnl']))}` -> `{_fmt_float(float(current_summary['session_realized_pnl']))}`"
            f" (`{_fmt_float(pnl_delta)}`)"
        )
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
    if confidence_metadata_available:
        md.append("| ts | hand | street | chosen | top line | confidence | se | regret | tolerance | pot | to_call | user_stack |")
        md.append("|---|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|")
    else:
        md.append("| ts | hand | street | chosen | top line | regret | tolerance | pot | to_call | user_stack |")
        md.append("|---|---:|---|---|---|---:|---:|---:|---:|---:|")
    for e in top:
        confidence = _decision_best_confidence(e) or ""
        stderr = _decision_best_stderr(e)
        if confidence_metadata_available:
            md.append(
                "| {ts} | {hand} | {street} | {chosen} | {top_line} | {confidence} | {stderr} | {regret} | {tol} | {pot} | {to_call} | {stack} |".format(
                    ts=_time_only(str(e.get("ts") or "")),
                    hand=_fmt_int(e.get("hand_id")),
                    street=str(e.get("street") or ""),
                    chosen=str(e.get("chosen_action") or ""),
                    top_line=_top_line_label(e),
                    confidence=confidence,
                    stderr=f"±{_fmt_float(stderr)}" if stderr is not None else "",
                    regret=_fmt_float(float(e.get("regret") or 0.0)),
                    tol=_fmt_float(float(e.get("equivalence_tolerance") or 0.0)),
                    pot=_fmt_int(e.get("pot")),
                    to_call=_fmt_int(e.get("to_call")),
                    stack=_fmt_int(e.get("user_stack")),
                )
            )
        else:
            md.append(
                "| {ts} | {hand} | {street} | {chosen} | {top_line} | {regret} | {tol} | {pot} | {to_call} | {stack} |".format(
                    ts=_time_only(str(e.get("ts") or "")),
                    hand=_fmt_int(e.get("hand_id")),
                    street=str(e.get("street") or ""),
                    chosen=str(e.get("chosen_action") or ""),
                    top_line=_top_line_label(e),
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

    non_equivalent = [
        e
        for e in decisions
        if float(e.get("regret") or 0.0) > max(0.01, float(e.get("equivalence_tolerance") or 0.0))
    ]
    supported_non_equivalent = [e for e in non_equivalent if _decision_has_clear_best(e)]

    worst = max(non_equivalent or decisions, key=lambda e: float(e.get("regret") or 0.0))
    worst_regret = float(worst.get("regret") or 0.0)
    worst_street = str(worst.get("street") or "")
    worst_chosen = str(worst.get("chosen_action") or "")
    worst_best = str(worst.get("best_action") or "")
    worst_supported = (
        max(supported_non_equivalent, key=lambda e: float(e.get("regret") or 0.0))
        if supported_non_equivalent
        else None
    )
    worst_supported_regret = float(worst_supported.get("regret") or 0.0) if worst_supported else 0.0
    worst_supported_street = str(worst_supported.get("street") or "") if worst_supported else ""
    worst_supported_chosen = str(worst_supported.get("chosen_action") or "") if worst_supported else ""
    worst_supported_best = str(worst_supported.get("best_action") or "") if worst_supported else ""
    has_major_leak = bool(worst_supported) and worst_supported_regret > max(
        0.01, float(worst_supported.get("equivalence_tolerance") or 0.0)
    )

    takeaways: list[tuple[str, str]] = []
    used_topics: set[str] = set()

    if previous_summary is not None and decision_count >= 5 and int(previous_summary["decision_count"]) >= 5:
            near_delta = float(current_summary["near_opt_rate"]) - float(previous_summary["near_opt_rate"])
            avg_regret_delta = float(current_summary["avg_regret"]) - float(previous_summary["avg_regret"])
            if abs(near_delta) >= 0.08 or abs(avg_regret_delta) >= 5.0:
                verdict = "improved" if near_delta > 0 and avg_regret_delta <= 0 else "regressed" if near_delta < 0 and avg_regret_delta >= 0 else "mixed"
                if verdict == "improved":
                    title = "**You improved versus the previous session, but the gains are narrow.**"
                elif verdict == "regressed":
                    title = "**This session regressed versus the previous one.**"
                else:
                    title = "**Progress is mixed versus the previous session.**"
                detail = (
                    f"   - Near-opt rate moved from `{_fmt_float(float(previous_summary['near_opt_rate']) * 100.0)}%` to"
                    f" `{_fmt_float(float(current_summary['near_opt_rate']) * 100.0)}%`, while avg regret moved from"
                    f" `{_fmt_float(float(previous_summary['avg_regret']))}` to `{_fmt_float(float(current_summary['avg_regret']))}`."
                )
                takeaways.append(("trend", f"{title}\n{detail}"))
                used_topics.add("trend")

    if confidence_metadata_available and decision_count >= 3 and clear_best_rate < 0.6:
        takeaways.append(
            (
                "confidence",
                (
                    "**A large share of this session was estimate-only, not strong-signal grading.**\n"
                    f"   - Only `{clear_best_count}/{decision_count}` decisions had a clear best line, so treat weak-gap postflop spots as directional coaching rather than firm mistakes."
                ),
            )
        )
        used_topics.add("confidence")

    street_focus = None
    for street, count, near_rate, street_avg_regret, street_total_regret in sorted(
        street_rows,
        key=lambda row: row[4],
        reverse=True,
    ):
        if count >= 2 and total_regret > 0 and street_total_regret >= 0.4 * total_regret:
            street_focus = (street, count, near_rate, street_avg_regret, street_total_regret)
            break
    if street_focus is not None:
        street, count, near_rate, street_avg_regret, street_total_regret = street_focus
        takeaways.append(
            (
                "street",
                (
                    f"**Most of the EV loss is concentrated on the {street}.**\n"
                    f"   - {street.capitalize()} accounted for `{_fmt_float(street_total_regret)}` of `{_fmt_float(total_regret)}` total regret"
                    f" across `{count}` decisions, with near-opt rate `{_fmt_float(near_rate * 100.0)}%`."
                ),
            )
        )
        used_topics.add("street")

    pattern_detail = None
    for item in action_details:
        action = str(item["action"] or "")
        chosen_count = int(item["chosen_count"])
        best_count = int(item["best_count"])
        delta = int(item["delta"])
        total_regret_when_chosen = float(item["total_regret_when_chosen"])
        avg_regret_when_chosen = float(item["avg_regret_when_chosen"])
        top_example = item["top_example"]
        if not action:
            continue
        if abs(delta) < 2:
            continue
        if total_regret_when_chosen < max(10.0, total_regret * 0.12):
            continue
        direction = "overused" if delta > 0 else "underused"
        example_line = ""
        if isinstance(top_example, dict):
            if _decision_has_clear_best(top_example):
                example_line = (
                    f" Biggest example: hand `{_fmt_int(top_example.get('hand_id'))}` {str(top_example.get('street') or '')}"
                    f" where `{action}` lost `{_fmt_float(float(top_example.get('regret') or 0.0))}` EV versus"
                    f" `{str(top_example.get('best_action') or '')}`."
                )
            else:
                example_line = (
                    f" Biggest example: hand `{_fmt_int(top_example.get('hand_id'))}` {str(top_example.get('street') or '')}"
                    f" where `{action}` lost `{_fmt_float(float(top_example.get('regret') or 0.0))}` EV, but the top line was not clearly separated."
                )
        pattern_detail = (
            f"**Your sizing mix is drifting around `{action}`.**\n"
            f"   - You {direction} it: chosen `{chosen_count}` times vs best `{best_count}`, and those choices"
            f" averaged `{_fmt_float(avg_regret_when_chosen)}` regret for `{_fmt_float(total_regret_when_chosen)}` total regret.{example_line}"
        )
        break
    if pattern_detail is not None:
        takeaways.append(("pattern", pattern_detail))
        used_topics.add("pattern")

    if has_major_leak and worst_supported_regret >= max(15.0, total_regret * 0.25):
        if worst_supported_best == "fold" and worst_supported_chosen != "fold":
            title = "**Your biggest leak is still a hard-stop spot.**"
        elif worst_supported_chosen in {"check/call", "check"} and worst_supported_best.startswith("raise"):
            title = "**Your biggest miss was passive when the model wanted pressure.**"
        else:
            title = "**One expensive punt is still distorting the session.**"
        detail = (
            f"   - Hand `{_fmt_int(worst_supported.get('hand_id'))}` {worst_supported_street}: `{worst_supported_chosen}` vs `{worst_supported_best}`"
            f" lost `{_fmt_float(worst_supported_regret)}` EV, which is `{_fmt_float((worst_supported_regret / total_regret) * 100.0 if total_regret else 0.0)}%`"
            f" of total session regret."
        )
        takeaways.append(("punt", f"{title}\n{detail}"))
        used_topics.add("punt")

    if undos >= max(2, round(decision_count * 0.2)):
        takeaways.append(
            (
                "process",
                (
                    f"**Your review process is interrupting flow often enough to matter.**\n"
                    f"   - You used `undo` `{undos}` time(s) ({_fmt_float(undo_rate * 100.0)}% of decisions)."
                    f" Keep the replay, but set a rule: compare one alternative, then commit."
                ),
            )
        )
        used_topics.add("process")
    elif busts:
        takeaways.append(
            (
                "process",
                (
                    f"**Bust outcomes are still being driven by a few decisions, not steady leakage.**\n"
                    f"   - `user_bust` fired `{busts}` time(s). Tag the top non-equivalent hand first rather than treating the whole session as broken."
                ),
            )
        )
        used_topics.add("process")

    if not takeaways:
        if has_major_leak:
            takeaways.append(
                (
                    "fallback",
                    (
                        "**This sample points to one expensive mistake more than a repeat habit.**\n"
                        f"   - Start with hand `{_fmt_int(worst_supported.get('hand_id'))}` {worst_supported_street}: `{worst_supported_chosen}` vs `{worst_supported_best}`"
                        f" lost `{_fmt_float(worst_supported_regret)}` EV."
                    ),
                )
            )
        elif confidence_metadata_available and non_equivalent and not supported_non_equivalent:
            takeaways.append(
                (
                    "fallback",
                    (
                        "**The largest EV gaps in this sample were not strongly separated.**\n"
                        f"   - `{len(non_equivalent)}` non-equivalent decisions were logged, but none had a clear best line, so review them as directional estimates rather than hard leaks."
                    ),
                )
            )
        else:
            takeaways.append(
                (
                    "fallback",
                    (
                        ("**This sample is too thin for a strong behavioral read.**\n"
                         f"   - Only `{decision_count}` decisions were logged, so prioritize volume before drawing conclusions from one bullet or one regret spike.")
                        if decision_count < 3
                        else
                        ("**No strong leak is supported by this sample.**\n"
                         f"   - Biggest recorded regret was `{_fmt_float(worst_regret)}`, which stayed within or near the equivalence threshold, so volume matters more than forcing a narrative.")
                    ),
                )
            )

    for idx, (_, takeaway) in enumerate(takeaways[:4], start=1):
        md.append(f"{idx}. {takeaway}")
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
