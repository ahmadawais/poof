#!/bin/bash
# Build, install to /Applications, (re)launch. Poof needs no permissions.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
pkill -x Poof 2>/dev/null || true
for _ in $(seq 50); do pgrep -xq Poof || break; sleep 0.1; done  # let it quit, or `open` fails with -600
rm -rf /Applications/Poof.app
cp -R build/Poof.app /Applications/Poof.app
open /Applications/Poof.app
echo "Installed /Applications/Poof.app"
