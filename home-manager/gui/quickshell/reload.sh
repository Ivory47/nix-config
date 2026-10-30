#!/usr/bin/env bash

pkill -f "quickshell -c status-bar"
qs -c status-bar &


pkill -f "quickshell -c app-launcher"
qs -c app-launcher &


pkill -f "quickshell -c clipboard"
# stop old clipboard watchers so reloads don't stack them up
pkill -f "x-kde-passwordManagerHint"
pkill -f "wl-paste --type image --watch"
qs -c clipboard &
