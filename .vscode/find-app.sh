#!/bin/bash

# Find the Dedup.app in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Dedup.app" -type d 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/Dedup"
    if [ -f "$EXECUTABLE_PATH" ]; then
        echo "$EXECUTABLE_PATH"
        exit 0
    fi
fi

# Fallback to local build directory
LOCAL_PATH="${workspaceFolder}/build/Debug/Dedup.app/Contents/MacOS/Dedup"
if [ -f "$LOCAL_PATH" ]; then
    echo "$LOCAL_PATH"
    exit 0
fi

# If not found, exit with error
echo "Dedup.app not found in DerivedData or local build directory" >&2
exit 1 