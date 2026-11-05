#!/usr/bin/env python3
"""Measures what the live glass costs Hyprland, and what its counters say.

Needs the status bar to run with `ipcTarget: "glass"` on its GlassBackdrop (it does). Each
scenario sets the pipeline through `qs ipc`, waits for things to settle, and then reads CPU time
from /proc for Hyprland and for the status bar, plus the capture and validation counters, over a
few seconds.

    python3 measure.py [seconds] [scenario ...]

Scenarios (see SCENARIOS below). Without names: glass-off and normal.
Put the desktop in the state you want to measure first (static, something moving behind the bar,
...): this script does not move anything.
"""
import json
import os
import subprocess
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")


def pids_where(pred):
    out = []
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            comm = open(f"/proc/{p}/comm").read().strip()
            cmd = open(f"/proc/{p}/cmdline", "rb").read().split(b"\0")
        except OSError:
            continue
        if pred(comm, cmd):
            out.append(int(p))
    return out


def hyprland_pid():
    return pids_where(lambda c, _: c.lower().startswith(".hyprland-wrapp") or c == "Hyprland")[0]


def bar_pid():
    return pids_where(lambda c, cmd: "quickshell" in c and b"status-bar" in cmd and b"glass-test" not in b" ".join(cmd))[0]


def cpu_ticks(pid):
    total = 0
    main = 0
    for tid in os.listdir(f"/proc/{pid}/task"):
        try:
            s = open(f"/proc/{pid}/task/{tid}/stat").read()
        except OSError:
            continue
        f = s[s.rindex(")") + 2:].split()
        t = int(f[11]) + int(f[12])
        total += t
        if int(tid) == pid:
            main = t
    return total, main


def ipc(*args):
    r = subprocess.run(["qs", "ipc", "-c", "status-bar", "call", "glass", *map(str, args)], capture_output=True, text=True, timeout=30)
    return r.stdout.strip()


def stats():
    return json.loads(ipc("stats"))


NORMAL = [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setWholeOutput", "true"),
          ("setDepth", 1), ("setDmabuf", "true"), ("setInterval", 0), ("setPoolLimit", 0), ("setForceReject", "false"),
          ("setDiagnostics", "true")]

SCENARIOS = {
    "glass-off": ("glass switched off completely: the bar with a plain tinted rectangle", [("setGlass", "false")]),
    "capture-off": ("glass drawn, capture not requested", NORMAL + [("setCapture", "false")]),
    "capture-only": ("capture received and thrown away", NORMAL + [("setProcessing", "false")]),
    "normal": ("the whole pipeline as it is meant to run (whole output, dmabuf, one request)", NORMAL),
    "pool-2": ("normal, but the pool is limited to 2 dmabufs (forces exhaustion)", NORMAL + [("setPoolLimit", 2)]),
    "reject": ("normal, but every capture is treated as the wrong frame", NORMAL + [("setForceReject", "true")]),
}


def run(name, seconds, settle=3.0):
    desc, settings = SCENARIOS[name]
    for fn, arg in settings:
        ipc(fn, arg)
    time.sleep(settle)

    hp, bp = hyprland_pid(), bar_pid()
    h0, hm0 = cpu_ticks(hp)
    b0, _ = cpu_ticks(bp)
    s0 = stats()
    t0 = time.monotonic()
    time.sleep(seconds)
    dt = time.monotonic() - t0
    h1, hm1 = cpu_ticks(hp)
    b1, _ = cpu_ticks(bp)
    s1 = stats()

    c0, c1 = s0["capture"], s1["capture"]

    def rate(key):
        return (c1[key] - c0[key]) / dt

    print(f"[{name}] {desc}")
    print(f"    hyprland cpu {100.0 * (h1 - h0) / HZ / dt:5.1f}%  (main thread {100.0 * (hm1 - hm0) / HZ / dt:5.1f}%)   status bar cpu {100.0 * (b1 - b0) / HZ / dt:5.1f}%")
    print(
        f"    per second: requests {rate('requests'):5.1f}  completions {rate('completions'):5.1f}  published {rate('published'):5.1f}  "
        f"duplicates {rate('duplicates'):5.1f}  warm-up dropped {rate('warmupDropped'):4.1f}  cancelled {rate('cancelled'):4.1f}  "
        f"window frames {rate('frames'):5.1f}  damage events {rate('damageEvents'):5.1f} (full {rate('damageFull'):5.1f})"
    )
    print(
        f"    dmabuf: using {c1['usingDmabuf']}  whole-output {c1['lastWholeOutput']}  broken {c1['dmabufBroken']}  fences {c1['fencesAvailable']}  "
        f"pool {c1['poolSize']} (free {c1['poolFree']}, in flight {c1['poolInFlight']}, pending {c1['poolPending']}, shown {c1['poolShown']}, retiring {c1['poolRetiring']})"
    )
    print(
        f"    totals: exhausted {c1['poolExhausted']}  wait timeouts {c1['bufferWaitTimeouts']}  alloc failures {c1['allocFailures']}  "
        f"import failures {c1['importFailures']}  fallbacks {c1['fallbackActivations']}  heals {c1['heals']}  "
        f"fence releases {c1['fencesWaited']}  timed releases {c1['timedRetired']}  compositor failed {c1['compositorFailed']}  latency {c1['latency']:.0f} ms"
    )
    v0, v1 = s0.get("validation") or {}, s1.get("validation") or {}
    if v1:
        d = lambda k: v1.get(k, 0) - v0.get(k, 0)
        print(
            f"    validation (this window): processed {d('processed'):.0f}  accepted {d('accepted'):.0f}  rejected wrong-frame {d('rejectedWrongFrame'):.0f}  "
            f"rejected unusable {d('rejectedUnusable'):.0f}  held last good {d('heldLastGood'):.0f}  no-backdrop fallbacks {d('greyFallbackNoBackdrop'):.0f}"
        )
        print(
            f"    pixels: unknown {v1['unknownPctLast']:.1f}% (avg {v1['unknownPctAvg']:.1f}%)  wrong {v1['wrongPctLast']:.2f}% (avg {v1['wrongPctAvg']:.2f}%)  "
            f"impossible {v1['impossiblePctLast']:.2f}% (avg {v1['impossiblePctAvg']:.2f}%)  valid backdrop seen {v1['validBackdropSeen']}"
        )
    p = s1["pipeline"]
    print(f"    pipeline: flips {p['flips']}  updates scheduled {p['updatesScheduled']}  deferred {p['updatesDeferred']}  ready {p['ready']}")
    sys.stdout.flush()


def main():
    args = sys.argv[1:]
    seconds = 6.0
    if args and args[0].replace(".", "").isdigit():
        seconds = float(args.pop(0))
    names = args or ["glass-off", "normal"]
    try:
        for n in names:
            run(n, seconds)
    finally:
        # Always put the pipeline back, also after an error or Ctrl+C. Each call is guarded so
        # one failing call does not stop the others.
        for fn, arg in NORMAL + [("setDiagnostics", "false")]:  # the read-back costs a frame twice a second
            try:
                ipc(fn, arg)
            except Exception as e:
                print(f"warning: restoring {fn} failed: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
