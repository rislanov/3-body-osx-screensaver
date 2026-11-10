#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/script/version.sh"
case "${1:-}" in
  '') ./script/build.sh ;;
  --no-build) ;;
  *) echo "Usage: $0 [--no-build]" >&2; exit 2 ;;
esac
# Reject stale bundles, broken signatures and diagnostic builds before packaging.
for PRODUCT in ThreeBodyPreview.app ThreeBody.saver; do
  PLIST="dist/$PRODUCT/Contents/Info.plist"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")" == "$BUILD_NUMBER" ]]
  codesign --verify --strict "dist/$PRODUCT"
done
[[ ! -e dist/ThreeBody.saver/Contents/Resources/DiagnosticsEnabled.txt ]]
mkdir -p "$ROOT/build" "$ROOT/dist"
PACKAGE_WORK="$(mktemp -d "$ROOT/build/package.XXXXXX")"
trap 'rm -rf "$PACKAGE_WORK"' EXIT
NAME="ThreeBody-$VERSION-macos-arm64"
PAYLOAD="$PACKAGE_WORK/payload"
mkdir -p "$PAYLOAD/Applications" "$PAYLOAD/Library/Screen Savers"
ditto dist/ThreeBodyPreview.app "$PAYLOAD/Applications/ThreeBodyPreview.app"
ditto dist/ThreeBody.saver "$PAYLOAD/Library/Screen Savers/ThreeBody.saver"
pkgbuild --analyze --root "$PAYLOAD" "$PACKAGE_WORK/components.plist"
python3 - "$PACKAGE_WORK/components.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    components = plistlib.load(f)
for component in components:
    component['BundleIsRelocatable'] = False
    component['BundleOverwriteAction'] = 'upgrade'
with open(path, 'wb') as f:
    plistlib.dump(components, f)
PY
pkgbuild --root "$PAYLOAD" --component-plist "$PACKAGE_WORK/components.plist" \
  --identifier studio.threebody.installer --version "$VERSION" \
  --install-location / --ownership recommended "$PACKAGE_WORK/payload.pkg"
cat > "$PACKAGE_WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>ThreeBody $VERSION</title>
  <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
  <domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
  <allowed-os-versions><os-version min="14.0"/></allowed-os-versions>
  <choices-outline><line choice="default"/></choices-outline>
  <choice id="default" visible="false"><pkg-ref id="studio.threebody.installer"/></choice>
  <pkg-ref id="studio.threebody.installer" version="$VERSION" onConclusion="none">payload.pkg</pkg-ref>
</installer-gui-script>
XML
productbuild --distribution "$PACKAGE_WORK/distribution.xml" --package-path "$PACKAGE_WORK" "dist/$NAME.pkg"
STAGE="$PACKAGE_WORK/$NAME"
mkdir -p "$STAGE"
ditto dist/ThreeBodyPreview.app "$STAGE/ThreeBodyPreview.app"
ditto dist/ThreeBody.saver "$STAGE/ThreeBody.saver"
cp README.md LICENSE SPECIFICATION.md CHANGELOG.md VERSION BUILD_NUMBER "$STAGE/"
ditto docs "$STAGE/docs"
ditto -c -k --keepParent "$STAGE" "dist/$NAME.zip"
(cd dist && shasum -a 256 "$NAME.pkg" "$NAME.zip" > "$NAME.sha256")
printf 'Created dist/%s.{pkg,zip,sha256}\n' "$NAME"
