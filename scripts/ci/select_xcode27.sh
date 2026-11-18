#!/usr/bin/env bash
# Pin all Noir CI steps to one stable Xcode 27 installation and iOS SDK.
set -euo pipefail
XCODE_APP=$(ls -d /Applications/Xcode_27*.app 2>/dev/null | grep -viE 'beta|release_candidate|_rc' | sort -V | tail -n 1 || true)
if [ -z "$XCODE_APP" ] || [ ! -d "$XCODE_APP/Contents/Developer" ]; then
  echo '::error::No stable Xcode 27 app is installed' >&2
  exit 1
fi
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
XCODE_VERSION=$(xcodebuild -version | sed -n '1s/^Xcode //p')
IOS_SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version)
SIM_SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
if [[ ! "$XCODE_VERSION" =~ ^27(\.[0-9]+)*$ ]] ||
   [[ ! "$IOS_SDK_VERSION" =~ ^27(\.[0-9]+)*$ ]] ||
   [[ ! "$SIM_SDK_VERSION" =~ ^27(\.[0-9]+)*$ ]]; then
  echo "::error::Expected Xcode/iOS SDK 27; got Xcode=$XCODE_VERSION, iPhoneOS=$IOS_SDK_VERSION, iPhoneSimulator=$SIM_SDK_VERSION" >&2
  exit 1
fi
printf 'Xcode %s (%s); iPhoneOS %s; simulator %s\n' "$XCODE_VERSION" "$XCODE_APP" "$IOS_SDK_VERSION" "$SIM_SDK_VERSION"
if [ -n "${GITHUB_ENV:-}" ]; then
  printf 'DEVELOPER_DIR=%s\n' "$DEVELOPER_DIR" >> "$GITHUB_ENV"
fi
