#!/usr/bin/env python3
"""Traces masks/*.png into closed outlines and adds the procedural ones (map pin, gear, Spotify arcs, Instagram, the
Claude spark, Gmail's M, Slack's four pieces, Venmo's V), and stacks the Uber Eats words,
written to glyphs.json as {name: [ring, ...]}: each ring a list of [x, y] with y up, the whole glyph centred on its
bounding box and scaled so its larger side is 1. Holes are just more rings (Blender fills 2D curves even-odd).
Run: python3 trace.py  (after swift glyphs.swift)"""
import glob, json, math, os, sys
sys.dont_write_bytecode = True
import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def normalise(rings):
    pts = np.concatenate([np.asarray(r, dtype=float) for r in rings])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    c, s = (lo + hi) / 2, (hi - lo).max()
    return [[[round((x - c[0]) / s, 5), round((y - c[1]) / s, 5)] for x, y in r] for r in rings]


def normalise_group(parts):
    """normalise() for a glyph in several parts (one per material), keeping the parts where they are to each other."""
    pts = np.concatenate([np.asarray(r, dtype=float) for rings in parts.values() for r in rings])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    c, s = (lo + hi) / 2, (hi - lo).max()
    return {k: [[[round((x - c[0]) / s, 5), round((y - c[1]) / s, 5)] for x, y in r] for r in rings]
            for k, rings in parts.items()}


def trace(path):
    return normalise(contours(load(path)))


def load(path):
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    return img[..., 3] if img.shape[2] == 4 else 255 - cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)


