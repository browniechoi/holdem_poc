#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACT_DIR="${1:-$ROOT_DIR/artifacts/pre_release}"
SNAPSHOT_DIR="$ARTIFACT_DIR/layout_snapshots"

mkdir -p "$ARTIFACT_DIR"

echo "== Rust engine tests =="
(cd "$ROOT_DIR/poker_core" && cargo test -q)

echo "== Rust release build =="
(cd "$ROOT_DIR/poker_core" && cargo build --release -q)

echo "== Swift app build =="
(cd "$ROOT_DIR/HoldemPOC" && swift build -q)

echo "== Python analysis scripts =="
python3 -m py_compile \
  "$ROOT_DIR/scripts/generate_latest_session_report.py" \
  "$ROOT_DIR/scripts/generate_ai_session_report.py" \
  "$ROOT_DIR/scripts/check_report_fixtures.py" \
  "$ROOT_DIR/scripts/check_layout_snapshots.py"

echo "== Golden report fixtures =="
python3 "$ROOT_DIR/scripts/check_report_fixtures.py"

echo "== Deterministic layout snapshots =="
HOLDEM_SKIP_BUILD=1 "$ROOT_DIR/scripts/render_layout_snapshots.sh" "$SNAPSHOT_DIR"

echo "== Approved layout baselines =="
python3 "$ROOT_DIR/scripts/check_layout_snapshots.py" \
  --current-dir "$SNAPSHOT_DIR" \
  --diff-dir "$ARTIFACT_DIR/layout_snapshot_diffs"

echo
printf 'Pre-release checks passed.\nArtifacts: %s\n' "$ARTIFACT_DIR"
