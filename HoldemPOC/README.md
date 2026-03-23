# HoldemPOC (macOS SwiftUI + Rust)

## Run

From workspace root:

```bash
./run_mac.sh
```

This script:
1. Builds Rust core (`poker_core`)
2. Runs the SwiftUI macOS app with `DYLD_LIBRARY_PATH` set so `libpoker_core.dylib` is found.

## Build only

```bash
cd HoldemPOC
swift build
```

## Open in Xcode

```bash
open /Users/gyuhyo/holdem_poc/HoldemPOC/Package.swift
```

If you run from Xcode, make sure `libpoker_core.dylib` is built first and discoverable at runtime.

## Logs and Analysis Bundle

Raw append-only event log (audit source of truth):

- `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events.jsonl`

Canonical model-input bundle (derived from raw log, regenerated on each append):

- `/Users/gyuhyo/Library/Application Support/HoldemPOC/logs/play_events_canonical.json`

The raw JSONL is never rewritten; canonical aggregates are emitted separately for analysis workflows.

Session history index:

- `/Users/gyuhyo/Library/Application Support/HoldemPOC/history/session_history.json`

Generated session reports:

- `/Users/gyuhyo/Library/Application Support/HoldemPOC/history/reports/`

Optional OpenAI coaching pass for the 20-hand benchmark:

- Set `OPENAI_API_KEY` before launch to enable the API call.
- Optionally set `HOLDEM_OPENAI_MODEL` to override the preferred model string.
- Optionally set `HOLDEM_REPORT_OPEN_APP` to force `Open Report` to use a lighter editor, for example:

```bash
HOLDEM_REPORT_OPEN_APP="Sublime Text" ./run_mac.sh
```

You can also pass a full app path, for example:

```bash
HOLDEM_REPORT_OPEN_APP="/Applications/Sublime Text.app" ./run_mac.sh
```

## Deterministic Layout Snapshots

Seeded layout harness scenes are available for regression checks:

- `live_turn`
- `all_in_turn`
- `showdown`
- `long_names`
- `long_footer_pills`
- `coach_turn`

Render the full snapshot pack:

```bash
./scripts/render_layout_snapshots.sh
```

Snapshot rendering now fails fast if ScreenCaptureKit cannot capture the seeded app window.
The harness defaults to a longer capture delay tuned for stable showdown snapshots; override it only if you are intentionally testing faster captures.

Artifacts are written to:

- `/Users/gyuhyo/holdem_poc/artifacts/layout_snapshots/current/`

Useful overrides:

```bash
HOLDEM_UI_WINDOW_WIDTH=1440 HOLDEM_UI_WINDOW_HEIGHT=900 ./scripts/render_layout_snapshots.sh
HOLDEM_UI_SNAPSHOT_DELAY=2.5 ./scripts/render_layout_snapshots.sh
```

## Pre-Release Check

Run the full local gate before shipping:

```bash
./scripts/pre_release_check.sh
```

That command runs:

1. `cargo test -q`
2. `cargo build --release -q`
3. `swift build -q`
4. `python3 -m py_compile` for report scripts and fixture checker
5. golden report fixture validation
6. deterministic layout snapshot rendering
7. pixel-exact layout baseline diffing

Critical UI regions are also asserted from:

- `/Users/gyuhyo/holdem_poc/tests/fixtures/layout_snapshots/regions.json`

To rewrite golden reports intentionally after a legitimate report-format change:

```bash
python3 ./scripts/check_report_fixtures.py --rewrite
```

To bless updated layout baselines intentionally after a legitimate UI change:

```bash
./scripts/render_layout_snapshots.sh
python3 ./scripts/check_layout_snapshots.py --rewrite
```
