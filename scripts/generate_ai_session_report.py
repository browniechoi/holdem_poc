#!/usr/bin/env python3

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from generate_latest_session_report import (
    DEFAULT_RAW_LOG,
    _latest_session_id,
    _load_jsonl,
    _normalize_play_event,
    _previous_session_id,
    _session_summary_for_sid,
    generate_report,
)


RESPONSES_URL = "https://api.openai.com/v1/responses"
DEFAULT_FALLBACK_MODEL = "gpt-5.2"
DEFAULT_REASONING_EFFORT = "xhigh"


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _trim_baseline_report(baseline_report: str) -> str:
    marker = "\n## Coaching Takeaways (What To Do Differently Next 10 Hands)\n"
    if marker in baseline_report:
        return baseline_report.split(marker, 1)[0].rstrip()
    return baseline_report.strip()


def _build_evidence_block(events: list[dict[str, Any]], session_id: str) -> str:
    raw_session_events = [
        event for event in events if (event.get("session_id") or (event.get("envelope") or {}).get("session_id")) == session_id
    ]
    session_events = [_normalize_play_event(event) for event in raw_session_events]
    decisions = [event for event in session_events if event.get("event") == "decision_lock"]
    undo_count = sum(1 for event in session_events if event.get("event") == "undo")
    bust_count = sum(1 for event in session_events if event.get("event") == "user_bust")

    chosen_ctr: collections.Counter[str] = collections.Counter()
    best_ctr: collections.Counter[str] = collections.Counter()
    regret_by_chosen: collections.defaultdict[str, float] = collections.defaultdict(float)
    decisions_by_chosen: collections.defaultdict[str, int] = collections.defaultdict(int)
    by_street: collections.defaultdict[str, list[dict[str, Any]]] = collections.defaultdict(list)

    for decision in decisions:
        chosen_action = str(decision.get("chosen_action") or "(missing)")
        best_action = str(decision.get("best_action") or "(missing)")
        chosen_ctr[chosen_action] += 1
        best_ctr[best_action] += 1
        regret_by_chosen[chosen_action] += _safe_float(decision.get("regret"))
        decisions_by_chosen[chosen_action] += 1
        by_street[str(decision.get("street") or "unknown")] += [decision]

    street_order = {"preflop": 0, "flop": 1, "turn": 2, "river": 3}
    street_summary: list[dict[str, Any]] = []
    for street, street_decisions in sorted(by_street.items(), key=lambda item: street_order.get(item[0], 99)):
        decision_count = len(street_decisions)
        near_opt_count = sum(
            1
            for decision in street_decisions
            if _safe_float(decision.get("regret")) <= _safe_float(decision.get("equivalence_tolerance"))
        )
        avg_regret = (
            sum(_safe_float(decision.get("regret")) for decision in street_decisions) / decision_count if decision_count else 0.0
        )
        street_summary.append(
            {
                "street": street,
                "decisions": decision_count,
                "near_opt_count": near_opt_count,
                "near_opt_rate": round((near_opt_count / decision_count) if decision_count else 0.0, 4),
                "average_regret": round(avg_regret, 2),
            }
        )

    top_leaks = []
    for decision in sorted(decisions, key=lambda event: _safe_float(event.get("regret")), reverse=True)[:5]:
        top_leaks.append(
            {
                "hand_id": _safe_int(decision.get("hand_id")),
                "street": str(decision.get("street") or "unknown"),
                "chosen_action": str(decision.get("chosen_action") or ""),
                "best_action": str(decision.get("best_action") or ""),
                "chosen_ev": round(_safe_float(decision.get("chosen_ev")), 2),
                "best_ev": round(_safe_float(decision.get("best_ev")), 2),
                "regret": round(_safe_float(decision.get("regret")), 2),
                "tolerance": round(_safe_float(decision.get("equivalence_tolerance")), 2),
                "pot": _safe_int(decision.get("pot")),
                "to_call": _safe_int(decision.get("to_call")),
                "user_stack": _safe_int(decision.get("user_stack")),
                "session_realized_pnl": round(_safe_float(decision.get("session_realized_pnl")), 2),
            }
        )

    action_mismatches: list[dict[str, Any]] = []
    for action in sorted(set(chosen_ctr) | set(best_ctr)):
        chosen_count = int(chosen_ctr.get(action, 0))
        best_count = int(best_ctr.get(action, 0))
        if chosen_count == best_count:
            continue
        action_mismatches.append(
            {
                "action": action,
                "chosen_count": chosen_count,
                "best_count": best_count,
                "delta": chosen_count - best_count,
                "avg_regret_when_chosen": round(
                    (regret_by_chosen[action] / decisions_by_chosen[action]) if decisions_by_chosen[action] else 0.0,
                    2,
                ),
            }
        )
    action_mismatches.sort(key=lambda item: abs(_safe_int(item["delta"])), reverse=True)

    decision_count = len(decisions)
    near_opt_count = sum(
        1
        for decision in decisions
        if _safe_float(decision.get("regret")) <= _safe_float(decision.get("equivalence_tolerance"))
    )
    previous_session_id = _previous_session_id(events, session_id)
    previous_summary = _session_summary_for_sid(events, previous_session_id) if previous_session_id else None
    previous_comparison = None
    if previous_summary is not None:
        current_avg_regret = (
            sum(_safe_float(decision.get("regret")) for decision in decisions) / decision_count if decision_count else 0.0
        )
        current_realized_pnl = _safe_float(decisions[-1].get("session_realized_pnl")) if decisions else 0.0
        current_near_opt_rate = (near_opt_count / decision_count) if decision_count else 0.0
        previous_comparison = {
            "previous_session_id": previous_session_id,
            "near_opt_rate_delta": round(current_near_opt_rate - _safe_float(previous_summary.get("near_opt_rate")), 4),
            "avg_regret_delta": round(current_avg_regret - _safe_float(previous_summary.get("avg_regret")), 2),
            "session_realized_pnl_delta": round(
                current_realized_pnl - _safe_float(previous_summary.get("session_realized_pnl")),
                2,
            ),
            "previous_session_overview": previous_summary,
        }
    evidence = {
        "session_id": session_id,
        "session_overview": {
            "decision_count": decision_count,
            "undo_count": undo_count,
            "undo_rate": round((undo_count / decision_count) if decision_count else 0.0, 4),
            "bust_count": bust_count,
            "near_opt_count": near_opt_count,
            "near_opt_rate": round((near_opt_count / decision_count) if decision_count else 0.0, 4),
            "average_regret": round(
                (sum(_safe_float(decision.get("regret")) for decision in decisions) / decision_count) if decision_count else 0.0,
                2,
            ),
            "session_realized_pnl": round(
                _safe_float(decisions[-1].get("session_realized_pnl")) if decisions else 0.0,
                2,
            ),
        },
        "action_frequency": {
            "chosen_counts": dict(sorted(chosen_ctr.items())),
            "best_counts": dict(sorted(best_ctr.items())),
            "largest_mismatches": action_mismatches[:6],
            "avg_regret_by_chosen_action": {
                action: round(regret_by_chosen[action] / decisions_by_chosen[action], 2)
                for action in sorted(decisions_by_chosen)
                if decisions_by_chosen[action]
            },
        },
        "street_summary": street_summary,
        "top_leaks": top_leaks,
        "previous_session_comparison": previous_comparison,
    }
    return json.dumps(evidence, indent=2, sort_keys=True)


