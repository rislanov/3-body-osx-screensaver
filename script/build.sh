#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/script/version.sh"
SDK="$(xcrun --show-sdk-path)"
# Never carry stale shader binaries or diagnostic resources into a new build.
rm -rf dist/ThreeBodyPreview.app dist/ThreeBody.saver
rm -f build/ThreeBody.air build/ThreeBody.metallib
mkdir -p build dist/ThreeBodyPreview.app/Contents/{MacOS,Resources} dist/ThreeBody.saver/Contents/{MacOS,Resources}
if xcrun metal --version >/dev/null 2>&1; then
xcrun metal -c Sources/Rendering/Shaders.metal -o build/ThreeBody.air -std=macos-metal2.4 -mmacosx-version-min=14.0
xcrun metallib build/ThreeBody.air -o build/ThreeBody.metallib
else
  echo "Metal compiler component unavailable: bundling shader source for offline runtime compilation."
fi
COMMON=(Sources/Core/*.swift Sources/Rendering/*.swift)
FLAGS=(-O -whole-module-optimization -target arm64-apple-macos14.0 -sdk "$SDK" -swift-version 5 -framework AppKit -framework Metal -framework MetalKit -framework IOKit)
xcrun swiftc "${FLAGS[@]}" "${COMMON[@]}" Sources/Preview/*.swift -framework AVFoundation -framework ScreenSaver -o dist/ThreeBodyPreview.app/Contents/MacOS/ThreeBodyPreview
xcrun swiftc "${FLAGS[@]}" "${COMMON[@]}" Sources/Saver/*.swift -emit-library -module-name ThreeBodySaver -Xlinker -bundle -framework ScreenSaver -o dist/ThreeBody.saver/Contents/MacOS/ThreeBody
for PRODUCT in ThreeBodyPreview.app ThreeBody.saver; do
  cp Resources/ThreeBody.icns "dist/$PRODUCT/Contents/Resources/"
  cp Sources/Rendering/Shaders.metal "dist/$PRODUCT/Contents/Resources/"
  if [[ -f build/ThreeBody.metallib ]]; then cp build/ThreeBody.metallib "dist/$PRODUCT/Contents/Resources/"; fi
done
cp Resources/thumbnail.png Resources/thumbnail@2x.png dist/ThreeBody.saver/Contents/Resources/
python3 - <<'PY'
import os
import plistlib
for folder,exe,identifier,kind,principal in [('ThreeBodyPreview.app','ThreeBodyPreview','studio.threebody.preview','APPL','NSApplication'),('ThreeBody.saver','ThreeBody','studio.threebody.saver','BNDL','ThreeBodySaver.ThreeBodyView')]:
    d=dict(CFBundleExecutable=exe,CFBundleIdentifier=identifier,CFBundleName='ThreeBody',CFBundlePackageType=kind,CFBundleVersion=os.environ['BUILD_NUMBER'],CFBundleShortVersionString=os.environ['VERSION'],LSMinimumSystemVersion='14.0',NSPrincipalClass=principal,NSHighResolutionCapable=True,CFBundleIconFile='ThreeBody',NSHumanReadableCopyright='ThreeBody contributors')
    if kind == 'BNDL': d['ScreenSaverThumbnail'] = 'thumbnail.png'
    with open('dist/'+folder+'/Contents/Info.plist','wb') as f: plistlib.dump(d,f)
PY
rm -f dist/ThreeBody.saver/Contents/Resources/DiagnosticsEnabled.txt
if [[ "${THREEBODY_DIAGNOSTICS:-0}" == "1" ]]; then
  printf "Local renderer diagnostic probe\n" > dist/ThreeBody.saver/Contents/Resources/DiagnosticsEnabled.txt
fi
codesign --force --sign - dist/ThreeBodyPreview.app
codesign --force --sign - dist/ThreeBody.saver
