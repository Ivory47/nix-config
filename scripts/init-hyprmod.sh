#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DIR="${SCRIPT_DIR}/../home-manager/hypr"
TARGET_FILE="${TARGET_DIR}/hyprland-gui.lua"

if [ -d "$TARGET_DIR" ]; then
    touch "$TARGET_FILE"
else
    echo "Error: Directory $TARGET_DIR needs to exist to setup hyprmod"
    exit 1
fi