def _build_prompt(
    session_id: str,
    benchmark_hands: int,
    benchmark_target: int,
    benchmark_clean_hands: int,
    evidence_json: str,
    baseline_report: str,
) -> str:
    trimmed_baseline = _trim_baseline_report(baseline_report)
    return f"""You are reviewing a beginner-to-intermediate Hold'em training session.

Benchmark window:
- Clean hands: {benchmark_clean_hands}/{benchmark_hands}
- Target clean hands: {benchmark_target}/{benchmark_hands}

Requirements:
- Write concise Markdown with useful substance, not generic coach filler.
- Focus on decision quality, betting and bluffing mind games, and mathematical discipline.
- Keep it beginner/intermediate friendly, but do not talk down to the player.
- The JSON evidence block is authoritative. The local markdown report is secondary context.
- Do not dump raw logs or internal schema details.
- Identify 2-4 concrete behavioral patterns only if the evidence supports them.
- Every takeaway must cite evidence such as hand ids, streets, action-count mismatches, regret values, undo rate, or bust count.
- If previous-session comparison is present, explain what actually changed instead of restating the same advice in slightly different wording.
- Do not repeat the same leak in multiple bullets with different wording.
- Do not mention overbets, undo habits, or busts unless the evidence clearly supports that topic.
- Distinguish between a repeat pattern and a single expensive punt.
- If the evidence is thin or mixed, say that directly instead of inventing a strong narrative.
- Explain EV intuition in plain English for a player who still does not fully understand it.
- Include a short section on how the app itself should improve based on this player's session data.
- Call out if the player looks too pattern-driven or too sizing-predictable, but only if the action-frequency evidence supports it.
- End with a short \"Next 20 Hands\" section.

Required output structure:
## Session Verdict
## Evidence-Based Leaks
## EV Intuition
## App Improvements
## Next 20 Hands

Bad example:
- "Don't default to overbets."

Good example:
- "On the turn you chose `raise 150% pot` 4 times while the best action matched that size once; the biggest miss was hand 18 turn where `raise 150% pot` lost 22.4 EV versus `call`."

Session id: {session_id}

Structured evidence derived from the raw audit log:

```json
{evidence_json}
```

Local baseline report derived from the raw audit log:

{trimmed_baseline}
"""


