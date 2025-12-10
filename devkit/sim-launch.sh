#!/bin/sh

if [ -z "$THEOS_DEVICE_SIMULATOR" ]; then
  exit 0
fi

cd "$(dirname "$0")"/.. || exit

DEVICE_ID="2458FACD-57EA-44F8-A8E4-C209B9352CD2"
XCODE_PATH=$(xcode-select -p)

xcrun simctl boot $DEVICE_ID
open "$XCODE_PATH/Applications/Simulator.app"
