#!/usr/bin/env python3
"""Measures what the live glass costs Hyprland, one setting at a time.

Needs the status bar to run with `ipcTarget: "glass"` on its GlassBackdrop (it does). Each
scenario sets the pipeline through `qs ipc`, waits for things to settle, and then reads CPU time
from /proc for Hyprland and for the status bar, plus the capture counters, over a few seconds.

    python3 measure.py [seconds] [scenario ...]

Scenarios (see SCENARIOS below). Without names, all of them run.
"""
import json
import os
import socket
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
    found = pids_where(lambda c, _: c.lower().startswith(".hyprland-wrapp") or c == "Hyprland")
    return found[0]


def bar_pid():
    found = pids_where(lambda c, cmd: "quickshell" in c and b"status-bar" in cmd and b"glass-test" not in b" ".join(cmd))
    return found[0]


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


def ctx_switches(pid):
    v = n = 0
    for line in open(f"/proc/{pid}/status"):
        if line.startswith("voluntary_ctxt_switches"):
            v = int(line.split()[1])
        elif line.startswith("nonvoluntary_ctxt_switches"):
            n = int(line.split()[1])
    return v, n


def ipc(*args):
    r = subprocess.run(["qs", "ipc", "-c", "status-bar", "call", "glass", *map(str, args)], capture_output=True, text=True)
    return r.stdout.strip()


def stats():
    return json.loads(ipc("stats"))


def events_socket():
    rt = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        d = os.path.join(rt, "hypr")
        sig = sorted(os.listdir(d), key=lambda n: os.path.getmtime(os.path.join(d, n)))[-1]
    s = socket.socket(socket.AF_UNIX)
    s.connect(os.path.join(rt, "hypr", sig, ".socket2.sock"))
    s.setblocking(False)
    return s


def drain(sock):
    data = b""
    try:
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            data += chunk
    except BlockingIOError:
        pass
    return data.decode(errors="replace")


# name: (description, settings applied through ipc, in order)
SCENARIOS = {
    "region-d1": ("REGION capture (compositor-side region), whole pipeline, 1 in flight", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setWholeOutput", "false"), ("setDepth", 1), ("setDmabuf", "true")]),
    "output-d1": ("WHOLE OUTPUT capture, cropped in the shader, whole pipeline, 1 in flight", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setWholeOutput", "true"), ("setDepth", 1), ("setDmabuf", "true")]),
    "output-d2": ("WHOLE OUTPUT capture, whole pipeline, 2 in flight", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setWholeOutput", "true"), ("setDepth", 2), ("setDmabuf", "true")]),
    "output-d3": ("WHOLE OUTPUT capture, whole pipeline, 3 in flight", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setWholeOutput", "true"), ("setDepth", 3), ("setDmabuf", "true")]),
    "output-only-d1": ("WHOLE OUTPUT capture received and thrown away, 1 in flight", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "false"), ("setWholeOutput", "true"), ("setDepth", 1), ("setDmabuf", "true")]),
    "glass-off": ("glass switched off completely: bar with a plain tinted rectangle", [("setGlass", "false")]),
    "off": ("no capture requested at all; bar running", [("setGlass", "true"), ("setCapture", "false")]),
    "cap-only-d1": ("capture received and thrown away, 1 in flight, dmabuf", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "false"), ("setDepth", 1), ("setDmabuf", "true")]),
    "cap-only-d3": ("capture received and thrown away, 3 in flight, dmabuf", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "false"), ("setDepth", 3), ("setDmabuf", "true")]),
    "cap-only-shm": ("capture received and thrown away, 1 in flight, shm", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "false"), ("setDepth", 1), ("setDmabuf", "false")]),
    "full-d1": ("whole pipeline, 1 in flight, dmabuf", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setDepth", 1), ("setDmabuf", "true")]),
    "full-d3": ("whole pipeline, 3 in flight, dmabuf (the old default)", [("setGlass", "true"), ("setCapture", "true"), ("setProcessing", "true"), ("setDepth", 3), ("setDmabuf", "true")]),
}


def run(name, seconds, settle=3.0):
    desc, settings = SCENARIOS[name]
    if "output" not in name:
        ipc("setWholeOutput", "false")  # these are the region-capture scenarios
    for fn, arg in settings:
        ipc(fn, arg)
    time.sleep(settle)

    hp, bp = hyprland_pid(), bar_pid()
    sock = events_socket()
    drain(sock)
    h0, hm0 = cpu_ticks(hp)
    b0, _ = cpu_ticks(bp)
    c0 = ctx_switches(hp)
    s0 = stats()
    t0 = time.monotonic()
    time.sleep(seconds)
    dt = time.monotonic() - t0
    h1, hm1 = cpu_ticks(hp)
    b1, _ = cpu_ticks(bp)
    c1 = ctx_switches(hp)
    s1 = stats()
    events = drain(sock)
    sock.close()

    def rate(key):
        return (s1[key] - s0[key]) / dt

    casts = sum(1 for line in events.splitlines() if line.startswith("screencast"))
    print(f"[{name}] {desc}")
    print(f"    hyprland cpu {100.0 * (h1 - h0) / HZ / dt:5.1f}%  (main thread {100.0 * (hm1 - hm0) / HZ / dt:5.1f}%)  voluntary ctx/s {(c1[0] - c0[0]) / dt:6.0f}  involuntary ctx/s {(c1[1] - c0[1]) / dt:6.0f}")
    print(f"    status bar cpu {100.0 * (b1 - b0) / HZ / dt:5.1f}%")
    print(
        f"    per second: requests {rate('requests'):5.1f}  copies {rate('copies'):5.1f}  received {rate('received'):5.1f}  "
        f"published {rate('published'):5.1f}  skipped {rate('skipped'):5.1f}  cancelled {rate('cancelled'):5.1f}  flips {rate('flips'):5.1f}  window frames {rate('frames'):5.1f}"
    )
    print(f"    screencast session events (start/stop) in {dt:.0f}s: {casts}   in flight now: {s1['inFlight']}   whole-output captures: {s1['lastWholeOutput']}  dmabuf broken: {s1['dmabufBroken']}   latency {s1['latency']:.0f} ms")
    sys.stdout.flush()


def main():
    args = sys.argv[1:]
    seconds = 6.0
    if args and args[0].replace(".", "").isdigit():
        seconds = float(args.pop(0))
    names = args or list(SCENARIOS)
    for n in names:
        run(n, seconds)
    # leave it as it was meant to run
    for fn, arg in SCENARIOS["output-d2"][1]:
        ipc(fn, arg)


if __name__ == "__main__":
    main()
