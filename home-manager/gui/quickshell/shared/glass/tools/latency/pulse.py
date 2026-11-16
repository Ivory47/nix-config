#!/usr/bin/env python3
"""On-screen glass lag under continuous motion, from a lagcap recording of a white bar that
crosses point A (plain view) and point B (behind the glass, same x) at the same moment.
For every pass: time centroid of the luminance pulse at A and at B (the blur is symmetric, so it
keeps the centroid); lag = centroid(B) - centroid(A). usage: pulse.py <lagcap file>"""
import sys, statistics as st
fr = []
for l in open(sys.argv[1]):
    p = l.split()
    if len(p) >= 6: fr.append((float(p[1]), float(p[3]), float(p[4])))   # recv ms, lum A, lum B
if len(fr) < 100: print("too few frames", len(fr)); sys.exit()
ts = [f[0] for f in fr]
dts = sorted(ts[i+1]-ts[i] for i in range(len(ts)-1)); period = dts[len(dts)//2]
a = [f[1] for f in fr]; b = [f[2] for f in fr]
a0 = sorted(a)[len(a)//4]; b0 = sorted(b)[len(b)//4]            # resting levels
amax = max(a); thr = a0 + 0.3 * (amax - a0)
lags = []; i = 0; W = 14
while i < len(fr):
    if a[i] > thr:
        j = i
        while j < len(fr) and a[j] > thr: j += 1
        lo, hi = max(0, i - W), min(len(fr), j + W)
        wa = [max(0, a[k] - a0) for k in range(lo, hi)]; wb = [max(0, b[k] - b0) for k in range(lo, hi)]
        tt = ts[lo:hi]
        if sum(wa) > 0 and sum(wb) > 0.2 * sum(wa) * (max(b) - b0) / max(1, amax - a0) and lo > 0 and hi < len(fr):
            ca = sum(t * w for t, w in zip(tt, wa)) / sum(wa); cb = sum(t * w for t, w in zip(tt, wb)) / sum(wb)
            lags.append(cb - ca)
        i = j + W
    else: i += 1
if not lags: print("no passes found"); sys.exit()
lags.sort()
print("frames %d (period %.2f ms, %.1f fps captured) | passes %d" % (len(fr), period, 1000 * (len(fr) - 1) / (ts[-1] - ts[0]), len(lags)))
print("on-screen glass lag: median %.1f ms = %.2f frames | mean %.1f ms | min %.1f max %.1f | stdev %.1f" % (
    st.median(lags), st.median(lags) / period, st.mean(lags), lags[0], lags[-1], st.pstdev(lags)))
