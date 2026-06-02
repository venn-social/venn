#!/usr/bin/env bash
set -euo pipefail

# Select or create a booted iOS simulator for CI, then expose an xcodebuild
# destination through GITHUB_ENV. GitHub's macOS images do not consistently
# ship with the same pre-created simulator devices, so workflows should target
# the selected UDID rather than a hardcoded device name.

SIMULATOR_NAME="${1:-Venn CI iPhone}"

runtime="$(
  xcrun simctl list runtimes available -j |
    jq -r '[.runtimes[] | select(.platform == "iOS") | .identifier] | last // empty'
)"

if [[ -z "$runtime" ]]; then
  echo "::error::No available iOS simulator runtime found."
  exit 1
fi

device_type="$(
  xcrun simctl list devicetypes -j |
    jq -r '
      [.devicetypes[]
        | select(
          .name == "iPhone 17 Pro" or
          .name == "iPhone 16 Pro" or
          .name == "iPhone 15 Pro" or
          .name == "iPhone 14 Pro"
        )
        | .identifier
      ][0] // empty
    '
)"

if [[ -z "$device_type" ]]; then
  echo "::error::No compatible iPhone simulator device type found."
  exit 1
fi

udid="$(
  xcrun simctl list devices available -j |
    jq -r --arg name "$SIMULATOR_NAME" '
      [.devices[][] | select(.name == $name) | .udid][0] // empty
    '
)"

if [[ -z "$udid" ]]; then
  udid="$(xcrun simctl create "$SIMULATOR_NAME" "$device_type" "$runtime")"
fi

destination="platform=iOS Simulator,id=$udid"
echo "Selected simulator destination: $destination"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "TEST_DESTINATION=$destination" >>"$GITHUB_ENV"
fi
