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

Optional OpenAI coaching pass for the 10-hand benchmark:

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
