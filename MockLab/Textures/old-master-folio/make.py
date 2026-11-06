#!/usr/bin/env python3
"""Old Master Folio textures: an antique book lying open on dark velvet, and the oil-painting plates tipped into it.

The book (RGB, 1 px per point, the widget's own size): dark umber velvet, a sliver of the leather boards, the stacked
edges of the page block, and the top pages in warm aged paper, toned at the margins, faintly foxed, with deckled
edges, a gentle curve down into the gutter (lit from the upper left, so the verso darkens toward the spine and the
recto shows a narrow crease and a lit lip) and the slight dip of the head and tail edges toward the spine.
  spread-large.jpg   348x365   two pages, gutter at x 174 (Day and Quote large)
  spread-medium.jpg  348x164   two pages, gutter at x 174 (Day medium)
  page-medium.jpg    348x164   one recto, the gutter at the left edge (Quote medium)
  page-small.jpg     164x164   one recto, the gutter at the left edge (Day and Quote small)
  leaf.jpg            96x96    plain aged paper, for the turned corner and the leaf under it
The SwiftUI side lays the time-of-day light over these (a soft wash, warmer at dusk, lamplit at night).

The plates are original sepia oil paintings, value studies tinted at run time exactly like Old Master's
(<name>-lo / -hi / -glow alpha PNGs, see MockLab/Textures/old-master/make.py, whose painting functions are imported).
They are painted at twice their size and filtered down to 1 px per point, so the brushwork reads at plate scale:
  plate-day-large      138x264   the frontispiece facing the day (tall)
  plate-day-medium     140x96
  plate-day-small      122x54    headpiece
  plate-quote-large    138x280   the frontispiece facing the quote (tall)
  plate-quote-medium   304x48    headpiece: a long panorama of the range
  plate-quote-small    122x54    headpiece
  veil.png             160x160   rain (alpha only)

Run from anywhere (deterministic):  python3 MockLab/Textures/old-master-folio/make.py [names] [--preview <folder>]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing the other make scripts must not leave a __pycache__ anywhere

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("om_make", os.path.join(os.path.dirname(HERE), "old-master", "make.py"))
om = importlib.util.module_from_spec(spec)
spec.loader.exec_module(om)  # its main() is guarded; this only defines the functions (and imports make_textures)
mt = om.mt

hexrgb, fbm, mix, smoothstep = mt.hexrgb, mt.fbm, mt.mix, mt.smoothstep
SS = 2


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def save_rgb(name, rgb, quality=90):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=quality, subsampling=0)
    print(f"{name}.jpg: {rgb.shape[1]}x{rgb.shape[0]}")


def down(a, k=SS):
    """Box filter by an integer factor (works on 2D and 3D arrays)."""
    h, w = a.shape[0] // k, a.shape[1] // k
    a = a[:h * k, :w * k]
    return a.reshape((h, k, w, k) + a.shape[2:]).mean(axis=(1, 3))


def rrect_sdf(xx, yy, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle (negative inside)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(xx - cx) - hx, np.abs(yy - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


# MARK: The book

PAPER_HI = 0xCFB089    # the paper where the light falls fullest
PAPER = 0xBB9B70       # its body
PAPER_TONED = 0x87653F  # the toned margins
VELVET = (0x170E09, 0x281810)
LEATHER = (0x3A2215, 0x5A3820)


def book(w, h, seed, gutter=None, single=False):
    """One open book seen from above, at 1 px per point. gutter: the spine's x in pt (two pages meet there).
    single: only the recto shows; the spine is at the left edge, with a sliver of the facing page beyond it."""
    rng = np.random.default_rng(seed)
    W, H = w * SS, h * SS
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64) / SS + 0.5 / SS  # in points
    # Velvet: very dark umber, with a soft nap that catches a little light.
    nap = fbm(H, W, rng, base=40, octaves=3, persistence=0.6)
    rgb = mix(hexrgb(VELVET[0]), hexrgb(VELVET[1]), smoothstep(-2, 2.5, nap + 0.8 * fbm(H, W, rng, base=3, octaves=2)))

    spine = 9.0 if single else gutter
    left = -40.0 if single else 2.5           # the boards (beyond the widget on the left of a single page)
    boards = rrect_sdf(xx, yy, left, 2.5, w - 2.5, h - 2.5, 17.0)
    # Leather: grain, worn lighter on the rim that catches the light.
    grain = fbm(H, W, rng, base=70, octaves=3, persistence=0.6)
    leather = mix(hexrgb(LEATHER[0]), hexrgb(LEATHER[1]), smoothstep(-1.5, 2.5, grain) * 0.5)
    rim = smoothstep(-2.4, -0.4, boards) * (1 - smoothstep(-0.4, 0.4, boards))
    lit_side = smoothstep(0.25, -0.5, (xx / w + yy / h) - 1)
    leather = mt.shade(leather, 0.4 * rim * lit_side - 0.2 * rim * (1 - lit_side))
    a_boards = smoothstep(0.6, -0.6, boards)
    shadow = smoothstep(3.5, -0.5, rrect_sdf(xx, yy, left + 0.8, 3.4, w - 1.8, h - 1.4, 17.0))
    rgb = mt.shade(rgb, -0.5 * shadow * (1 - a_boards))
    rgb = mix(rgb, leather, a_boards)

    # The head and tail edges dip a little toward the spine (the pages curve down into it).
    def dip(x):
        return 1.8 * np.exp(-np.abs(x - spine) / 18.0)

    block = rrect_sdf(xx, yy, left + 2.5 if single else 5.0, 5.0 + dip(xx) * 0.5, w - 5.0, h - 5.0 - dip(xx) * 0.5, 9.0)
    a_block = smoothstep(0.5, -0.5, block)
    # Stacked page edges: fine light and dark lines following the outline, in shadow under the top page.
    depth = np.clip(-block, 0, None)
    lines = 0.5 + 0.5 * np.sin(depth * 2 * np.pi / 0.7 + 1.5 * fbm(H, W, rng, base=30, octaves=2))
    stack = mix(hexrgb(0x765738), hexrgb(0xC4A47A), 0.3 + 0.5 * lines)
    stack = mt.shade(stack, -0.3 * smoothstep(3.0, 0.0, depth))
    rgb = mix(rgb, stack, a_block)

    # The top pages: an inset outline, deckled a hair, with the same dip toward the spine.
    deckle = 0.22 * fbm(H, W, rng, base=90, octaves=2) + 0.18 * fbm(H, W, rng, base=20, octaves=2)
    x0 = -40.0 if single else 8.0
    page = rrect_sdf(xx, yy, x0, 7.6 + dip(xx), w - 8.0, h - 7.6 - dip(xx), 6.0) + deckle
    inside = smoothstep(0.45, -0.45, page)
    edge_in = np.clip(-page, 0, None)

    # Paper: body tone with slow mottling, faint fibres and laid lines; toned margins; a few fox marks.
    mott = fbm(H, W, rng, base=4, octaves=4, persistence=0.55)
    paper = mix(hexrgb(PAPER), hexrgb(PAPER_HI), 0.55 + 0.2 * mott)
    fib = mt.lic(rng.standard_normal((H, W)), np.full((H, W), 0.1) + 0.3 * fbm(H, W, rng, base=6, octaves=2), 3, step=0.7)
    paper = mt.shade(paper, 0.012 * fib / (fib.std() + 1e-9) + 0.014 * fbm(H, W, rng, base=120, octaves=1))
    laid = 0.5 + 0.5 * np.cos(2 * np.pi * yy / 0.9)
    chain = np.exp(-((((xx - spine) % 21.0) - 10.5) / 0.6) ** 2)
    paper = mt.shade(paper, -0.006 * laid - 0.01 * chain)
    toning = smoothstep(7.0, 0.0, edge_in + 1.6 * fbm(H, W, rng, base=6, octaves=3)) ** 1.5
    paper = mix(paper, hexrgb(PAPER_TONED), 0.5 * toning)
    # Foxing: sparse soft rust spots with a darker rim, more toward the edges.
    fox = np.zeros((H, W))
    for _ in range(int(w * h / 2400)):
        for _try in range(8):
            fx, fy = rng.uniform(10, w - 10), rng.uniform(10, h - 10)
            if rng.uniform() < 0.25 or min(fx - 8, w - 8 - fx, fy - 8, h - 8 - fy) < 24:
                break
        r = rng.uniform(0.45, 1.5)
        x_0, x_1 = int(max(0, (fx - 12) * SS)), int(min(W, (fx + 12) * SS))
        y_0, y_1 = int(max(0, (fy - 12) * SS)), int(min(H, (fy + 12) * SS))
        sx_, sy_ = xx[y_0:y_1, x_0:x_1], yy[y_0:y_1, x_0:x_1]
        d = np.hypot(sx_ - fx, (sy_ - fy) * rng.uniform(0.8, 1.2)) / r
        spot = np.exp(-d ** 2) * rng.uniform(0.3, 0.85) + 0.2 * np.exp(-((d - 1.0) / 0.35) ** 2)
        for _ in range(int(rng.integers(0, 4))):  # satellite specks
            px_, py_ = fx + rng.normal(0, r * 3), fy + rng.normal(0, r * 3)
            spot = spot + 0.45 * np.exp(-(np.hypot(sx_ - px_, sy_ - py_) / (r * 0.4)) ** 2)
        fox[y_0:y_1, x_0:x_1] = np.maximum(fox[y_0:y_1, x_0:x_1], spot)
    paper = mix(paper, hexrgb(0x8A5732), np.clip(fox, 0, 1) * 0.4)

    # The curve of the pages: each rises out of the gutter and lies nearly flat by the middle, lifting a touch at
    # its fore-edge. Lit from the upper left, so the verso turns away from the light into the spine and the recto
    # turns toward it, with the crease in shadow between them.
    if single:
        d = np.clip(xx - 9.0, 0, None)
        side = np.ones_like(d)
        fore = w - 8.0 - xx
    else:
        d = np.abs(xx - gutter)
        side = np.sign(xx - gutter + 1e-6)
        fore = np.where(side > 0, w - 8.0 - xx, xx - 8.0)
    slope = 1.4 * np.exp(-d / 6.0) + 0.45 * np.exp(-d / 22.0)
    slope = slope - 0.18 * np.exp(-np.clip(fore, 0, None) / 5.0)
    lx, ly, lz = om.norm3(-0.6, -0.3, 0.75)
    nX, nY, nZ = om.norm3(-side * slope, np.zeros_like(slope), np.ones_like(slope))
    lam = nX * lx + nY * ly + nZ * lz
    turn = np.clip((lam - lz) * 0.8, -0.42, 0.08)
    paper = mt.shade(paper, turn - 0.3 * np.exp(-d / 1.2) - 0.1 * np.exp(-d / 5.0))
    # A soft fall of light across the spread: fullest upper left, dimmer toward the foot and the far fore-edge.
    fall = 0.04 - 0.15 * smoothstep(0.15, 1.3, 0.5 * xx / w + 0.8 * yy / h)
    paper = mt.shade(paper, fall)

    # The paper's edge: a hair of shadow on the deckle, and the top page's cast shadow on the stack.
    paper = mt.shade(paper, -0.08 * (1 - smoothstep(0.0, 0.9, edge_in)))
    cast = smoothstep(2.2, 0.0, page) * (1 - inside)
    rgb = mt.shade(rgb, -0.45 * cast * a_block)
    rgb = mix(rgb, paper, inside)
    if single:
        # The facing page beyond the spine: a sliver curving away into shadow.
        verso = smoothstep(9.2, 8.4, xx) * inside
        sl = smoothstep(2.0, 9.0, xx)
        rgb = mix(rgb, mt.shade(mix(paper, hexrgb(PAPER_TONED), 0.4), -0.7 + 0.45 * (1 - sl)), verso)
    out = down(rgb)
    # A whisper of grain over everything, so the JPEG never bands.
    out = mt.shade(out, 0.01 * np.random.default_rng(seed + 1).standard_normal(out.shape[:2]))
    return out


def leaf(w, h, seed):
    """Plain aged paper: the back of the turned corner and the leaf beneath it."""
    rng = np.random.default_rng(seed)
    mott = fbm(h, w, rng, base=3, octaves=4)
    paper = mix(hexrgb(PAPER), hexrgb(PAPER_HI), 0.45 + 0.15 * mott)
    fib = mt.lic(rng.standard_normal((h, w)), np.full((h, w), 0.15), 4, step=0.8)
    return mt.shade(paper, 0.025 * fib / (fib.std() + 1e-9))


# MARK: The plates

def p(x, y):
    return (x, y)


FAR = om.FAR
MID = om.MID
NEAR = om.NEAR
rng_ = om.rng_
K = 2  # plates are painted at K times their size (and SS on top of that) and filtered down, for finer brushwork


def plate(w, h, seed, preview=None, name="", **kw):
    """om.painting at K times the plate's size, filtered down to 1 px per point."""
    value, glow = om.painting(w * K, h * K, seed, preview=None, name=name, **kw)
    value, glow = down(value, K), down(glow, K)
    if preview:
        om.write_preview(preview, name, value, glow)
    return value, glow


