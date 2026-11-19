#!/bin/sh
# The "close" key for Quickshell widgets (hyprland.lua runs this instead of closing a window).
# Every running Quickshell shell that is a widget has an IPC target `widget` with `closeIfOpen()`
# (GlassPopup has it built in; shells that are not widgets do not, and the call just fails). This asks
# all of them at once and, if none was open, closes the focused window as the bind normally would.
# A new widget needs nothing here: give its shell the `widget` target.
any=0
tmp=$(mktemp -d) || exit 1
for pid in $(qs list --all 2>/dev/null | sed -n 's/^ *Process ID: *//p'); do
    qs ipc --pid "$pid" call widget closeIfOpen >"$tmp/$pid" 2>/dev/null &
done
wait
grep -qx true "$tmp"/* 2>/dev/null && any=1
rm -rf "$tmp"
[ "$any" = 1 ] || hyprctl dispatch "hyprWindowCloseRaw()" >/dev/null
