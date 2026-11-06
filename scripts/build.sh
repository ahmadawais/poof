#!/bin/bash
# Builds build/Poof.app (release, sandboxed, hardened runtime).
# Ad-hoc signed: Poof needs no permission (no TCC grant to keep across builds), so no certificate is needed.
# Override: SIGN_ID="Developer ID Application: …" ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SIGN_ID="${SIGN_ID:--}"
# UNIVERSAL=1: one binary for Apple silicon and Intel (needs full Xcode; release CI uses it).
ARCH=()
if [ "${UNIVERSAL:-}" = 1 ]; then ARCH=(--arch arm64 --arch x86_64); fi
swift build -c release ${ARCH[@]+"${ARCH[@]}"}
BIN="$(swift build -c release ${ARCH[@]+"${ARCH[@]}"} --show-bin-path)/Poof"
if [ ! -f Resources/AppIcon.icns ]; then
  swift scripts/make-icon.swift "cursorarrow.slash" && iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
fi
APP=build/Poof.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Poof"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --options runtime --timestamp=none --entitlements Resources/Poof.entitlements \
  --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($(du -sh "$APP" | cut -f1))"