def trees(which, height, spacing, coverage, tone):
    """Fir rows, sized in plate points (scaled up for the K-times canvas)."""
    return (which, (height[0] * K, height[1] * K), spacing * K, coverage, tone)


def plate_day_large(pv):
    # Tall frontispiece. The light breaks high between dark banks; a great snowy peak rises through lit cumulus;
    # below it ridge after ridge recedes through the valley mist, and a dark fir wood closes the foot of the plate.
    return plate(138, 264, 501, sun=(0.4, 0.12), horizon=0.42,
                 clouds=[(0.0, 0.1, 0.5, 0.1, 30, 0.55), (1.0, 0.08, 0.44, 0.09, 26, 0.5),
                         (0.9, 0.33, 0.6, 0.16, 70), (0.06, 0.35, 0.44, 0.1, 40, 0.1)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.45), p(0.12, 0.41), p(0.24, 0.34), p(0.36, 0.25), p(0.46, 0.19),
                                     p(0.54, 0.22), p(0.64, 0.29), p(0.76, 0.35), p(0.9, 0.4), p(1, 0.42)],
                          seed=511, snowline=0.36, mist=(40, 120, 0.8)),
                     rng_(MID, keys=[p(0, 0.5), p(0.16, 0.52), p(0.34, 0.49), p(0.52, 0.53), p(0.7, 0.5),
                                     p(0.86, 0.54), p(1, 0.52)], seed=523, tone=0.32, mist=(8, 40, 0.6)),
                     rng_(MID, keys=[p(0, 0.62), p(0.22, 0.59), p(0.44, 0.63), p(0.62, 0.6), p(0.84, 0.64),
                                     p(1, 0.61)], seed=527, tone=0.25, mist=(6, 40, 0.5)),
                     rng_(MID, keys=[p(0, 0.72), p(0.18, 0.74), p(0.4, 0.71), p(0.64, 0.75), p(0.86, 0.72),
                                     p(1, 0.74)], seed=529, tone=0.19, mist=(6, 30, 0.35)),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.8), p(0.12, 0.84), p(0.32, 0.88), p(0.6, 0.89), p(0.84, 0.85),
                                             p(1, 0.81)], seed=531),
                 trees=[trees(4, (16, 36), 5.0, 0.75, 0.06), trees(3, (6, 12), 3.5, 0.55, 0.11),
                        trees(2, (4, 7), 3.0, 0.4, 0.16)],
                 preview=pv, name="plate-day-large")


