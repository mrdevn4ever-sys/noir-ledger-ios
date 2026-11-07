#!/usr/bin/env bash
# Fails if the Release app binary contains any trace of the Debug-only QA accelerator.
# Usage: verify_release_exclusion.sh <Release .app path>
set -euo pipefail
APP="$1"
BIN="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
echo "Release binary: $BIN ($(stat -f%z "$BIN") bytes)"
hits=0
for marker in "-qa-scenario" "-qa-timescale" "-qa-reset" "QAAccelerator" "playFinalOperation" "replaceState" "final_ready"; do
  n=$( (strings -a "$BIN"; nm -a "$BIN" 2>/dev/null | (xcrun swift-demangle 2>/dev/null || cat)) | grep -c -- "$marker" || true)
  echo "marker '$marker': $n"
  hits=$((hits + n))
done
if [ "$hits" -ne 0 ]; then
  echo "RELEASE_EXCLUSION_FAIL"
  exit 1
fi
echo "RELEASE_EXCLUSION_OK"
