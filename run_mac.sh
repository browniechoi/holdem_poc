#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

pkill HoldemPOC >/dev/null 2>&1 || true

cd "$ROOT_DIR/poker_core"
cargo build --release

cd "$ROOT_DIR/HoldemPOC"
swift build
APP_BIN="$(swift build --show-bin-path)/HoldemPOC"
echo "Launching HoldemPOC GUI..."
DYLD_LIBRARY_PATH="$ROOT_DIR/poker_core/target/release:${DYLD_LIBRARY_PATH:-}" "$APP_BIN"
