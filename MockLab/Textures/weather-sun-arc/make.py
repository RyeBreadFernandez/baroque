#!/usr/bin/env python3
"""Sun Arc textures: the Old Master Cover's sepia oil painting of the Matterhorn, recomposed so its sky is the sun's
path. The widget draws a fine gilt arc across the open sky, from the horizon on the left to the horizon on the right
over the summit, with the sun (or the moon) riding it; these canvases leave that sky calm and mid-dark, so a gilt
hairline reads across it, and put the weather's cloud low at the sides.

Each canvas is painted with the Cover's own machinery (MockLab/Textures/old-master-cover/make.py, imported from its
path, not copied: the traced Matterhorn, Old Master's sky_field, cumulus, ranges and firs, and the stroke passes of
scripts/make_textures.py) as one value study, and written as alpha PNGs at 1 px per point of the widget:

  <name>-lo.png, <name>-hi.png   alpha = the lower and upper half of the painted value; glazed at run time with the
                                 Cover's CoverLight (shadow, warm mid, light), so one canvas serves day, dusk, night
                                 and grey weather.
  <name>-glow.png                alpha = the brightest lights (cloud tops, lit snow), glazed in the colour of the sun.
  <name>-front.png               alpha = the land (ridges, the Matterhorn, firs): drawn again over the sun, the moon
                                 and the arc's feet, so the sun rises and sets behind the ridges.
  names: large 348x365, medium 348x164, small 164x164 (the Weather widget)
         todo-medium 348x164, todo-small 164x164 (the To-do widget: the painting's dark ground, lo/hi only)
Other:
  wallpaper.jpg  780x805  the board's home screen (not a widget texture): a sepia cloudscape after Old Master's.

The arc geometry is fixed per canvas in Swift (SACanvas.arc in Sources/WSunArc/SAPainting.swift); the summit sits
under the arc's crown with room to spare, and the arc's feet stand on the ridge crest (ARC below mirrors it, for the
previews).

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-sun-arc/make.py [names...]
Add --preview <folder> to also write day-palette previews with the arc drawn on.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing the Cover's make.py (and through it Old Master's and scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("oc_make", os.path.join(os.path.dirname(HERE), "old-master-cover", "make.py"))
oc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oc)
om, mt, SS = oc.om, oc.mt, oc.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def left_wall(w, h, rng, x0, x1):
    """A wall of near firs standing on the left, its edge wandering between x0 and x1 (fractions): three ranks of
    tall spires (Old Master's fir), the outer rank a little lit along the edge that faces the open sky, the inner
    ranks darker until they merge into the dark wood the temperature is set on. Returns mask, value."""
    edge = om.crest([(0, x1), (0.3, x0), (0.65, x0 + 0.6 * (x1 - x0)), (1, x0)], int(rng.integers(1000)), h, w, 0.18)
    xx = np.mgrid[0:h, 0:w][1].astype(np.float64)
    mask = np.zeros((h, w))
    value = np.zeros((h, w))
    unit = h / (164 * SS)  # tree sizes in points of a 164 pt tall canvas
    for rank, (tone, inset, size) in enumerate([(0.17, -4, (40, 64)), (0.1, 10, (56, 90)), (0.055, 24, (76, 116))]):
        img = Image.new("L", (w * 2, h * 2), 0)
        d = ImageDraw.Draw(img)
        y = -50.0 * SS * unit
        while y < h:
            hh = rng.uniform(*size) * SS * unit
            base = y + hh
            row = int(np.clip(base - hh * 0.5, 0, h - 1))
            x = edge[row] - (inset + rng.uniform(-4, 5)) * SS * unit - hh * 0.1
            d.polygon([(px * 2, py * 2) for px, py in om.fir(x, base, hh, rng)], fill=255)
            y += hh * rng.uniform(0.26, 0.38)
        m = np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
        solid = smoothstep(edge[:, None] - (inset + 14) * SS * unit, edge[:, None] - (inset + 24) * SS * unit, xx)
        m = np.maximum(m, solid)
        rim = np.clip(-sobel(gaussian_filter(m, 0.5 * SS), axis=1) / 4 * SS, 0, 1)  # the edge toward the sky
        tex = 0.012 * fbm(h, w, rng, base=10, octaves=3, stretch=0.4)
        value = value * (1 - m) + (tone + tex + 0.14 * rim * (1 - rank / 2)) * m
        mask = np.maximum(mask, m)
    return mask, value


def arc_painting(w, h, seed, sun, horizon, clouds, peak, mid, near, trees, sky=None, contrast=1.3,
                 ground_dark=(0.62, 1.0, 0.4), wall=None, calm=None):
    """A value study at SS times the widget's size, painted and filtered to 1 px per point: the Cover's
    cover_painting with no hero glyph, an optional fir wall on the left, and a calm passage of sky under the arc.
    peak: (sx, sy, height pt) for the traced Matterhorn, or None; mid, near: ranges in front of its foot (Old Master's
    mountain() dicts with keys); trees: [(range index into [peak?, mid, near], height pt, spacing pt, coverage, value)];
    calm: (cx, cy, rx, ry, amount) fractions, an ellipse of sky the wisps and rays are smoothed out of, so the gilt arc
    reads. Returns value, glow, land (0..1)."""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    V, angle = om.sky_field(w, h, rng, sun, horizon, **(sky or {}))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    if calm is not None:
        cx, cy, rx, ry, amount = calm
        d = np.hypot((xx / w - cx) / rx, (yy / h - cy) / ry)
        quiet = amount * smoothstep(1.15, 0.7, d)
        V = V + (gaussian_filter(V, 6 * SS) - V) * quiet
    glow = np.zeros((h, w))
    for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
        if not layer:
            continue
        cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, sun)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit * 0.9
        angle = np.where(ccover > 0.3, ctan, angle)

    land = np.zeros((h, w))
    lean = np.zeros((h, w))
    keep = np.zeros((h, w))
    crests = []
    ranges = ([dict(matterhorn=peak)] if peak else []) + [mid, near]
    ground = None
    for r in ranges:
        r = dict(r)
        if "matterhorn" in r:
            sx, sy, height = r.pop("matterhorn")
            cy = oc.view_crest(w, h, sx, sy, height * SS)
            v, cover, snow_lit, nx, crisp = oc.matterhorn(w, h, rng, cy, sx, sy, height * SS)
            keep = np.maximum(keep * (1 - cover), crisp)
        else:
            cy = om.crest(r.pop("keys"), r.pop("seed"), w, h, r.pop("roughness", 0.22))
            v, cover, snow_lit, nx = om.mountain(w, h, rng, cy, r.pop("tone"), r.pop("light", oc.LIGHT), **r)
            keep *= 1 - cover
        crests.append(cy)
        V = V + (v - V) * cover
        glow = glow * (1 - cover) + snow_lit * cover
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + nx * cover
        ground = cover
    g0, g1, amount = ground_dark
    V = V * (1 - amount * smoothstep(g0 * h, g1 * h, yy) * land)

    tree_mask = np.zeros((h, w))
    for which, height, spacing, coverage, tone in trees:
        m = om.firs(w, h, rng, crests[which], height, spacing, coverage)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        V = V + (tone - V) * m + 0.10 * rimlight * (1 - m * 0.5)
        glow *= 1 - m
        land = np.maximum(land, m)
        tree_mask = np.maximum(tree_mask, m)

    if wall is not None:
        fm, fv = left_wall(w, h, rng, *wall)
        V = V + (fv - V) * fm
        glow *= 1 - fm
        land = np.maximum(land, fm)
        tree_mask = np.maximum(tree_mask, fm * smoothstep(0.9, 1.0, fm))
        lean = lean * (1 - fm)

    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    k = pw * ph / (348 * 365)
    s = SS
    solid = (land > 0.5).astype(np.float64)
    sky_field = oc.within(V, 1 - solid, 6 * SS)
    land_field = oc.within(V, solid, 6 * SS)
    sky_out = mt.paint(np.stack([sky_field] * 3, axis=2), angle, rng,
                       [(int(380 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                        (int(1300 * k), (3 * s, 5.5 * s), (7 * s, 18 * s)),
                        (int(2400 * k), (1.4 * s, 2.6 * s), (4 * s, 9 * s)),
                        (int(3200 * k), (0.7 * s, 1.2 * s), (3 * s, 7 * s))], 0.03)
    land_out = mt.paint(np.stack([land_field] * 3, axis=2), angle, rng,
                        [(int(500 * k), (4 * s, 8 * s), (6 * s, 14 * s)),
                         (int(1600 * k), (2 * s, 4 * s), (4 * s, 9 * s)),
                         (int(2400 * k), (1.2 * s, 2.2 * s), (2.5 * s, 6 * s)),
                         (int(2600 * k), (0.7 * s, 1.1 * s), (2 * s, 4 * s))], 0.04)
    out = sky_out * (1 - land[..., None]) + land_out * land[..., None]
    out = gaussian_filter(out[..., 0], 0.4 * s)
    out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(keep, 0.5 * s) * 0.85
    out = out + (np.minimum(out, V) - out) * gaussian_filter(tree_mask, 0.5 * s) * 0.7
    if ground is not None:
        out = out + (np.minimum(out, V + 0.04) - out) * gaussian_filter(ground, 0.5 * s)
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
    land = gaussian_filter(land, 0.35 * s)
    return om.down(out), om.down(glow), om.down(land)


def p(x, y):
    return (x, y)


MID = dict(tone=0.24, haze=0.05, haze_v=0.62, roughness=0.3, contrast=1.0, mist=(6, 20, 0.3))
NEAR = dict(tone=0.13, contrast=0.45, roughness=0.3, gully=0.2)


def r_(d, **kw):
    out = dict(d)
    out.update(kw)
    return out


# The arcs (fractions of the widget; mirrored in SACanvas.arc): centre x, horizon y, radius across, radius up.
ARC = {
    "large": (0.5, 0.575, 0.42, 0.45),
    "medium": (0.665, 0.75, 0.28, 0.5),
    "small": (0.5, 0.625, 0.39, 0.42),
}

# The Matterhorn on each canvas: summit (x, y) as fractions and the pyramid's height in points, at one scale.
PEAKS = {
    "large": (0.44, 0.235, 112),
    "medium": (0.625, 0.37, 56),
    "small": (0.45, 0.335, 48),
}


def large():
    # The Matterhorn a little left of centre under the arc's crown; a calm umber sky round the crown; dark cloud banks
    # in the upper corners and lit cumulus low at both feet; the dark ground from 0.63 down carries the temperature.
    return arc_painting(348, 365, 601, sun=(0.56, 0.12), horizon=0.58,
                        sky=dict(dark_top=0.2, bright=0.62, low=0.6),
                        clouds=[(-0.02, 0.12, 0.42, 0.12, 34, 0.55), (1.02, 0.1, 0.44, 0.12, 34, 0.5),
                                (0.22, 0.565, 0.18, 0.12, 30), (0.79, 0.57, 0.2, 0.15, 34),
                                (0.7, 0.4, 0.12, 0.04, 14)],
                        calm=(0.5, 0.3, 0.32, 0.2, 0.55),
                        peak=PEAKS["large"],
                        mid=r_(MID, keys=[p(0, 0.57), p(0.2, 0.575), p(0.45, 0.585), p(0.7, 0.59), p(1, 0.58)], seed=23),
                        near=r_(NEAR, keys=[p(0, 0.605), p(0.12, 0.61), p(0.3, 0.615), p(0.5, 0.62), p(0.7, 0.615),
                                            p(0.9, 0.61), p(1, 0.605)], seed=31),
                        trees=[(2, (7, 15), 5.5, 0.5, 0.07)], ground_dark=(0.61, 0.95, 0.45))


def medium():
    # Left: a wall of dark firs, the ground the temperature is set on. Right: the Matterhorn under a wide arc, its feet
    # on the ridge, a lit puff low on the right and a dark bank in the upper right corner.
    return arc_painting(348, 164, 603, sun=(0.7, 0.05), horizon=0.74,
                        sky=dict(dark_top=0.16, bright=0.6, low=0.62),
                        clouds=[(1.02, 0.12, 0.3, 0.16, 26, 0.55), (0.88, 0.75, 0.12, 0.16, 20)],
                        calm=(0.665, 0.36, 0.26, 0.32, 0.55),
                        peak=PEAKS["medium"],
                        mid=r_(MID, keys=[p(0.3, 0.74), p(0.45, 0.745), p(0.7, 0.755), p(1, 0.75)], seed=41),
                        near=r_(NEAR, keys=[p(0.3, 0.79), p(0.5, 0.8), p(0.7, 0.81), p(0.85, 0.8), p(1, 0.79)], seed=47),
                        trees=[(2, (8, 15), 5.5, 0.5, 0.07)], wall=(0.33, 0.37), ground_dark=(0.78, 1.0, 0.4))


def small():
    # The Matterhorn under a compact arc; the dark ground from 0.68 down carries the temperature and the next sun time.
    return arc_painting(164, 164, 605, sun=(0.6, 0.06), horizon=0.62,
                        sky=dict(dark_top=0.16, bright=0.64, low=0.62),
                        clouds=[(-0.02, 0.1, 0.4, 0.12, 24, 0.55), (1.02, 0.12, 0.4, 0.14, 24, 0.5),
                                (0.76, 0.6, 0.16, 0.1, 16)],
                        calm=(0.5, 0.36, 0.34, 0.24, 0.5),
                        peak=PEAKS["small"],
                        mid=r_(MID, keys=[p(0, 0.615), p(0.3, 0.625), p(0.6, 0.635), p(1, 0.63)], seed=53),
                        near=r_(NEAR, keys=[p(0, 0.665), p(0.2, 0.67), p(0.5, 0.675), p(0.8, 0.67), p(1, 0.665)], seed=57),
                        trees=[(2, (6, 11), 5.0, 0.5, 0.07)], ground_dark=(0.66, 1.0, 0.45))


def todo(w, h, seed):
    """The painting's dark ground for the To-do widget: a thin band of dusk sky at the top, a far ridge and a rank of
    fir tips against it, then the near ground in long dark strokes (values about 0.06 to 0.3, never flat)."""
    band = 0.16 if h > 150 and w > 300 else 0.17
    value, glow, _ = arc_painting(w, h, seed, sun=(0.75, -0.2), horizon=band,
                                  sky=dict(dark_top=0.3, bright=0.48, low=0.46),
                                  clouds=[], peak=None,
                                  mid=r_(MID, tone=0.2, keys=[p(0, band - 0.01), p(0.4, band), p(0.8, band - 0.015),
                                                              p(1, band - 0.005)], seed=seed + 1, mist=None),
                                  near=r_(NEAR, tone=0.11, keys=[p(0, band + 0.05), p(0.5, band + 0.06),
                                                                 p(1, band + 0.05)], seed=seed + 2),
                                  trees=[(0, (5, 11), 4.5, 0.6, 0.06), (1, (8, 16), 6.0, 0.5, 0.05)],
                                  contrast=1.15, ground_dark=(band + 0.05, 1.0, 0.35))
    return value, glow


def wallpaper(w, h, seed):
    """Old Master's sepia Baroque cloudscape, painted afresh for this board (its own seed)."""
    return om.wallpaper(w, h, seed)


def preview(folder, name, value, glow, land):
    """Day-palette composite with the arc drawn on (solid to a third of the way, dashed after), for checking the
    art without building Swift."""
    h, w = value.shape
    c0, c1, c2 = hexrgb(0x24170F), hexrgb(0xEEDDC2), hexrgb(0xF6CF98)
    rgb = mix(np.ones(value.shape + (3,)) * c0, np.ones(value.shape + (3,)) * c1, value)
    rgb = mix(rgb, np.ones(value.shape + (3,)) * c2, glow * 0.6)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC)
    if name in ARC:
        cx, hz, rx, ry = ARC[name]
        d = ImageDraw.Draw(img)
        pts = [((cx * w + rx * w * np.cos(np.pi * (1 - t))) * 3, (hz * h - ry * h * np.sin(np.pi * (1 - t))) * 3)
               for t in np.linspace(0, 1, 200)]
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            if i < 66 or (i // 3) % 2 == 0:
                d.line([a, b], fill=(236, 196, 138), width=3)
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"pv-{name}.png"))


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    jobs = {"large": large, "medium": medium, "small": small}
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        value, glow, land = fn()
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
        save_alpha(name + "-front", land)
        if pv:
            preview(pv, name, value, glow, land)
    for name, (w, h, seed) in {"todo-medium": (348, 164, 611), "todo-small": (164, 164, 613)}.items():
        if only and name not in only:
            continue
        value, glow = todo(w, h, seed)
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        if pv:
            preview(pv, name, value, glow, None)
    if not only or "wallpaper" in only:
        rgb = wallpaper(780, 805, 617)
        px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
        Image.fromarray(px, "RGB").save(os.path.join(HERE, "wallpaper.jpg"), quality=88, subsampling=0)
        print("wallpaper.jpg: 780x805")


if __name__ == "__main__":
    main()
