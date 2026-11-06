#!/usr/bin/env python3
"""Sun Arc in another landscape: the Tre Cime di Lavaredo (Drei Zinnen), the three north faces in the classic view
from near the Locatelli hut (Dreizinnenhuette), looking south-west: Cima Piccola on the left, Cima Grande (2,999 m)
in the middle, Cima Ovest on the right. Left is east: the morning sun comes from the left, lighting the towers'
eastern edges, while their north faces stand in shadow.

The large Weather canvas (348 x 365 pt) as one grey value study, glazed at run time by the Cover's CoverLight:
  large-lo.png, large-hi.png   the lower and upper halves of the value
  large-glow.png               the brightest lights (sunlit rock, cloud tops)
  large-front.png              the land, drawn again over the sun and the arc's feet
Data:
  dolomites.json               the skyline, traced from a photograph (see SOURCE.md) and normalised: Cima Grande's
                               summit at (0, 0), in units of its north face's height above the scree at its foot in
                               that photograph; with each tower's columns and main arete, and the scree fans at their
                               feet, drawn by eye on the same photograph, in the same units

Shares the painter in ../fuji/world.py (the Sun Arc canvas's machinery, generalised to layers).

Run (deterministic, offline):  python3 MockLab/Textures/weather-sun-arc/scenes/dolomites/make.py [--preview <png>]
Rebuild dolomites.json from the full trace:  make.py --trace <trace.json>
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("sa_world", os.path.join(os.path.dirname(HERE), "fuji", "world.py"))
world = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(world)
om, mt, SS = world.om, world.mt, world.SS
fbm, smoothstep = world.fbm, world.smoothstep

SKYLINE = os.path.join(HERE, "dolomites.json")
META = {
    "peak": {"name": "Tre Cime di Lavaredo (Cima Grande)", "elevation_m": 2999},
    "view": "the north faces from near the Locatelli hut (Dreizinnenhuette, 2,405 m), looking south-west",
    "source": {
        "photo": "File:Tremi cime di Lavaredo del rifugio Locatelli.jpg, Wikimedia Commons (July 2016)",
        "url": "https://commons.wikimedia.org/wiki/File:Tremi_cime_di_Lavaredo_del_rifugio_Locatelli.jpg",
        "author": "Irene Scarpante",
        "licence": "CC BY-SA 4.0",
        "use": "skyline only: for each column the first row that is not blue sky (3840 px wide copy, columns 0 to "
               "3300); the towers' aretes and the scree fans drawn by eye; no pixels kept",
    },
}
FACE_PX = 772          # Cima Grande's north face, summit to the scree at its foot, in the photograph (3840 px copy)
# Drawn by eye on the same photograph (photo px), stored in dolomites.json with the skyline:
#   tower_<name>   the tower's columns (two points: its left and right edge, at its top)
#   arete_<name>   the main vertical arete that splits its sunlit face from its shadowed face, top to foot
#   fan_<n>        the scree fans at the foot (apex, left and right corners of the base)
# Each tower: name, columns, arete, which side of the arete is sunlit, and the row below which the sunlit face
# passes into shadow (the light in the photograph comes from the left and stops short of the lower faces).
TOWERS = [
    ("piccola_1", (1000, 1108), [(1088, 868), (1090, 1262)], "left", 1210),
    ("piccola_2", (1108, 1292), [(1214, 738), (1200, 860), (1192, 1262)], "left", 860),
    ("piccola_3", (1292, 1442), [(1418, 678), (1424, 820), (1420, 1262)], "left", 930),
    ("grande", (1442, 2015), [(1760, 490), (1748, 700), (1722, 900), (1692, 1100), (1672, 1262)], "left", 1080),
    ("ovest", (2015, 2628), [(2318, 610), (2258, 700), (2208, 850), (2186, 1000), (2178, 1262)], "right", 1262),
    ("shoulder", (2628, 3300), None, None, 0),
]
FANS = [[(1290, 1250), (1120, 1306), (1460, 1306)], [(1745, 1246), (1560, 1306), (1930, 1306)],
        [(1990, 1222), (1800, 1306), (2180, 1306)], [(2430, 1248), (2240, 1306), (2620, 1306)],
        [(2710, 1240), (2520, 1306), (2900, 1306)]]
FAN_LIGHT = [0.26, 0.36, 0.6, 0.62, 0.46]


def trace(path):
    lines = {}
    for name, (x0, x1), arete, side, lit_to in TOWERS:
        lines["tower_" + name] = [(x0, 500), (x1, 500)]
        if arete:
            lines["arete_" + name] = arete
    for i, fan in enumerate(FANS):
        lines[f"fan_{i}"] = fan
    world.skyline_from_trace(path, SKYLINE, META, step=3, unit=FACE_PX, lines=lines)


ARC = world.ARC
# Cima Grande's summit (x, y) fractions and points per unit: 0.135 pt per photo px, the group a little left of the
# crown so the arc's right foot clears the west tower's shoulder; the scree at the feet is at 0.58.
FRAME = (0.438, 0.292, 0.135 * FACE_PX)
LIGHT = (-0.7, -0.4, 0.55)


def towers_layer(sk):
    """The three towers in clean planes, as the Matterhorn's faces are: each split along its main vertical arete
    into the face the morning sun reaches (pale, falling off toward the foot) and the north face in cool shadow;
    the fluting and chimneys of the dolomite drawn out in long vertical streaks, soft and darker toward the foot,
    two or three broken ledges on each sunlit face, a lit rim along the sunlit skyline; the scree fans at their feet
    catching the light."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        cy = sk.crest(w, h, sx, sy, S, ends="level")
        cover = world.below(cy, h, 0.45)
        yy, xx = ctx["yy"], ctx["xx"]
        xs = np.arange(w) + 0.5
        v_ = (yy - sy * h) / S
        down = np.pi / 2 * np.ones((h, w))
        flute = world.streaks(h, w, rng, down, 0.45 * S, base=140)               # fine vertical fluting
        runnel = gaussian_filter(world.streaks(h, w, rng, down, 0.7 * S, base=50), (0, 0.8 * SS))   # soft runnels
        soft = world.streaks(h, w, rng, down, 0.9 * S, base=34)                  # broad soft streaks of tone
        sunlit = np.zeros((h, w))
        value = np.zeros((h, w))
        crisp = []                                                               # dark lines laid back crisp
        lips = []                                                                # lit lines above the ledges
        for name, _, arete, side, lit_to in TOWERS:
            (x0, _), (x1, _) = sk.line("tower_" + name, w, h, sx, sy, S)
            cols = smoothstep(x0 - 0.5 * SS, x0 + 0.5 * SS, xx) * smoothstep(x1 + 0.5 * SS, x1 - 0.5 * SS, xx)
            top = float(np.min(cy[int(max(x0, 0)):int(min(x1, w))]))
            foot = (sy + 1.0 * size / world.H) * h
            depth = np.clip((yy - top) / max(foot - top, 1), 0, 1)
            if arete:
                ax, ay = zip(*sk.line("arete_" + name, w, h, sx, sy, S))
                edge_x = np.interp(yy, ay, ax)
                face = smoothstep(0.5 * SS, -0.5 * SS, xx - edge_x) if side == "left" else smoothstep(-0.5 * SS, 0.5 * SS, xx - edge_x)
                lit_row = sy * h + (lit_to - sk.data["trace"]["summit"][1]) / sk.data["trace"]["unit_px"] * S
                fade = lit_row + 10 * SS * np.tanh((xx - edge_x) / (12 * SS)) * (1 if side == "left" else -1)
                face = face * smoothstep(fade + 10 * SS, fade - 10 * SS, yy)
            else:
                face = np.zeros((h, w))
            dark_runs = smoothstep(0.2, 2.0, runnel)
            # the sunlit rock: long soft streaks of darker tone down the fluting, deepening toward the foot
            lit_v = (0.86 - 0.2 * depth + 0.03 * np.tanh(flute) - 0.1 * dark_runs
                     - (0.08 + 0.14 * depth) * smoothstep(-0.4, 1.3, soft))
            shade_v = 0.26 - 0.06 * depth + 0.035 * np.tanh(flute) - 0.08 * dark_runs + 0.04 * smoothstep(-1.5, -0.6, runnel)
            tower_v = shade_v + (lit_v - shade_v) * face
            value = value * (1 - cols) + tower_v * cols
            sunlit = np.maximum(sunlit, face * cols)
            # Ledges: two or three per sunlit face, kept inside the face (never across the arete or another mark),
            # each a broken, slightly tilted dark line with a lit lip above it.
            if arete:
                count = 3 if name in ("grande", "ovest") else 2
                rows = np.sort(rng.uniform(0.18, 0.8, count))
                rows = rows[np.concatenate([[True], np.diff(rows) > 0.12])]
                for r in rows:
                    ly = top + r * (foot - top)
                    if ly > lit_row - 4 * SS:
                        continue
                    ex = float(np.interp(ly, ay, ax))
                    lo, hi = (x0 + 3 * SS, ex - 3 * SS) if side == "left" else (ex + 3 * SS, x1 - 3 * SS)
                    if hi - lo < 6 * SS:
                        continue
                    span = rng.uniform(0.35, 0.65) * (hi - lo)
                    start = rng.uniform(lo, hi - span)
                    tilt = rng.uniform(-0.08, 0.08)
                    cuts = np.sort(rng.uniform(0.25, 0.75, 2))
                    pieces = [(0.0, cuts[0] - 0.06), (cuts[0] + 0.04, cuts[1] - 0.05), (cuts[1] + 0.05, 1.0)]
                    for p0, p1 in pieces:
                        if p1 - p0 < 0.08:
                            continue
                        pa, pb = start + p0 * span, start + p1 * span
                        ya = ly + tilt * (pa - start) + rng.uniform(-0.4, 0.4) * SS
                        yb = ly + tilt * (pb - start) + rng.uniform(-0.4, 0.4) * SS
                        if min(ya, yb) < float(cy[int(np.clip(pa, 0, w - 1))]) + 3 * SS:
                            continue
                        crisp.append([(pa, ya), (pb, yb)])
                        lips.append([(pa, ya - 0.9 * SS), (pb, yb - 0.9 * SS)])
        value = value * cover
        sunlit = sunlit * cover
        # crisp drawing: the ledges as dark lines, their lips as light ones (drawn at 4x, antialiased)
        def lines_mask(polys, width):
            from PIL import Image, ImageDraw
            k = 4
            img = Image.new("L", (w * k, h * k), 0)
            d = ImageDraw.Draw(img)
            for pl in polys:
                d.line([(x * k, y * k) for x, y in pl], fill=255, width=max(1, int(width * k)))
            return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
        dark = lines_mask(crisp, 1.0 * SS) * cover
        light = lines_mask(lips, 0.8 * SS) * cover * sunlit
        value = value * (1 - 0.5 * dark) + 0.12 * light
        # a lit rim along the skyline where the sunlit face meets the sky
        rim = np.clip(smoothstep(2.0 * SS, 0.2 * SS, yy - cy[None, :]) * cover, 0, 1)
        value = value + 0.1 * rim * sunlit
        keep = np.clip(dark + light, 0, 1)
        # The arete edge between the planes, crisp.
        sg = gaussian_filter(sunlit, 0.4 * SS)
        keep = np.clip(keep + np.hypot(*np.gradient(sg)) * 2.5 * SS, 0, 1)
        # Scree fans at the feet: pale cones, lit on their left (the sun's) side.
        fans = np.zeros((h, w))
        fan_v = np.zeros((h, w))
        for i, light_v in enumerate(FAN_LIGHT):
            poly = sk.line(f"fan_{i}", w, h, sx, sy, S)
            m = world.draw_mask(w, h, [poly], k=4)
            apex_x = poly[0][0]
            side_light = np.where(xx < apex_x, 1.0, 0.78)
            fall = np.pi / 2 + 0.9 * np.tanh((xx - apex_x) / (6 * SS)) * -1     # down each side of the cone
            grain = 0.05 * np.tanh(world.streaks(h, w, rng, fall, 0.08 * S, base=110))
            fan_v = fan_v * (1 - m) + (light_v * side_light + grain) * m
            fans = np.maximum(fans, m)
        value = value * (1 - fans) + fan_v * fans
        keep = np.clip(keep + np.hypot(*np.gradient(gaussian_filter(fans, 0.4 * SS))) * 2 * SS, 0, 1)
        cover = np.maximum(cover, fans)
        glow = sunlit * smoothstep(0.7, 0.85, value) * (1 - fans)
        return dict(value=value, cover=cover, glow=glow, lean=np.zeros((h, w)), keep=keep * cover, crest=cy)
    return layer


