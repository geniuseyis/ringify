#!/bin/bash
# Run on a development Mac with existing Xcode/XcodeGen. No installation or publishing.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  printf '%s\n' 'Native validation requires macOS and Xcode.' >&2
  exit 1
fi
for tool in swift xcodebuild xcodegen xcrun; do
  command -v "$tool" >/dev/null || { printf 'Missing required tool: %s\n' "$tool" >&2; exit 1; }
done
if [[ -z "${1:-}" ]]; then
  printf '%s\n' 'Provide an installed iPhone Simulator UDID: scripts/validate-native.sh <UDID>' >&2
  xcrun simctl list devices available
  exit 1
fi
SIMULATOR_UDID="$1"
if [[ ! "$SIMULATOR_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  printf '%s\n' 'Invalid Simulator UDID.' >&2
  exit 1
fi
swift --version
swift build --package-path "$ROOT_DIR/packages/RingifyCore"
swift test --package-path "$ROOT_DIR/packages/RingifyCore"
cd "$ROOT_DIR/ios"
xcodegen generate --spec project.yml
RESULTS_DIR="$ROOT_DIR/artifacts/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"
xcodebuild -project Ringify.xcodeproj -scheme Ringify -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$RESULTS_DIR/DerivedData" \
  -resultBundlePath "$RESULTS_DIR/Tests.xcresult" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Ringify.xcodeproj -scheme Ringify -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$RESULTS_DIR/DerivedData" CODE_SIGNING_ALLOWED=NO build
printf 'Simulator validation completed. Evidence: %s\n' "$RESULTS_DIR"
printf '%s\n' 'Device, audio quality, StoreKit sandbox, signed Archive and App Store acceptance are still separate gates.'