def plate_day_medium(pv):
    return plate(140, 96, 503, sun=(0.3, 0.16), horizon=0.6,
                 clouds=[(0.0, 0.12, 0.5, 0.18, 30, 0.5), (1.0, 0.14, 0.44, 0.18, 26, 0.5),
                         (0.78, 0.46, 0.5, 0.3, 54)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.62), p(0.12, 0.55), p(0.26, 0.42), p(0.38, 0.3), p(0.46, 0.36),
                                     p(0.58, 0.48), p(0.72, 0.56), p(1, 0.6)], seed=541, snowline=0.5,
                          mist=(20, 60, 0.65)),
                     rng_(MID, keys=[p(0, 0.7), p(0.18, 0.67), p(0.4, 0.71), p(0.62, 0.66), p(0.82, 0.7), p(1, 0.68)],
                          seed=543, mist=(6, 30, 0.4)),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.8), p(0.2, 0.84), p(0.45, 0.82), p(0.7, 0.86), p(1, 0.83)],
                                 seed=547),
                 trees=[trees(2, (10, 22), 5.0, 0.65, 0.07)], preview=pv, name="plate-day-medium")


def plate_day_small(pv):
    return plate(122, 54, 505, sun=(0.62, 0.2), horizon=0.62,
                 clouds=[(0.0, 0.2, 0.46, 0.22, 26, 0.5), (0.98, 0.18, 0.3, 0.2, 22, 0.45),
                         (0.82, 0.55, 0.36, 0.34, 40)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.66), p(0.14, 0.56), p(0.28, 0.4), p(0.38, 0.26), p(0.46, 0.34),
                                     p(0.58, 0.5), p(0.72, 0.58), p(1, 0.64)], seed=551, snowline=0.52,
                          mist=(16, 40, 0.6)),
                     rng_(MID, keys=[p(0, 0.74), p(0.2, 0.71), p(0.44, 0.75), p(0.66, 0.7), p(1, 0.73)], seed=553),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.84), p(0.3, 0.88), p(0.6, 0.86), p(1, 0.89)], seed=557),
                 trees=[trees(2, (7, 14), 4.0, 0.6, 0.07)], preview=pv, name="plate-day-small")


