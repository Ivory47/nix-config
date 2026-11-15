#!/usr/bin/env bash
# Measures how far the glass is behind what it blurs, without touching the running shells.
#
# Starts two throwaway Quickshell instances for a few seconds: `load` (a test background on the
# Top layer) and `probe` (an Overlay-layer strip with the same GlassBackdrop and GlassPanel as the
# status bar, over that background; no input). The probe runs with WAYLAND_DEBUG=1, and
# timeline.py reads from its log what became of every capture. Both show on screen while it runs.
#
# usage: run.sh <mode> <seconds> <tag>
#   mode    sweep  coloured bars move every frame (timeline.py)
#           ramp   the whole background changes every frame (timeline.py)
#           pulse  one white bar; with LAGCAP=1 the real screen is recorded (pulse.py)
#           idle   nothing moves (must give no updates)
# environment:
#   PROBE_Y, PROBE_H  place and height of the strip, logical px (252 and 51; 0 and the screen
#                     height for a surface like the popups'). Multiples of 3 at scale 1.333.
#   GLASS_QML         .../lib/qt-6/qml of a Glass.Native build to test instead of the deployed one
#                     (see CLAUDE.md for the nix build command)
#   LAGCAP=1          record with Lucent's lagcap (LAGCAP_BIN, default ~/Documents/Code/Lucent/tools/build/lagcap)
#   OUT               where the logs go (default: a new directory under $XDG_RUNTIME_DIR)
# Results: $OUT/probe-<tag>.log + clocks-<tag>.txt (timeline.py), lagcap-<tag>.txt (pulse.py).
# Processes are stopped by PID. Never use pkill -f here (see CLAUDE.md).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mode="$1"; secs="$2"; tag="$3"
export PROBE_Y="${PROBE_Y:-252}" PROBE_H="${PROBE_H:-51}"
OUT="${OUT:-$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/glass-latency.XXXXXX")}"; mkdir -p "$OUT"

# The probe needs `shared/` next to it, with the compiled shaders: take the deployed copy.
work="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/glass-probe.XXXXXX")"
cp -r "$here/probe" "$work/probe" && cp -rL "$HOME/.config/quickshell/status-bar/shared" "$work/probe/shared" || exit 1
chmod -R u+w "$work"

LOAD_MODE="$mode" setsid qs -p "$here/load" >"$OUT/load-$tag.log" 2>&1 &
LP=$!
sleep 0.8
if [ -n "${GLASS_QML:-}" ]; then
    # What the deployed wrapper starts, without its own Glass.Native path in front of ours.
    real="$(sed -n 's/^exec -a "\$0" "\([^"]*\)".*/\1/p' "$(readlink -f "$(command -v qs)")")"
    WAYLAND_DEBUG=1 QSG_NO_VSYNC=1 QML_IMPORT_PATH="$GLASS_QML" QML2_IMPORT_PATH="$GLASS_QML" setsid "$real" -p "$work/probe" >"$OUT/probe-$tag.log" 2>&1 &
else
    WAYLAND_DEBUG=1 setsid qs -p "$work/probe" >"$OUT/probe-$tag.log" 2>&1 &
fi
PP=$!
trap 'kill $PP $LP 2>/dev/null; rm -rf "$work"' EXIT
sleep 3.5   # the capture's warm-up
python3 -c "import time;print('CLOCKS', time.clock_gettime(time.CLOCK_REALTIME), time.clock_gettime(time.CLOCK_MONOTONIC))" >"$OUT/clocks-$tag.txt"

cpu() { awk '{print $14+$15}' "/proc/$1/stat" 2>/dev/null; }
# GPU render-engine time of a process in ns (one value per drm client).
gpu() { cat /proc/$1/fdinfo/* 2>/dev/null | awk '/^drm-client-id/{id=$2} /^drm-engine-render/{v[id]=$2} END{s=0; for(i in v) s+=v[i]; print s+0}'; }
# The compositor: the Hyprland process with the most CPU time (its watchdog has the same name).
HP=$(for p in $(pgrep -x .Hyprland-wrapp); do echo "$(cpu "$p") $p"; done | sort -n | tail -1 | cut -d' ' -f2)

qs ipc -p "$work/probe" call glassprobe stats >"$OUT/stats1-$tag.json"
c1p=$(cpu $PP); c1h=$(cpu "$HP"); g1p=$(gpu $PP); g1h=$(gpu "$HP"); t1=$(date +%s.%N)
if [ "${LAGCAP:-0}" = 1 ]; then
    # A (plain view, below the strip) and B (behind the glass), same x, physical pixels at scale 4/3.
    ax=$(( 720*4/3 )); ay=$(( (PROBE_Y+PROBE_H+60)*4/3 )); by=$(( (PROBE_Y+PROBE_H/2)*4/3 ))
    "${LAGCAP_BIN:-$HOME/Documents/Code/Lucent/tools/build/lagcap}" "$secs" $ax $ay $ax $by >"$OUT/lagcap-$tag.txt" 2>"$OUT/lagcap-$tag.err"
else
    sleep "$secs"
fi
c2p=$(cpu $PP); c2h=$(cpu "$HP"); g2p=$(gpu $PP); g2h=$(gpu "$HP"); t2=$(date +%s.%N)
qs ipc -p "$work/probe" call glassprobe stats >"$OUT/stats2-$tag.json"
kill $PP $LP 2>/dev/null

python3 - "$OUT/stats1-$tag.json" "$OUT/stats2-$tag.json" "$c1p" "$c2p" "$c1h" "$c2h" "$t1" "$t2" "$g1p" "$g2p" "$g1h" "$g2h" <<'PY'
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
c1p, c2p, c1h, c2h, t1, t2, g1p, g2p, g1h, g2h = map(float, sys.argv[3:13]); dt = t2 - t1
def d(k, s='capture'): return (b[s][k] - a[s][k]) / dt
print("%.1f s, clean=%s, capture %s" % (dt, b['pipeline']['clean'], b['size']['capture']))
print("per second: requests %.1f answers %.1f published %.1f duplicates %.1f updates %.1f window frames %.1f" % (
    d('requests'), d('completions'), d('published'), d('duplicates'), d('updatesScheduled', 'pipeline'), d('frames')))
print("CPU %%: probe %.1f, Hyprland %.1f | GPU render-engine busy %%: probe %.1f, Hyprland %.1f" % (
    (c2p - c1p) / dt, (c2h - c1h) / dt, (g2p - g1p) / dt / 1e7, (g2h - g1h) / dt / 1e7))
PY
echo "logs: $OUT  (python3 $here/timeline.py $OUT/probe-$tag.log $OUT/clocks-$tag.txt)"
