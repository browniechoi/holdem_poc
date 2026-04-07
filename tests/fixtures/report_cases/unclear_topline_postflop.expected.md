# Latest Session Analysis (local)

- Generated: 2026-03-07
- Raw log snapshot cutoff: `2026-03-07T12:30:30Z`
- Canonical bundle: `fixture:play_events_canonical.json`
- Raw audit log: `fixture:unclear_topline_postflop.jsonl`

## Session Snapshot

- Session id: `FIXTURE_UNCLEAR_004`
- Time range: `2026-03-07T12:30:00Z` → `2026-03-07T12:30:30Z`
- Hands: `1` (hands with decisions)
- Decisions: `1`
- Near-optimal (regret <= tolerance): `0/1` (`0.0%`)
- Total regret: `12.5` chips
- Avg regret: `12.5` chips/decision
- Supported clear-best decisions: `0/1` (`0.0%`)
- Avg best-line standard error: `±28.5` chips
- Session realized P&L: `0.0` chips
- Realized P&L delta / decision: `0.0` chips
- Busts: `0`
- Undos: `0` (undo rate `0.0%`)

## Trend vs Previous Session

No prior session with parseable timestamps was available for comparison.

## Log Integrity Checks

For this session:

- Migration contract: `holdem.play_event_migration.v1`. Readable source schemas: `2`-`4` (seen: `4`), normalized in-memory to `4`.
- Migrated records during analysis: `0/3`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| turn | 1 | 0.0% | 12.5 | 12.5 |

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | top line | confidence | se | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|
| 12:30:09Z | 3 | turn | check/call | unclear (low-confidence) | low | ±28.5 | 12.5 | 5.0 | 180 | 42 | 370 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `raise_pot`: chosen 0 vs best 1 (underused)
- `check/call`: chosen 1 vs best 0 (overused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **The largest EV gaps in this sample were not strongly separated.**
   - `1` non-equivalent decisions were logged, but none had a clear best line, so review them as directional estimates rather than hard leaks.