def plate_quote_large(pv):
    # Tall frontispiece: a gorge. Dark walls fall in from both sides, a far snow peak stands in the gap under
    # towering lit cloud, and the light pours down the valley through the mist.
    return plate(138, 280, 507, sun=(0.58, 0.15), horizon=0.4,
                 clouds=[(0.0, 0.09, 0.5, 0.1, 30, 0.55), (1.0, 0.1, 0.4, 0.1, 26, 0.5),
                         (0.36, 0.31, 0.9, 0.19, 90), (0.92, 0.27, 0.36, 0.1, 36)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.46), p(0.2, 0.43), p(0.34, 0.37), p(0.46, 0.31), p(0.54, 0.28),
                                     p(0.62, 0.32), p(0.74, 0.39), p(1, 0.45)], seed=561, snowline=0.38,
                          mist=(30, 100, 0.75)),
                     rng_(MID, keys=[p(0, 0.48), p(0.18, 0.5), p(0.36, 0.53), p(0.5, 0.52), p(0.66, 0.54),
                                     p(0.84, 0.5), p(1, 0.49)], seed=562, tone=0.3, mist=(6, 40, 0.6)),
                     rng_(MID, keys=[p(0, 0.34), p(0.08, 0.4), p(0.18, 0.5), p(0.3, 0.6), p(0.42, 0.66),
                                     p(0.6, 0.67), p(0.74, 0.6), p(0.86, 0.5), p(0.94, 0.43), p(1, 0.38)],
                          seed=563, tone=0.2, mist=(10, 80, 0.3)),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.7), p(0.14, 0.76), p(0.3, 0.82), p(0.5, 0.86), p(0.72, 0.84),
                                             p(0.88, 0.78), p(1, 0.72)], seed=571, tone=0.12),
                 trees=[trees(3, (16, 38), 5.5, 0.75, 0.06), trees(2, (5, 11), 3.5, 0.5, 0.13)],
                 preview=pv, name="plate-quote-large")


