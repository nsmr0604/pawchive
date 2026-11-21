#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]] || ! command -v xcrun >/dev/null; then
  echo "Building an iPhone IPA requires macOS with Xcode and the iPhoneOS SDK." >&2
  exit 1
fi
: "${PROBE_OUTPUT:?Set a writable output directory outside the checkout}"
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$PROBE_OUTPUT"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
bundle="$work/Payload/FilesProbe.app"
mkdir -p "$bundle"

plutil -lint "$source_dir/IOSProbeInfo.plist"
cp "$source_dir/IOSProbeInfo.plist" "$bundle/Info.plist"
xcrun --sdk iphoneos swiftc -target arm64-apple-ios14.0 -sdk "$sdk" -parse-as-library \
  -Xlinker -no_adhoc_codesign \
  "$source_dir/IOSProbeApp.swift" "$source_dir/IOSLocalePicker.swift" -o "$bundle/FilesProbe"
load_commands=$(xcrun otool -l "$bundle/FilesProbe")
if grep -q LC_CODE_SIGNATURE <<< "$load_commands"; then
  echo "Expected an unsigned iOS executable." >&2
  exit 1
fi
(cd "$work" && zip -q -r FilesProbe-unsigned.ipa Payload)
unzip -t "$work/FilesProbe-unsigned.ipa"
cp "$work/FilesProbe-unsigned.ipa" "$PROBE_OUTPUT/PawKemoViewer-Files-Probe-unsigned.ipa"
