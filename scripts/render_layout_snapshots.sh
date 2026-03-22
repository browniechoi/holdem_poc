#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/artifacts/layout_snapshots/current}"
shift || true

DEFAULT_SCENES=(live_turn all_in_turn showdown footer_showdown long_names long_footer_pills coach_turn)
if [ "$#" -gt 0 ]; then
  SCENES=("$@")
else
  SCENES=("${DEFAULT_SCENES[@]}")
fi

WINDOW_WIDTH="${HOLDEM_UI_WINDOW_WIDTH:-1440}"
WINDOW_HEIGHT="${HOLDEM_UI_WINDOW_HEIGHT:-900}"
SNAPSHOT_DELAY="${HOLDEM_UI_SNAPSHOT_DELAY:-2.5}"

mkdir -p "$OUTPUT_DIR"

if [ "${HOLDEM_SKIP_BUILD:-0}" != "1" ]; then
  (cd "$ROOT_DIR/poker_core" && cargo build --release -q)
  (cd "$ROOT_DIR/HoldemPOC" && swift build -q)
fi

APP_BIN="$(cd "$ROOT_DIR/HoldemPOC" && swift build --show-bin-path)/HoldemPOC"
DYLD_PATH="$ROOT_DIR/poker_core/target/release:${DYLD_LIBRARY_PATH:-}"

pkill HoldemPOC >/dev/null 2>&1 || true

for scene in "${SCENES[@]}"; do
  out="$OUTPUT_DIR/${scene}.png"
  rm -f "$out"
  echo "Rendering $scene -> $out"
  DYLD_LIBRARY_PATH="$DYLD_PATH" \
  HOLDEM_LAYOUT_DEBUG_SCENE="$scene" \
  HOLDEM_UI_SNAPSHOT_PATH="$out" \
  HOLDEM_UI_SNAPSHOT_DELAY="$SNAPSHOT_DELAY" \
  HOLDEM_UI_WINDOW_WIDTH="$WINDOW_WIDTH" \
  HOLDEM_UI_WINDOW_HEIGHT="$WINDOW_HEIGHT" \
  "$APP_BIN"
  if [ ! -s "$out" ]; then
    echo "Snapshot missing or empty for $scene: $out" >&2
    exit 1
  fi
done

INDEX_PATH="$OUTPUT_DIR/index.md"
{
  echo "# Layout Snapshots"
  echo
  echo "- Window: ${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
  echo "- Scenes: ${SCENES[*]}"
  echo
  for scene in "${SCENES[@]}"; do
    echo "## ${scene}"
    echo
    echo "![$scene](./${scene}.png)"
    echo
  done
} > "$INDEX_PATH"

echo "Wrote snapshots to $OUTPUT_DIR"
echo "Index: $INDEX_PATH"
