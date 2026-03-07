# Latest Session Analysis (GPT-5.2)

- Generated: 2026-03-02
- Raw log snapshot cutoff: `2026-03-02T10:42:26Z`
- Canonical bundle: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events_canonical.json`
- Raw audit log: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`

## Session Snapshot

- Session id: `68592037-A909-4E1A-89EA-40DAB796004C`
- Time range: `2026-03-02T10:39:20Z` → `2026-03-02T10:42:26Z`
- Hands: `4` (hands with decisions)
- Decisions: `7`
- Near-optimal (regret <= tolerance): `5/7` (`71.4%`)
- Total regret: `107.7` chips
- Avg regret: `15.4` chips/decision
- Busts: `1`
- Undos: `0` (undo rate `0.0%`)

## Log Integrity Checks

For this session:

- All events had `schema_version=2`, `envelope.schema_name=holdem.play_event`, and `envelope.event_version`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| flop | 4 | 50.0% | 18.4 | 73.7 |
| turn | 3 | 100.0% | 11.3 | 34.0 |

Important nuance: flop is dominated by 1 decision.

- Flop worst regret: `44.7`
- Flop regret excluding the worst: `29.0` across 3 decisions (`9.7` avg)

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 10:41:23Z | 2 | flop | raise_overbet_150_pot | fold | 44.7 | 5.8 | 90 | 15 | 473 |
| 10:41:33Z | 2 | turn | raise_half_pot | raise_min | 29.3 | 41.7 | 1290 | 215 | 323 |
| 10:42:18Z | 4 | flop | bet_overbet_150_pot | bet_quarter_pot | 29.0 | 5.0 | 41 | 0 | 1765 |
| 10:42:04Z | 3 | turn | bet_overbet_125_pot | bet_three_quarter_pot | 4.7 | 18.9 | 378 | 0 | 402 |
| 10:41:01Z | 1 | flop | fold | fold | 0.0 | 39.4 | 90 | 15 | 489 |
| 10:41:50Z | 3 | flop | bet_overbet_150_pot | bet_overbet_150_pot | 0.0 | 18.7 | 54 | 0 | 483 |
| 10:42:26Z | 4 | turn | bet_quarter_pot | bet_quarter_pot | 0.0 | 5.0 | 224 | 0 | 1704 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `raise_overbet_150_pot`: chosen 1 vs best 0 (overused)
- `raise_min`: chosen 0 vs best 1 (underused)
- `raise_half_pot`: chosen 1 vs best 0 (overused)
- `fold`: chosen 1 vs best 2 (underused)
- `bet_three_quarter_pot`: chosen 0 vs best 1 (underused)
- `bet_quarter_pot`: chosen 1 vs best 2 (underused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **When best is `fold`, treat it as a hard stop.**
   - Biggest leak was `raise_overbet_150_pot` vs `fold` on flop (lost `44.7` EV).

2. **Don’t default to overbets; force a comparison against standard sizes.**
   - Overbets tend to be high-variance and are often not robust unless clearly best in the EV map.

3. **Bust review: don’t let a single non-equivalent decision decide the stack.**
   - Tag the biggest-regret hand(s), replay them, and set a goal of 0 busts from non-equivalent actions next session.
