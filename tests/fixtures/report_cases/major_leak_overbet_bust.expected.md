# Latest Session Analysis (local)

- Generated: 2026-03-07
- Raw log snapshot cutoff: `2026-03-07T12:20:30Z`
- Canonical bundle: `fixture:play_events_canonical.json`
- Raw audit log: `fixture:major_leak_overbet_bust.jsonl`

## Session Snapshot

- Session id: `FIXTURE_MAJOR_003`
- Time range: `2026-03-07T12:20:00Z` → `2026-03-07T12:20:30Z`
- Hands: `1` (hands with decisions)
- Decisions: `2`
- Near-optimal (regret <= tolerance): `0/2` (`0.0%`)
- Total regret: `113.0` chips
- Avg regret: `56.5` chips/decision
- Session realized P&L: `-500.0` chips
- Realized P&L delta / decision: `-250.0` chips
- Busts: `1`
- Undos: `2` (undo rate `100.0%`)

## Trend vs Previous Session

No prior session with parseable timestamps was available for comparison.

## Log Integrity Checks

For this session:

- Migration contract: `holdem.play_event_migration.v1`. Readable source schemas: `2`-`4` (seen: `4`), normalized in-memory to `4`.
- Migrated records during analysis: `0/6`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| flop | 1 | 0.0% | 25.0 | 25.0 |
| river | 1 | 0.0% | 88.0 | 88.0 |

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 12:20:20Z | 7 | river | check/call | fold | 88.0 | 8.0 | 1240 | 88 | 237 |
| 12:20:06Z | 7 | flop | raise_overbet_150_pot | bet_half_pot | 25.0 | 5.0 | 315 | 0 | 325 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `raise_overbet_150_pot`: chosen 1 vs best 0 (overused)
- `fold`: chosen 0 vs best 1 (underused)
- `check/call`: chosen 1 vs best 0 (overused)
- `bet_half_pot`: chosen 0 vs best 1 (underused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **Your biggest leak is still a hard-stop spot.**
   - Hand `7` river: `check/call` vs `fold` lost `88.0` EV, which is `77.9%` of total session regret.

2. **Your review process is interrupting flow often enough to matter.**
   - You used `undo` `2` time(s) (100.0% of decisions). Keep the replay, but set a rule: compare one alternative, then commit.
