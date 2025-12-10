#!/bin/bash

set -e

if [ "$THEOS_PACKAGE_SCHEME" = "rootless" ]; then
    /usr/libexec/PlistBuddy -c 'Set :ProgramArguments:0 /var/jb/usr/libexec/NoRedirectUI' "$THEOS_STAGING_DIR/Library/LaunchDaemons/com.82flex.noredirect.plist"
fi