def plateau_layer():
    """The near ground: the stony plateau under the hut, its rim catching the light in the middle (left and right,
    where the sun times stand, it lies in the towers' shadow), then the dark slope falling toward us in long
    diagonal strokes, a few boulders' tops lit."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        base = (sy + 1.07 * size / world.H) * h
        X = (np.arange(w) + 0.5) / w
        line = base + (1.6 * np.sin(X * 6 + 0.5) + 0.8 * np.sin(X * 17 + 2)) * SS + 0.6 * SS * fbm(1, w, rng, base=40, octaves=3)[0]
        cover = world.below(line, h, 0.5)
        yy, xx = ctx["yy"], ctx["xx"]
        d = (yy - line[None, :]) / SS                          # points below the rim
        lit = smoothstep(0.26, 0.38, X) * smoothstep(0.76, 0.66, X)
        rim = smoothstep(2.6, 0.6, d)
        slope = 0.2 * np.exp(-d / 12.0) + 0.13 - 0.08 * smoothstep(20, 50, d)
        stones = world.streaks(h, w, rng, np.full((h, w), 2.4), 4 * SS, base=60)
        v = slope + 0.05 * np.tanh(stones) * np.exp(-d / 25.0) + rim * (0.12 + 0.3 * lit[None, :])
        # a few boulders on the slope, their tops lit
        polys = []
        for _ in range(18):
            bx, by = rng.uniform(0, w), line[0] + rng.uniform(4, 30) * SS
            by = float(np.interp(bx, np.arange(w), line)) + rng.uniform(4, 26) * SS
            r = rng.uniform(1.2, 3.0) * SS
            polys.append([(bx + r * np.cos(t), by + 0.55 * r * np.sin(t)) for t in np.linspace(np.pi, 2 * np.pi, 8)])
        caps = world.draw_mask(w, h, polys, k=4)
        v = v + 0.16 * caps * np.exp(-d / 20.0)
        angle = 2.4 + 0.1 * fbm(h, w, rng, base=6, octaves=2)    # down the slope, to the left
        keep = np.clip(np.hypot(*np.gradient(gaussian_filter(rim * lit[None, :], 0.4 * SS))) * 2 * SS + 0.6 * caps, 0, 1)
        return dict(value=v, cover=cover, angle=angle, keep=keep, crest=line, ground=True)
    return layer


def large():
    sk = world.Skyline(SKYLINE)
    return world.compose(348, 365, 721, sun=(0.3, 0.1), horizon=0.58,
                         sky=dict(dark_top=0.2, bright=0.58, low=0.56),
                         clouds=[(-0.02, 0.11, 0.42, 0.12, 34, 0.55), (1.02, 0.1, 0.44, 0.12, 34, 0.5),
                                 (0.04, 0.56, 0.16, 0.1, 26), (0.97, 0.53, 0.14, 0.09, 24)],
                         calm=(0.5, 0.3, 0.34, 0.22, 0.7),
                         layers=[towers_layer(sk), plateau_layer()],
                         ground_dark=(0.66, 1.0, 0.45))


if __name__ == "__main__":
    world.main(HERE, large, ARC, trace)
