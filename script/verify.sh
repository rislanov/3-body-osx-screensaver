#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p artifacts
swift test -c release > artifacts/core-tests.log 2>&1
./script/build.sh > artifacts/build.log 2>&1
codesign --verify --strict dist/ThreeBodyPreview.app
codesign --verify --strict dist/ThreeBody.saver
open -W -n "$ROOT/dist/ThreeBodyPreview.app" --args --lifecycle-test --log "$ROOT/artifacts/lifecycle.log"
[[ "$(grep -c 'PASS' artifacts/lifecycle.log)" == 20 ]]
for SIZE in 320x200 1920x1080 2520x1080; do
  open -W -n "$ROOT/dist/ThreeBodyPreview.app" --args --preset eight --seed 42 --time 12 --size "$SIZE" --snapshot "$ROOT/artifacts/frame-$SIZE.png"
  [[ -s "$ROOT/artifacts/frame-$SIZE.png" ]]
done
printf 'Core tests, signatures, 20 saver lifecycle cycles and 3 frame sizes passed.\n'
