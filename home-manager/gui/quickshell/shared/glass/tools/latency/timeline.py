#!/usr/bin/env python3
"""Reads a WAYLAND_DEBUG log of a glass surface (probe) and reports what became of every capture:
dropped as a duplicate, or published, and then in which compositor frame the glass update landed
(lag in frames behind the captured content), and why slow ones were slow.
The probe prints "EVPUB" for every published capture (GlassCapture.captured).
usage: timeline.py <probe log> <clocks file> [--dump N] [--slow N]"""
import re, sys, datetime, bisect, statistics as st

log, clocks = sys.argv[1], sys.argv[2]
def opt(name):
    return int(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else 0
dump, slow = opt("--dump"), opt("--slow")
_, R0, M0 = open(clocks).read().split()
R0, M0 = float(R0), float(M0)
day = datetime.datetime.fromtimestamp(R0).replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
off = R0 - M0

line_re = re.compile(r"^\[(\d+):(\d+):(\d+)\.(\d+)\]\s*(\{[^}]*\})?\s*(discarded )?(-> )?(\w+)#(\d+)\.(\w+)\((.*)\)")
ev = []          # [mono_ms, kind, data]
marks = 0
last_ready = None
multi = 0
for l in open(log, errors="replace"):
    m = line_re.match(l)
    if not m:
        if "EVPUB" in l:
            marks += 1
            if last_ready is not None:
                if last_ready[3]: multi += 1
                last_ready[3] = True
        continue
    h, mi, s, us, queue, disc, out, iface, oid, msg, args = m.groups()
    t = (day + int(h) * 3600 + int(mi) * 60 + int(s) + int(us) / 1e6 - off) * 1e3
    if iface == "zwlr_screencopy_frame_v1" and msg == "ready" and not out:
        a = [int(x) for x in args.split(",")]
        last_ready = [t, "ready", (a[1] + a[2] / 1e9) * 1e3, False]
        ev.append(last_ready)
    elif iface == "zwlr_screencopy_manager_v1" and msg.startswith("capture_output") and out:
        ev.append([t, "request", None])
    elif iface == "zwlr_screencopy_frame_v1" and msg == "copy_with_damage" and out:
        ev.append([t, "arm", None])
    elif iface == "wl_surface" and msg == "frame" and out:
        ev.append([t, "framereq", None])
    elif iface == "wl_surface" and msg == "commit" and out and "mesa" in (queue or ""):
        ev.append([t, "commit", None])
    elif iface == "wl_callback" and msg == "done" and not queue and not out:
        ev.append([t, "framecb", float(args)])

rd = [e for e in ev if e[1] == "ready"]
if len(rd) < 10:
    print("too few captures:", len(rd)); sys.exit()
# The log's time of day may be in another zone than local time: whole hours off.
hrs = round((rd[len(rd) // 2][0] - rd[len(rd) // 2][2]) / 3.6e6) * 3.6e6
for e in ev: e[0] -= hrs
ev.sort(key=lambda e: e[0])

t_start = rd[0][0] + 2000          # skip the warm-up
readys = [e for e in rd if e[0] >= t_start]
commits = [e[0] for e in ev if e[1] == "commit"]
framecbs = [(e[0], e[2]) for e in ev if e[1] == "framecb"]
requests = [e[0] for e in ev if e[1] == "request"]
arms = [e[0] for e in ev if e[1] == "arm"]

def after(lst, t):
    i = bisect.bisect_right(lst, t)
    return lst[i] if i < len(lst) else None
def q(v, p):
    v = sorted(v); return v[min(len(v) - 1, int(p * (len(v) - 1) + 0.5))]
def summ(name, v, unit="ms"):
    if not v: print(f"{name}: none"); return
    print(f"{name}: median {st.median(v):.1f}  p10 {q(v,.1):.1f}  p90 {q(v,.9):.1f}  max {max(v):.1f} {unit} (n={len(v)})")

period = 1000 / 60.049
dur = (readys[-1][0] - readys[0][0]) / 1e3
have_marks = marks > 0
pubs = [e for e in readys if e[3]] if have_marks else readys
dups = len(readys) - len(pubs)
print(f"window {dur:.1f} s | capture answers {len(readys)/dur:.1f}/s" + (f" (published {len(pubs)/dur:.1f}/s, dropped as duplicate {dups/dur:.1f}/s)" if have_marks else " (no publish marks: every answer taken as published)")
      + f" | surface commits {sum(1 for c in commits if c>=t_start)/dur:.1f}/s")
if multi: print(f"WARNING: {multi} publish marks could not be matched one to one")

summ("compositor commit -> answer at client", [e[0] - e[2] for e in readys])
gaps = [round((readys[i + 1][2] - readys[i][2]) / period) for i in range(len(readys) - 1)]
skipped = sum(g - 1 for g in gaps if g > 1)
frames_total = sum(gaps)
print("gap between captured compositor frames:", {g: gaps.count(g) for g in sorted(set(gaps))}, f"| compositor frames not captured: {skipped} of {frames_total} ({100*skipped/max(1,frames_total):.1f}%)")
summ("answer -> next request (re-arm)", [after(requests, e[0]) - e[0] for e in readys if after(requests, e[0])])
summ("published capture -> surface commit", [after(commits, e[0]) - e[0] for e in pubs if after(commits, e[0])])

# Compositor frame grid (render start times), from the frame callbacks and the capture timestamps.
cbt = sorted(d for _, d in framecbs)
deltas = []
for e in readys:
    i = bisect.bisect_right(cbt, e[2]) - 1
    if i >= 0 and e[2] - cbt[i] < 8: deltas.append(e[2] - cbt[i])
delta = st.median(deltas) if deltas else 2.0
starts = sorted(set([round(e[2] - delta, 1) for e in readys] + cbt))
grid = []
for s in starts:
    if grid and s - grid[-1] < period * 0.5: continue
    while grid and s - grid[-1] > period * 1.5: grid.append(grid[-1] + period)
    grid.append(s)

lags = []; margins = []; gated = late = other = 0; slow_list = []
for e in pubs:
    t, tc = e[0], e[2]
    c = after(commits, t)
    if c is None: continue
    n = bisect.bisect_right(grid, tc - delta + 3) - 1          # the frame that was captured
    j = bisect.bisect_left(grid, c)                            # first frame that starts after our commit
    if n < 0 or j >= len(grid): continue
    lag = j - n
    lags.append(lag); margins.append(grid[j] - c)
    if lag >= 2:
        nxt = grid[n + 1]
        if t + 2.0 > nxt: late += 1
        elif c - t > 4.0: gated += 1; slow_list.append(t)
        else: other += 1
nl = len(lags)
print("glass update lands N frames after the captured content:", {g: f"{lags.count(g)} ({100*lags.count(g)/nl:.1f}%)" for g in sorted(set(lags))},
      f"| mean {st.mean(lags):.2f} frames = {st.mean(lags)*period:.1f} ms")
summ("margin: our commit -> start of the frame that shows it", margins)
print(f"updates that took 2+ frames: {gated} capture in time but the render waited >4 ms, {late} capture arrived too late for the next frame, {other} other")
fresh = sum(1 for g in lags if g == 1)
print(f"SUMMARY: of {frames_total} compositor frames with changing content, the glass showed the previous frame's content (1 frame behind) in {fresh} ({100*fresh/max(1,frames_total):.1f}%); "
      f"not captured {skipped}, dropped as duplicate {dups}, slow update {nl - fresh}")

def show(t0, before, span):
    for e in ev:
        if t0 - before <= e[0] <= t0 + span:
            extra = ""
            if e[1] == "ready": extra = f"  (compositor commit {e[2] - t0:+.2f}; {'PUBLISHED' if e[3] else 'duplicate'})"
            if e[1] == "framecb": extra = f"  (frame time {e[2] - t0:+.0f})"
            print(f"  {e[0] - t0:8.2f} ms  {e[1]}{extra}")
if dump:
    show(readys[len(readys) // 2][0], 2, dump)
for t0 in slow_list[len(slow_list)//2:len(slow_list)//2 + slow]:
    print("-- slow update:"); show(t0, 20, 24)