def plate_quote_medium(pv):
    # A long headpiece: the whole range under a band of cloud, the light breaking over the highest summit.
    return plate(304, 48, 509, sun=(0.56, 0.18), horizon=0.62,
                 clouds=[(0.0, 0.22, 0.24, 0.26, 30, 0.5), (1.0, 0.2, 0.22, 0.24, 30, 0.5),
                         (0.3, 0.5, 0.22, 0.4, 40), (0.8, 0.48, 0.2, 0.38, 36)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.66), p(0.08, 0.56), p(0.16, 0.6), p(0.26, 0.46), p(0.36, 0.5),
                                     p(0.46, 0.34), p(0.54, 0.26), p(0.6, 0.36), p(0.7, 0.48), p(0.8, 0.44),
                                     p(0.9, 0.56), p(1, 0.62)], seed=581, snowline=0.52, mist=(14, 40, 0.6)),
                     rng_(MID, keys=[p(0, 0.74), p(0.2, 0.7), p(0.4, 0.75), p(0.6, 0.71), p(0.8, 0.76), p(1, 0.72)],
                          seed=583, mist=(4, 20, 0.35)),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.84), p(0.25, 0.88), p(0.5, 0.86), p(0.75, 0.9), p(1, 0.86)],
                                 seed=587),
                 trees=[trees(2, (7, 15), 4.5, 0.6, 0.07)], preview=pv, name="plate-quote-medium")


