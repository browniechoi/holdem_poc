# Latest Session Analysis (GPT-5.2)

- Generated: 2026-03-02
- Raw log snapshot cutoff: `2026-03-02T11:13:25Z`
- Canonical bundle: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events_canonical.json`
- Raw audit log: `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`

## Session Snapshot

- Session id: `BF6C24D3-7AB7-4988-BD1E-866789405C66`
- Time range: `2026-03-02T11:09:28Z` → `2026-03-02T11:13:25Z`
- Hands: `5` (hands with decisions)
- Decisions: `13`
- Near-optimal (regret <= tolerance): `6/13` (`46.2%`)
- Total regret: `1209.4` chips
- Avg regret: `93.0` chips/decision
- Busts: `0`
- Undos: `3` (undo rate `23.1%`)

## Log Integrity Checks

For this session:

- All events had `schema_version=2`, `envelope.schema_name=holdem.play_event`, and `envelope.event_version`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| flop | 7 | 42.9% | 70.7 | 494.7 |
| turn | 4 | 50.0% | 44.6 | 178.5 |
| river | 2 | 50.0% | 268.1 | 536.2 |

Important nuance: turn is dominated by 1 decision.

- Turn worst regret: `149.2`
- Turn regret excluding the worst: `29.2` across 3 decisions (`9.7` avg)

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 11:13:05Z | 4 | river | bet_overbet_125_pot | bet_half_pot | 536.2 | 53.6 | 2548 | 0 | 2743 |
| 11:11:28Z | 2 | flop | bet_pot | bet_overbet_200_pot | 154.8 | 34.2 | 46 | 0 | 1501 |
| 11:12:19Z | 3 | turn | fold | raise_min | 149.2 | 19.1 | 453 | 151 | 3590 |
| 11:13:21Z | 5 | flop | bet_quarter_pot | bet_overbet_200_pot | 124.0 | 12.4 | 42 | 0 | 7055 |
| 11:12:08Z | 3 | flop | raise_half_pot | fold | 120.8 | 32.8 | 63 | 21 | 3642 |
| 11:12:37Z | 4 | flop | bet_overbet_150_pot | bet_overbet_200_pot | 78.9 | 25.3 | 52 | 0 | 3575 |
| 11:11:38Z | 2 | turn | bet_overbet_200_pot | bet_three_quarter_pot | 29.2 | 9.3 | 414 | 0 | 1409 |
| 11:09:51Z | 1 | flop | raise_overbet_150_pot | raise_overbet_200_pot | 16.3 | 78.8 | 91 | 18 | 495 |
| 11:10:00Z | 1 | turn | raise_half_pot | raise_half_pot | 0.0 | 99.4 | 861 | 172 | 341 |
| 11:11:32Z | 2 | flop | bet_overbet_200_pot | bet_overbet_200_pot | 0.0 | 34.2 | 46 | 0 | 1501 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `bet_overbet_200_pot`: chosen 4 vs best 6 (underused)
- `raise_overbet_200_pot`: chosen 0 vs best 1 (underused)
- `raise_overbet_150_pot`: chosen 1 vs best 0 (overused)
- `raise_min`: chosen 0 vs best 1 (underused)
- `raise_half_pot`: chosen 2 vs best 1 (overused)
- `bet_three_quarter_pot`: chosen 0 vs best 1 (underused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **Don’t default to overbets; force a comparison against standard sizes.**
   - Overbets tend to be high-variance and are often not robust unless clearly best in the EV map.

2. **Undo is fine; use it to protect EV, not to chase perfection.**
   - You used `undo` 3 time(s). If you undo, immediately re-check `bet_half_pot` vs 1 alternative and commit.
