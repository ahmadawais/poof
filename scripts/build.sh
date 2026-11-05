#!/bin/bash
# Builds build/Poof.app (release, sandboxed, hardened runtime).
# Signs with this Mac's "AA Local Code Signing" identity when it exists (~/.dotfiles/setup/codesign-identity.sh):
# same signature every build, so macOS keeps the Accessibility grant. Else ad-hoc (grant resets each build).
# Override: SIGN_ID="Other Identity" ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${SIGN_ID:-}" ]; then
  SIGN_ID=-
  security find-certificate -c "AA Local Code Signing" > /dev/null 2>&1 && SIGN_ID="AA Local Code Signing"
fi
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Poof"
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
