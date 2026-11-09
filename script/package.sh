#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "${1:-}" != "--no-build" ]]; then ./script/build.sh; fi
mkdir -p "$ROOT/build" "$ROOT/dist"
PACKAGE_WORK="$(mktemp -d "$ROOT/build/package.XXXXXX")"
trap 'rm -rf "$PACKAGE_WORK"' EXIT
STAGE="$PACKAGE_WORK/ThreeBody-development"
mkdir -p "$STAGE"
ditto dist/ThreeBodyPreview.app "$STAGE/ThreeBodyPreview.app"
ditto dist/ThreeBody.saver "$STAGE/ThreeBody.saver"
cp README.md LICENSE SPECIFICATION.md "$STAGE/"
ditto docs "$STAGE/docs"
ditto -c -k --keepParent "$STAGE" dist/ThreeBody-development.zip
shasum -a 256 dist/ThreeBody-development.zip > dist/ThreeBody-development.zip.sha256