def plate_quote_small(pv):
    return plate(122, 54, 511, sun=(0.36, 0.2), horizon=0.6,
                 clouds=[(0.0, 0.18, 0.36, 0.2, 24, 0.5), (1.0, 0.2, 0.5, 0.22, 26, 0.5),
                         (0.64, 0.52, 0.4, 0.34, 40)],
                 ranges=[
                     rng_(FAR, keys=[p(0, 0.6), p(0.16, 0.44), p(0.26, 0.3), p(0.36, 0.38), p(0.5, 0.52),
                                     p(0.7, 0.5), p(0.84, 0.58), p(1, 0.62)], seed=591, snowline=0.5,
                          mist=(16, 40, 0.6)),
                     rng_(MID, keys=[p(0, 0.74), p(0.25, 0.7), p(0.5, 0.75), p(0.75, 0.7), p(1, 0.74)], seed=593),
                 ],
                 foreground=rng_(NEAR, keys=[p(0, 0.86), p(0.3, 0.88), p(0.62, 0.85), p(1, 0.89)], seed=597),
                 trees=[trees(2, (7, 15), 4.0, 0.6, 0.07)], preview=pv, name="plate-quote-small")


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]

    def want(n):
        return not only or n in only

    if want("spread-large"):
        save_rgb("spread-large", book(348, 365, 601, gutter=174.0))
    if want("spread-medium"):
        save_rgb("spread-medium", book(348, 164, 603, gutter=174.0))
    if want("page-medium"):
        save_rgb("page-medium", book(348, 164, 605, single=True))
    if want("page-small"):
        save_rgb("page-small", book(164, 164, 607, single=True))
    if want("leaf"):
        save_rgb("leaf", leaf(96, 96, 609))
    plates = {"plate-day-large": plate_day_large, "plate-day-medium": plate_day_medium,
              "plate-day-small": plate_day_small, "plate-quote-large": plate_quote_large,
              "plate-quote-medium": plate_quote_medium, "plate-quote-small": plate_quote_small}
    for name, fn in plates.items():
        if not want(name):
            continue
        value, glow = fn(pv)
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
    if want("veil"):
        save_alpha("veil", om.veil(160, 160, 613))


if __name__ == "__main__":
    main()
