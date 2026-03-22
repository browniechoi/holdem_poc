# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Run the app
```bash
./run_mac.sh
```
Builds Rust core, builds Swift app, then launches with `DYLD_LIBRARY_PATH` set so `libpoker_core.dylib` is found at runtime.

### Build individually
```bash
# Rust engine only
cd poker_core && cargo build --release

# Swift app only (requires libpoker_core.dylib already built)
cd HoldemPOC && swift build
```

### Tests
```bash
# Rust unit tests
cd poker_core && cargo test

# Full pre-release gate (Rust tests + Swift build + Python lint + fixture validation + layout snapshots)
./scripts/pre_release_check.sh
```

### Report fixtures
```bash
# Rewrite golden report fixtures after a legitimate format change
python3 ./scripts/check_report_fixtures.py --rewrite
```

### Layout snapshots
```bash
# Render snapshot pack (6 seeded scenes)
./scripts/render_layout_snapshots.sh

# Bless updated baselines after a legitimate UI change
./scripts/render_layout_snapshots.sh
python3 ./scripts/check_layout_snapshots.py --rewrite
```

### Environment overrides
```bash
OPENAI_API_KEY=... ./run_mac.sh          # enables AI coaching pass at 20-hand benchmark
HOLDEM_OPENAI_MODEL=...                  # override OpenAI model string
HOLDEM_REPORT_OPEN_APP="Sublime Text"   # override editor for Open Report
HOLDEM_UI_WINDOW_WIDTH=1440 HOLDEM_UI_WINDOW_HEIGHT=900 ./scripts/render_layout_snapshots.sh
HOLDEM_UI_SNAPSHOT_DELAY=2.5 ./scripts/render_layout_snapshots.sh
```

## Architecture

### Language split
The engine is Rust (`poker_core/`), the UI is SwiftUI macOS (`HoldemPOC/`). They communicate through a C ABI — Rust compiles to `libpoker_core.dylib`, and Swift calls it via a thin C header + shim.

```
poker_core/src/lib.rs          # entire Rust engine — Game struct, bot AI, EV Monte Carlo, C FFI exports
HoldemPOC/Sources/CPokerCore/include/poker_core.h  # C ABI declaration
HoldemPOC/Sources/CPokerCore/shim.c                # C shim (Swift Package target CPokerCore)
HoldemPOC/Sources/HoldemPOCApp/PokerCore.swift     # Swift wrapper over C ABI, JSON decode
HoldemPOC/Sources/HoldemPOCApp/ContentView.swift   # SwiftUI views
HoldemPOC/Sources/HoldemPOCApp/SessionHistory.swift # Session tracking, analysis status, OpenAI coaching
```

### C ABI surface (`poker_core.h`)
All Rust state lives in an opaque `void* g`. Key functions:
- `pc_new_game(seed, num_players)` / `pc_free_game` / `pc_clone_game` / `pc_copy_game_state`
- `pc_state_json(g)` — returns current `PublicState` as a JSON C string (caller frees with `pc_free_cstring`)
- `pc_actions_with_ev_json(g, iters)` — returns `[ActionEV]` JSON with Monte Carlo EV per action
- `pc_apply_user_action(g, action_code)` — applies user's chosen action
- `pc_step_ai_until_user_or_hand_end(g)` — runs bot turns until it's the user's turn or hand ends
- `pc_step_to_hand_end(g)` / `pc_step_playback_once(g)` / `pc_start_new_training_hand(g)`

### EV calculation
EV is Monte Carlo simulation against the current bot pool using Common Random Numbers (CRN) — all action branches share the same world seed so comparisons are fair. Default `iters=1600`. Near-optimal tolerance is 10% relative with an absolute floor. Adaptive sampling (CI stop rule) is not yet implemented.

### Data flow (turn cycle)
1. Swift calls `core.state()` → decodes `PublicState` JSON → renders UI
2. Swift calls `core.actions(iters:)` → decodes `[ActionEV]` → shows EV panel
3. User picks action → Swift calls `core.act(_:)` → Rust applies action and steps AI turns
4. Repeat until hand ends, then `core.startNewTrainingHand()`

### Persistent logs
All paths under `~/Library/Application Support/HoldemPOC/`:
- `logs/play_events.jsonl` — append-only audit log (never rewritten, schema-versioned)
- `logs/play_events_canonical.json` — derived aggregate, regenerated on each append
- `history/session_history.json` — session index
- `history/reports/` — generated Markdown session reports

Log schema is versioned with an explicit migration contract. Any reader must use the migration contract rather than assuming the latest shape.

### Bot model
Each bot has a `BotStyle` (`tight`, `aggro`, `calliness`, `skill`) and belongs to a `TableProfile` (BalancedMix, LoosePassive, AggroPool, RegHeavy, NittyLineup). The pool profile adapts to the user's `UserPatternProfile` (tracks aggression tells across streets).

### Layout snapshot scenes
Six seeded scenes used for pixel-exact regression: `live_turn`, `all_in_turn`, `showdown`, `long_names`, `long_footer_pills`, `coach_turn`. Baselines live in `tests/fixtures/layout_snapshots/regions.json`.
