#!/usr/bin/env bash
# Source from build/release scripts; metadata is data, never executable shell.
VERSION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$VERSION_ROOT/VERSION")"
BUILD_NUMBER="$(cat "$VERSION_ROOT/BUILD_NUMBER")"
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo 'VERSION must contain MAJOR.MINOR.PATCH without leading zeros.' >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,3}$ ]]; then
  echo 'BUILD_NUMBER must be an integer from 1 to 9999.' >&2
  exit 1
fi
if [[ "${GITHUB_REF_TYPE:-}" == tag && "${GITHUB_REF_NAME:-}" != "v$VERSION" ]]; then
  echo "Release tag must match VERSION: expected v$VERSION." >&2
  exit 1
fi
export VERSION BUILD_NUMBER
