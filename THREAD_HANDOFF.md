# Thread Handoff (Recovered)

- Original thread id: `019ca5f6-f8de-78b1-9897-ffa5c2b087cc`
- Recovery date: `2026-03-02`
- Workspace: `/Users/gyuhyo/holdem_poc`

## Objective
Ship a playable macOS Texas Hold'em training app POC (Rust engine + Swift UI) with per-decision EV guidance, practical coaching feedback, and persistent logs for offline AI analysis.

## Current Status
- Rust core and SwiftUI app are both implemented and runnable via `./run_mac.sh`.
- Event logging is implemented at `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`.
- Log schema in current file is versioned, event-typed, and carries an explicit migration contract.
- Many UI/UX iterations were completed, but repeated user reports indicate some seat/footer clipping/layout edge cases still appeared during rapid iterations.
- EV comparison uses shared world seeds per decision node (CRN) for fair action comparison.
- Adaptive sampling is not implemented yet.

## Key Assumptions / Constraints
- POC-first architecture: Rust owns game truth + EV, Swift renders and orchestrates interaction.
- EV is Monte Carlo against current bot pool, not solved GTO equilibrium EV.
- Manual analysis pipeline: logs are generated locally and can be post-processed by LLMs.
- App targets macOS now; iOS is a later extension.

## Important Decisions Already Made
- Language split: `Rust` engine + `SwiftUI` desktop client through C ABI.
- Runtime logging: JSONL append-only events with base state snapshot fields and event-specific extras.
- Near-optimal feedback tolerance: currently percentage + absolute floor logic in UI (`10%` with absolute floor in current code path).
- Session economics: starting stack and bust/reload flows were expanded from the original toy setup.

## Files Of Interest
- Engine:
  - `/Users/gyuhyo/holdem_poc/poker_core/src/lib.rs`
  - `/Users/gyuhyo/holdem_poc/poker_core/Cargo.toml`
- Swift bridge and app:
  - `/Users/gyuhyo/holdem_poc/HoldemPOC/Sources/HoldemPOCApp/PokerCore.swift`
  - `/Users/gyuhyo/holdem_poc/HoldemPOC/Sources/HoldemPOCApp/ContentView.swift`
  - `/Users/gyuhyo/holdem_poc/HoldemPOC/Sources/CPokerCore/include/poker_core.h`
  - `/Users/gyuhyo/holdem_poc/HoldemPOC/Sources/CPokerCore/shim.c`
- Build/run:
  - `/Users/gyuhyo/holdem_poc/run_mac.sh`
- Persistent play log:
  - `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`

## Open Issues / Risks
- Adaptive sampling is not yet wired, so wider action trees still increase EV noise.
- Some legacy raw-log readers may still assume older schema behavior if they do not use the migration contract.
- Confidence intervals and uncertainty are still not surfaced, even though the tolerance basis is now visible in the decision panel and header.
- UI layout still has known seat/footer crowding risk under some table states.

## Strongest Next Steps
1. Add adaptive EV sampling (`N=200 -> 800 -> 1500`) using paired-difference CI stop rule.
2. Add a baseline-EV track separate from pool EV so users can distinguish exploitative success from fundamentally sound play.
3. Keep migrating every log reader/script to the explicit schema contract instead of assuming the latest shape.
4. Continue tightening UI transparency: tolerance rule, best/worst EV used, and optional confidence interval.

## Copy-Paste Starter Prompt For New Thread
```text
Continue from /Users/gyuhyo/holdem_poc using THREAD_HANDOFF.md and thread id 019ca5f6-f8de-78b1-9897-ffa5c2b087cc.

Priority:
1) Add adaptive sampling with paired-difference CI stop rule.
2) Add baseline EV alongside current pool EV.
3) Continue improving tolerance/confidence transparency in UI and reports.

Constraints:
- Keep app runnable via ./run_mac.sh
- Keep JSONL backward-compatible
- Add targeted tests for determinism, schema stability, and ranking stability
```
