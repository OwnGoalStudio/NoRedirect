#!/bin/sh

if [ -z "$THEOS_DEVICE_SIMULATOR" ]; then
  exit 0
fi

cd $(dirname $0)/..

DEVICE_ID="92CCA0BB-A0A5-4DB9-A023-0F6C44D959E4"
XCODE_PATH=$(xcode-select -p)

xcrun simctl boot $DEVICE_ID
open $XCODE_PATH/Applications/Simulator.app
