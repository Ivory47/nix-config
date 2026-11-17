#!/usr/bin/env bash

# Lucent (the Hyprland plugin, ~/Documents/Code/Lucent): make sure the installed build is the one
# that is loaded, before the shells restart (they look for its marker when they start).
#   - not loaded: load it
#   - loaded, same build as last time: nothing
#   - loaded, a different build was installed since (or unknown): unload and load again
#   - the old build called "pane" is loaded: it cannot be swapped here, restart Hyprland
# The state file lives in this Hyprland instance's runtime directory, so it is new for every start.
lucent=/etc/hypr/plugins/liblucent.so
if [ -e "$lucent" ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    state="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/lucent-build"
    build="$(readlink -f "$lucent")"
    loaded="$(hyprctl plugin list 2>/dev/null)"
    if grep -q '^Plugin pane' <<<"$loaded"; then
        echo "qsr: the old 'pane' plugin is loaded; restart Hyprland to get Lucent" >&2
    elif grep -q '^Plugin lucent' <<<"$loaded"; then
        if [ "$(cat "$state" 2>/dev/null)" != "$build" ]; then
            echo "qsr: reloading Lucent ($build)"
            hyprctl plugin unload "$lucent" >/dev/null
            sleep 1
            hyprctl plugin load "$lucent" >/dev/null && echo "$build" >"$state"
        fi
    else
        echo "qsr: loading Lucent ($build)"
        hyprctl plugin load "$lucent" >/dev/null && echo "$build" >"$state"
    fi
    # Let the shells see the new marker before they start.
    sleep 1
fi

pkill -f "quickshell -c status-bar"
qs -c status-bar >/dev/null 2>&1 & disown

pkill -f "quickshell -c app-launcher"
qs -c app-launcher >/dev/null 2>&1 & disown

pkill -f "quickshell -c settings"
qs -c settings >/dev/null 2>&1 & disown

pkill -f "quickshell -c wallpapers"
qs -c wallpapers >/dev/null 2>&1 & disown

pkill -f "quickshell -c clipboard"

# Stop old clipboard watchers (text and image) so reloads don't stack them up
pkill -f "wl-paste --type (text|image) --watch"

qs -c clipboard >/dev/null 2>&1 & disown
