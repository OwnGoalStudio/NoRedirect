#!/bin/bash

SIMULATOR_IDS=$(xcrun simctl list devices available | grep -E Booted | sed "s/^[ \t]*//" | tr " " "\n")

REAL_SIMULATOR_ID=
for SIMULATOR_ID in $SIMULATOR_IDS; do
    # shellcheck disable=SC2001
    SIMULATOR_ID=$(echo "$SIMULATOR_ID" | sed 's/[()]//g')
    if [[ $SIMULATOR_ID =~ ^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$ ]]; then
        REAL_SIMULATOR_ID=$SIMULATOR_ID
        break
    fi
done

if [ -z "$REAL_SIMULATOR_ID" ]; then
    echo "No booted simulator found"
    exit 1
fi

SIMULATOR_DATA_PATH=$HOME/Library/Developer/CoreSimulator/Devices/$SIMULATOR_ID/data

ln -sfn .. "$SIMULATOR_DATA_PATH/var/mobile"

echo "$SIMULATOR_DATA_PATH"
