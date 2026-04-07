# Latest Session Analysis (local)

- Generated: 2026-03-07
- Raw log snapshot cutoff: `2026-03-07T12:00:20Z`
- Canonical bundle: `fixture:play_events_canonical.json`
- Raw audit log: `fixture:equivalent_near_opt.jsonl`

## Session Snapshot

- Session id: `FIXTURE_EQUIV_001`
- Time range: `2026-03-07T12:00:00Z` → `2026-03-07T12:00:20Z`
- Hands: `1` (hands with decisions)
- Decisions: `1`
- Near-optimal (regret <= tolerance): `1/1` (`100.0%`)
- Total regret: `0.0` chips
- Avg regret: `0.0` chips/decision
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
| flop | 1 | 100.0% | 0.0 | 0.0 |

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | top line | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 12:00:05Z | 1 | flop | check/call | check/call | 0.0 | 5.0 | 100 | 20 | 480 |

## Sizing Tendencies (Chosen vs Best)

Chosen action counts matched best-action counts exactly in this snapshot.

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **This sample is too thin for a strong behavioral read.**
   - Only `1` decisions were logged, so prioritize volume before drawing conclusions from one bullet or one regret spike.
