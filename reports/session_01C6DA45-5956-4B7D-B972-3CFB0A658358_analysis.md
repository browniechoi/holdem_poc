# Latest Session Analysis (GPT-5.2)

- Generated: 2026-03-02
- Raw log snapshot cutoff: `2026-03-02T10:14:36Z`
- Canonical bundle: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events_canonical.json`
- Raw audit log: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`

## Session Snapshot

- Session id: `01C6DA45-5956-4B7D-B972-3CFB0A658358`
- Time range: `2026-03-02T10:06:37Z` → `2026-03-02T10:14:36Z`
- Hands: `12` (hands with decisions)
- Decisions: `31`
- Near-optimal (regret <= tolerance): `23/31` (`74.2%`)
- Total regret: `965.6` chips
- Avg regret: `31.1` chips/decision
- Busts: `0`
- Undos: `1` (undo rate `3.2%`)

## Log Integrity Checks

For this session:

- All events had `schema_version=2`, `envelope.schema_name=holdem.play_event`, and `envelope.event_version`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| flop | 12 | 83.3% | 5.0 | 59.9 |
| turn | 10 | 70.0% | 5.1 | 50.9 |
| river | 9 | 66.7% | 95.0 | 854.8 |

Important nuance: flop is dominated by 1 decision.

- Flop worst regret: `40.1`
- Flop regret excluding the worst: `19.8` across 11 decisions (`1.8` avg)

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 10:11:17Z | 5 | river | check/call | bet_quarter_pot | 677.4 | 67.7 | 1606 | 0 | 694 |
| 10:07:28Z | 3 | river | bet_pot | bet_quarter_pot | 138.5 | 13.8 | 656 | 0 | 1793 |
| 10:11:49Z | 7 | flop | raise_half_pot | fold | 40.1 | 5.7 | 40 | 8 | 276 |
| 10:12:52Z | 9 | river | bet_half_pot | check/call | 38.9 | 11.3 | 165 | 0 | 589 |
| 10:11:06Z | 5 | turn | bet_three_quarter_pot | bet_quarter_pot | 27.7 | 5.0 | 402 | 0 | 995 |
| 10:14:03Z | 11 | flop | bet_half_pot | bet_pot | 16.4 | 5.0 | 39 | 0 | 491 |
| 10:14:11Z | 11 | turn | bet_pot | bet_quarter_pot | 14.3 | 5.0 | 115 | 0 | 472 |
| 10:12:46Z | 9 | turn | bet_three_quarter_pot | bet_quarter_pot | 5.4 | 5.0 | 51 | 0 | 627 |
| 10:12:40Z | 9 | flop | bet_quarter_pot | bet_three_quarter_pot | 2.5 | 5.0 | 30 | 0 | 634 |
| 10:07:23Z | 3 | turn | bet_pot | check/call | 2.2 | 5.0 | 164 | 0 | 1957 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `bet_quarter_pot`: chosen 7 vs best 11 (underused)
- `bet_pot`: chosen 10 vs best 7 (overused)
- `check/call`: chosen 1 vs best 3 (underused)
- `bet_half_pot`: chosen 3 vs best 1 (overused)
- `raise_half_pot`: chosen 3 vs best 2 (overused)
- `fold`: chosen 2 vs best 3 (underused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **Undo is fine; use it to protect EV, not to chase perfection.**
   - You used `undo` 1 time(s). If you undo, immediately re-check `bet_quarter_pot` vs 1 alternative and commit.