def contours(a):
    """The outlines of a mask (pixels, y down) as rings in pixels with y up, not yet normalised."""
    a = cv2.GaussianBlur(a, (0, 0), 1.2)
    _, m = cv2.threshold(a, 127, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    rings = []
    for c in contours:
        if cv2.contourArea(c) < 60:
            continue
        c = c[:, 0, :].astype(float)
        # Smooth the pixel steps (circular moving average), then drop points that add nothing.
        k = 7
        pad = np.concatenate([c[-k:], c, c[:k]])
        ker = np.ones(2 * k + 1) / (2 * k + 1)
        c = np.stack([np.convolve(pad[:, 0], ker, "valid"), np.convolve(pad[:, 1], ker, "valid")], axis=1)
        c = cv2.approxPolyDP(c.astype(np.float32).reshape(-1, 1, 2), 0.35, True)[:, 0, :].astype(float)
        rings.append([[x, -y] for x, y in c])
    return rings


def circle(cx, cy, r, n=96, start=0.0, end=2 * math.pi):
    return [[cx + r * math.cos(start + (end - start) * i / n), cy + r * math.sin(start + (end - start) * i / n)] for i in range(n)]


def pin():
    # A teardrop: a circle and its two tangents to the tip below, with a round hole.
    c, r, tip = (0.0, 0.16), 0.3, (0.0, -0.5)
    d = c[1] - tip[1]
    a = math.asin(r / d)          # half-angle at the tip
    outer = [list(tip)] + [[c[0] + r * math.cos(-a + (math.pi + 2 * a) * i / 120),
                            c[1] + r * math.sin(-a + (math.pi + 2 * a) * i / 120)] for i in range(121)]
    return normalise([outer, circle(c[0], c[1], r * 0.42)])


def gear(teeth=8, spokes=6):
    # A wheel gear: teeth round the rim, six spokes between round-ended openings, a hub with a hole.
    ro, rr, ri, rh, hole = 0.5, 0.41, 0.3, 0.13, 0.06
    outer = []
    n = teeth * 4
    for i in range(n):
        k = i % 4
        ang = 2 * math.pi * (i // 4) / teeth
        w = 2 * math.pi / teeth
        offs = {0: -0.24, 1: -0.15, 2: 0.15, 3: 0.24}[k] * w
        rad = ro if k in (1, 2) else rr
        outer.append([rad * math.cos(ang + offs), rad * math.sin(ang + offs)])
    # Smooth the tooth corners a little by resampling.
    rings = [outer]
    for s in range(spokes):
        a0 = 2 * math.pi * s / spokes + 0.3
        a1 = 2 * math.pi * (s + 1) / spokes - 0.3
        ri = 0.27
        win = [[ri * math.cos(a0 + (a1 - a0) * i / 24), ri * math.sin(a0 + (a1 - a0) * i / 24)] for i in range(25)]
        win += [[rh * 1.4 * math.cos(a1 - (a1 - a0) * i / 24), rh * 1.25 * math.sin(a1 - (a1 - a0) * i / 24)] for i in range(25)]
        rings.append(win)
    rings.append(circle(0, 0, hole, 48))
    return normalise(rings)


def arc_band(r, w, a0, a1, n=48):
    outer = [[(r + w / 2) * math.cos(a0 + (a1 - a0) * i / n), (r + w / 2) * math.sin(a0 + (a1 - a0) * i / n)] for i in range(n + 1)]
    inner = [[(r - w / 2) * math.cos(a1 - (a1 - a0) * i / n), (r - w / 2) * math.sin(a1 - (a1 - a0) * i / n)] for i in range(n + 1)]
    return outer + inner


def spotify_arcs():
    # Three arcs, longest on top, each a band bowed upward, offset down the disc.
    rings = []
    for (cy, r, w, span) in [(-0.62, 0.98, 0.13, 0.74), (-0.75, 0.86, 0.11, 0.66), (-0.85, 0.74, 0.095, 0.6)]:
        band = arc_band(r, w, math.pi / 2 - span / 2, math.pi / 2 + span / 2)
        rings.append([[x, y + cy] for x, y in band])
    return rings  # keep the disc's own scale (not normalised): centred near the disc's middle


def instagram():
    def rrect(half, rad, n=12):
        pts = []
        for cx, cy, a0 in [(half - rad, half - rad, 0), (-half + rad, half - rad, math.pi / 2),
                           (-half + rad, -half + rad, math.pi), (half - rad, -half + rad, 1.5 * math.pi)]:
            pts += [[cx + rad * math.cos(a0 + math.pi / 2 * i / n), cy + rad * math.sin(a0 + math.pi / 2 * i / n)] for i in range(n + 1)]
        return pts
    return normalise([rrect(0.5, 0.15), rrect(0.4, 0.09), circle(0, 0, 0.22), circle(0, 0, 0.13), circle(0.27, 0.27, 0.05, 32)])


# MARK: - Drawn masks (1024 px, x and y in -0.5...0.5 with y up)

N = 1024


def px(x, y):
    return (x + 0.5) * N, (0.5 - y) * N


def blank():
    return np.zeros((N, N), np.uint8)


def poly(m, pts):
    cv2.fillPoly(m, [np.round(np.array([px(x, y) for x, y in pts]) * 16).astype(np.int32)], 255, cv2.LINE_AA, shift=4)


def dot(m, x, y, r):
    cx, cy = px(x, y)
    cv2.circle(m, (round(cx * 16), round(cy * 16)), round(r * N * 16), 255, -1, cv2.LINE_AA, shift=4)


def stroke(m, pts, w):
    """A polyline `w` wide with round caps and joins."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d = math.hypot(x1 - x0, y1 - y0)
        nx, ny = -(y1 - y0) / d * w / 2, (x1 - x0) / d * w / 2
        poly(m, [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])
    for x, y in pts:
        dot(m, x, y, w / 2)


def bezier(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def claude():
    # Claude's spark: a dozen blunt rays of uneven length from a solid heart, as if drawn with a broad nib.
    m = blank()
    rng = np.random.default_rng(11)
    for k in range(12):
        a = 2 * math.pi * k / 12 + 0.12 + rng.uniform(-0.08, 0.08)
        length = rng.uniform(0.34, 0.46)
        w0, w1 = rng.uniform(0.06, 0.07), rng.uniform(0.038, 0.046)
        ux, uy = math.cos(a), math.sin(a)
        tx, ty = ux * length, uy * length
        poly(m, [(-uy * w0, ux * w0), (tx - uy * w1, ty + ux * w1), (tx + uy * w1, ty - ux * w1), (uy * w0, -ux * w0)])
        dot(m, tx, ty, w1)
    dot(m, 0, 0, 0.11)
    return normalise(contours(m))


def gmail():
    # Gmail's M: an envelope whose sides are two posts and whose flap is a V from corner to corner.
    posts, v = blank(), blank()
    for x in (-0.33, 0.33):
        stroke(posts, [(x, -0.24), (x, 0.2)], 0.15)
    stroke(v, [(-0.33, 0.2), (0.0, -0.06), (0.33, 0.2)], 0.15)
    return normalise_group({"gmail-posts": contours(posts), "gmail-v": contours(v)})


def slack():
    # Slack's mark, from its drawing on a 127 grid (y down): a pill and a tab per colour, each colour the last turned
    # a quarter clockwise round the middle. Order: red (lower left), blue, green, yellow.
    def turn(p, k):
        x, y = p[0] - 63.5, p[1] - 63.5
        for _ in range(k):
            x, y = -y, x
        return x / 127 * 0.9, -y / 127 * 0.9

    parts = {}
    for k in range(4):
        m = blank()
        # The tab: a disc and the square that joins it to its pill.
        cx, cy = turn((14, 80), k)
        dot(m, cx, cy, 13.2 / 127 * 0.9)
        poly(m, [turn(p, k) for p in [(14, 66.8), (27.2, 66.8), (27.2, 93.2), (14, 93.2)]])
        # The pill.
        for c in [(47, 80), (47, 113)]:
            x, y = turn(c, k)
            dot(m, x, y, 13.2 / 127 * 0.9)
        poly(m, [turn(p, k) for p in [(33.8, 80), (60.2, 80), (60.2, 113), (33.8, 113)]])
        parts[f"slack-{k}"] = contours(m)
    return normalise_group(parts)


def venmo():
    # Venmo's V: a broad straight left stroke, a narrower right one that bows out as it climbs. The ends are round:
    # cut flat, they break the bevel in Blender.
    m = blank()
    stroke(m, [(-0.24, 0.38), (-0.05, -0.36)], 0.2)
    stroke(m, bezier((-0.03, -0.34), (0.3, -0.08), (0.27, 0.4)), 0.15)
    return normalise(contours(m))


def ubereats():
    # "Uber" over "Eats", left aligned, at one size.
    uber, eats = contours(load(os.path.join(HERE, "masks", "uber.png"))), contours(load(os.path.join(HERE, "masks", "eats.png")))
    def bounds(rings):
        p = np.concatenate([np.asarray(r) for r in rings])
        return p.min(axis=0), p.max(axis=0)
    (ulo, uhi), (elo, ehi) = bounds(uber), bounds(eats)
    dy = ehi[1] + 0.22 * (ehi[1] - elo[1]) - ulo[1]   # "Uber"'s baseline a little above "Eats"'s cap line
    uber = [[[x - ulo[0] + elo[0], y + dy] for x, y in r] for r in uber]
    return normalise_group({"uber": uber, "eats": eats})


def main():
    out = {}
    for p in sorted(glob.glob(os.path.join(HERE, "masks", "*.png"))):
        name = os.path.splitext(os.path.basename(p))[0]
        if name not in ("uber", "eats"):
            out[name] = trace(p)
    out.update(ubereats())
    out["claude"] = claude()
    out.update(gmail())
    out.update(slack())
    out["venmo"] = venmo()
    out["pin"] = pin()
    out["gear"] = gear()
    out["spotify-arcs"] = spotify_arcs()
    out["instagram"] = instagram()
    with open(os.path.join(HERE, "glyphs.json"), "w") as f:
        json.dump(out, f)
    for k, v in out.items():
        print(k, len(v), "rings", sum(len(r) for r in v), "points")


if __name__ == "__main__":
    main()