def _extract_output_text(payload: dict[str, Any]) -> str:
    output_text = payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    pieces: list[str] = []
    for item in payload.get("output", []):
        if not isinstance(item, dict):
            continue
        for content in item.get("content", []):
            if not isinstance(content, dict):
                continue
            text = content.get("text")
            if isinstance(text, str) and text.strip():
                pieces.append(text.strip())
    return "\n\n".join(pieces).strip()


def _request_analysis(model: str, prompt: str, api_key: str, reasoning_effort: str) -> str:
    body = {
        "model": model,
        "reasoning": {"effort": reasoning_effort},
        "instructions": (
            "You are a rigorous poker coach and product advisor. Use the supplied evidence JSON as the primary "
            "source of truth. Do not give generic poker advice that is not anchored to the evidence. Separate repeat "
            "patterns from one-off punts, explain EV in plain language, and say explicitly when the evidence is weak "
            "or mixed. Explain what the player's session says about decision quality, bluffing discipline, betting "
            "logic, mathematical clarity, and how the training app should change to better teach this specific player."
        ),
        "input": prompt,
    }
    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        RESPONSES_URL,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(body)
            error_obj = payload.get("error") or {}
            message = error_obj.get("message") or body
        except json.JSONDecodeError:
            message = body or str(exc)
        raise RuntimeError(message) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(str(exc)) from exc

    text = _extract_output_text(payload)
    if not text:
        raise RuntimeError("OpenAI response did not contain output_text.")
    return text


def _run_with_model_fallback(prompt: str, api_key: str) -> tuple[str, str]:
    preferred_model = os.environ.get("HOLDEM_OPENAI_MODEL", DEFAULT_FALLBACK_MODEL).strip() or DEFAULT_FALLBACK_MODEL
    preferred_effort = os.environ.get("HOLDEM_OPENAI_REASONING_EFFORT", DEFAULT_REASONING_EFFORT).strip() or DEFAULT_REASONING_EFFORT
    candidates: list[str] = []
    for model in (preferred_model, DEFAULT_FALLBACK_MODEL):
        if model not in candidates:
            candidates.append(model)

    effort_candidates: list[str] = []
    for effort in (preferred_effort, "high", "medium"):
        if effort not in effort_candidates:
            effort_candidates.append(effort)

    errors: list[str] = []
    for model in candidates:
        for effort in effort_candidates:
            try:
                text = _request_analysis(model=model, prompt=prompt, api_key=api_key, reasoning_effort=effort)
                return f"{model} ({effort})", text
            except RuntimeError as exc:
                errors.append(f"{model} ({effort}): {exc}")

    raise SystemExit(" | ".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate an OpenAI coaching report for a logged HoldemPOC session.")
    parser.add_argument("--raw-log", type=Path, default=DEFAULT_RAW_LOG, help="Path to play_events.jsonl")
    parser.add_argument("--out", type=Path, required=True, help="Output markdown path")
    parser.add_argument("--session-id", type=str, default=None, help="Specific session id to analyze")
    parser.add_argument("--benchmark-hands", type=int, default=20, help="Benchmark window size")
    parser.add_argument("--benchmark-target", type=int, default=16, help="Target clean hands")
    parser.add_argument("--benchmark-clean-hands", type=int, default=0, help="Actual clean hands achieved")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not set.")

    events = _load_jsonl(args.raw_log)
    if args.session_id:
        session_id = args.session_id
    else:
        session_id, _ = _latest_session_id(events)

    baseline_report = generate_report(events, session_id)
    evidence_json = _build_evidence_block(events, session_id)
    prompt = _build_prompt(
        session_id=session_id,
        benchmark_hands=args.benchmark_hands,
        benchmark_target=args.benchmark_target,
        benchmark_clean_hands=args.benchmark_clean_hands,
        evidence_json=evidence_json,
        baseline_report=baseline_report,
    )
    model_used, coach_report = _run_with_model_fallback(prompt=prompt, api_key=api_key)

    generated_at = dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    markdown = "\n".join(
        [
            f"# Session Coaching Report ({model_used})",
            "",
            f"- Generated at: `{generated_at}`",
            f"- Session id: `{session_id}`",
            f"- Benchmark: `{args.benchmark_clean_hands}/{args.benchmark_hands}` clean hands (target `{args.benchmark_target}`)",
            "",
            coach_report.strip(),
            "",
        ]
    )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(markdown)
    print(f"MODEL_USED={model_used}")
    print(f"Wrote {args.out} for session {session_id}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
