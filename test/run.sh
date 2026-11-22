#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${PLUGIN_DIR:-$ROOT}"

: "${OMARCHY_PATH:?OMARCHY_PATH is not set}"

for command_name in node omarchy qmllint; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "missing required command: $command_name" >&2
    exit 1
  fi
done

echo "== Node model tests =="
node --test "$ROOT/test/model.test.js"

echo "== Plugin manifest =="
omarchy plugin validate "$PLUGIN_DIR"

echo "== QML lint =="
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" \
  "$PLUGIN_DIR/Panel.qml" \
  "$PLUGIN_DIR/HistoryStore.qml" \
  "$PLUGIN_DIR/DumpRow.qml" \
  "$PLUGIN_DIR/NoticeCard.qml"

echo "All checks passed."
