#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
pkill -x ThreeBodyPreview >/dev/null 2>&1 || true
./script/build.sh
case "${1:-run}" in
  run) open -n "$ROOT/dist/ThreeBodyPreview.app" ;;
  --verify) open -n "$ROOT/dist/ThreeBodyPreview.app"; sleep 1; pgrep -x ThreeBodyPreview >/dev/null ;;
  --debug) lldb -- "$ROOT/dist/ThreeBodyPreview.app/Contents/MacOS/ThreeBodyPreview" ;;
  --logs|--telemetry) open -n "$ROOT/dist/ThreeBodyPreview.app"; /usr/bin/log stream --info --style compact --predicate 'process == "ThreeBodyPreview"' ;;
  *) echo "Usage: $0 [run|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
