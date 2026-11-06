#!/usr/bin/env bash

pkill -f "quickshell -c status-bar"
qs -c status-bar >/dev/null 2>&1 & disown

pkill -f "quickshell -c app-launcher"
qs -c app-launcher >/dev/null 2>&1 & disown

pkill -f "quickshell -c clipboard"

# Stop old clipboard watchers (text and image) so reloads don't stack them up
pkill -f "wl-paste --type (text|image) --watch"

qs -c clipboard >/dev/null 2>&1 & disown
