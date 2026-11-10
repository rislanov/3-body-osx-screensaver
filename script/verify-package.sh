#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/script/version.sh"
NAME="ThreeBody-$VERSION-macos-arm64"
(cd dist && shasum -a 256 -c "$NAME.sha256")
WORK="$(mktemp -d "$ROOT/build/verify-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pkgutil --expand-full "dist/$NAME.pkg" "$WORK/expanded"
python3 - "$WORK/expanded" <<'PY'
import os, pathlib, plistlib, struct, subprocess, sys
import xml.etree.ElementTree as ET
root = pathlib.Path(sys.argv[1])
distribution = ET.parse(root / 'Distribution').getroot()
assert distribution.find('options').get('hostArchitectures') == 'arm64'
assert distribution.find('allowed-os-versions/os-version').get('min') == '14.0'
info = ET.parse(root / 'payload.pkg/PackageInfo').getroot()
assert info.get('version') == os.environ['VERSION']
assert info.get('install-location') == '/'
payload = root / 'payload.pkg/Payload'
for relative in ('Applications/ThreeBodyPreview.app', 'Library/Screen Savers/ThreeBody.saver'):
    bundle = payload / relative
    with (bundle / 'Contents/Info.plist').open('rb') as f:
        metadata = plistlib.load(f)
    assert metadata['CFBundleShortVersionString'] == os.environ['VERSION']
    assert metadata['CFBundleVersion'] == os.environ['BUILD_NUMBER']
    assert not (bundle / 'Contents/Resources/DiagnosticsEnabled.txt').exists()
    if bundle.suffix == '.saver':
        assert metadata['ScreenSaverThumbnail'] == 'thumbnail.png'
        for name, dimensions in [('thumbnail.png', (480, 312)), ('thumbnail@2x.png', (960, 624))]:
            data = (bundle / 'Contents/Resources' / name).read_bytes()
            assert data[:8] == b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II', data[16:24]) == dimensions
    subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
    subprocess.run(['lipo', str(bundle / 'Contents/MacOS' / metadata['CFBundleExecutable']), '-verify_arch', 'arm64'], check=True)
print('Package payload, versions, architecture, signatures and checksums passed.')
PY
