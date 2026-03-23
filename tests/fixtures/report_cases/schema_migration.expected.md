# Latest Session Analysis (local)

- Generated: 2026-03-07
- Raw log snapshot cutoff: `2026-03-07T12:11:12Z`
- Canonical bundle: `fixture:play_events_canonical.json`
- Raw audit log: `fixture:schema_migration.jsonl`

## Session Snapshot

- Session id: `FIXTURE_MIGRATE_002`
- Time range: `2026-03-07T12:10:00Z` → `2026-03-07T12:11:12Z`
- Hands: `2` (hands with decisions)
- Decisions: `2`
- Near-optimal (regret <= tolerance): `1/2` (`50.0%`)
- Total regret: `156.6` chips
- Avg regret: `78.3` chips/decision
- Session realized P&L: `-15.0` chips
- Realized P&L delta / decision: `-7.5` chips
- Busts: `0`
- Undos: `1` (undo rate `50.0%`)

## Trend vs Previous Session

No prior session with parseable timestamps was available for comparison.

## Log Integrity Checks

For this session:

- Migration contract: `holdem.play_event_migration.v1`. Readable source schemas: `2`-`4` (seen: `2, 4`), normalized in-memory to `4`.
- Migrated records during analysis: `2/4`.
- `seq` was strictly increasing and matched `envelope.seq`.

## Street Breakdown (Where The EV Was Lost)

| Street | Decisions | Near-opt | Avg regret | Total regret |
|---|---:|---:|---:|---:|
| flop | 1 | 0.0% | 156.6 | 156.6 |
| turn | 1 | 100.0% | 0.0 | 0.0 |

## Top Costly Decisions (By Regret)

| ts | hand | street | chosen | best | regret | tolerance | pot | to_call | user_stack |
|---|---:|---|---|---|---:|---:|---:|---:|---:|
| 12:10:08Z | 8 | flop | bet_third_pot | raise_half_pot | 156.6 | 15.7 | 156 | 0 | 407 |
| 12:11:12Z | 9 | turn | fold | fold | 0.0 | 5.0 | 273 | 43 | 401 |

## Sizing Tendencies (Chosen vs Best)

Biggest gaps in this session:

- `raise_half_pot`: chosen 0 vs best 1 (underused)
- `bet_third_pot`: chosen 1 vs best 0 (overused)

## Coaching Takeaways (What To Do Differently Next 10 Hands)

1. **One expensive punt is still distorting the session.**
   - Hand `8` flop: `bet_third_pot` vs `raise_half_pot` lost `156.6` EV, which is `100.0%` of total session regret.
