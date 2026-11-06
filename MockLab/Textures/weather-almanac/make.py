#!/usr/bin/env python3
"""Almanac textures: the painted plate at the head of each almanac page, the page itself and the board's wallpaper.

The plate is an oil sketch of the Matterhorn from the Riffelsee (the traced skyline in
old-master-cover/matterhorn.json, at one scale, never stretched), painted with the shared brush: Old Master's sky_field,
cumulus, mountain and firs (old-master/make.py), Old Master Cover's matterhorn() (old-master-cover/make.py) and the
stroke passes of scripts/make_textures.py, all imported from their paths, not copied. Each plate is one value study,
tinted at run time like the shipped Cover paintings, so one canvas serves morning, dusk, night and grey weather:

  plate-<size>-lo.png, -hi.png  alpha = the lower and upper half of the painted value (a three-stop gradient map)
  plate-<size>-glow.png         alpha = the brightest lights (lit snow, cloud tops), glazed in the sun's colour
  plate-<size>-land.png         alpha = the land (peak, ridges, firs): drawn again over the sun or moon, so they set
                                behind the mountain
  plate-<size>-olive.png        alpha = the near ridges and firs, glazed olive (the page's second colour)
  sizes: large 324x160, medium 324x64, small 144x54 (1 px per point: the plate's size on the page)

The page:
  paper-lo.png, paper-hi.png    348x365  alpha = the dark and the light of a brushed gesso board (the lit ridges of
                                level strokes, bristle drag, fibres, tooth, a little foxing), at the strength they are
                                laid on. Tinted cream by day and espresso at night; medium and small use its top-left
                                corner.
  veil.png                      324x160  rain on the plate: Old Master's veil(), re-run here so the look owns its files
  wallpaper.jpg                 780x805  the board's home screen (not a widget texture): the plate's subject painted
                                large and dim in espresso and olive, the Matterhorn under a low evening sky.

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-almanac/make.py [names...]
Add --preview <folder> to also write day-palette previews of the plates.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # the imported make.py files (and scripts/) must not leave a __pycache__ behind

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
    """White with the given alpha (the widgets render these as template images)."""
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"),
                                                                              optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def save_rgb(name, rgb, quality=88):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=quality, subsampling=0)
    print(f"{name}.jpg: {rgb.shape[1]}x{rgb.shape[0]}")


# MARK: The plate

LIGHT = (0.55, -0.6, 0.6)   # from the upper right, as on the Matterhorn in the photograph
MID = dict(tone=0.26, haze=0.08, haze_v=0.6, contrast=1.0, light=LIGHT)
NEAR = dict(tone=0.16, contrast=0.55, gully=0.25, light=LIGHT)


def plate(w, h, seed, frame, sun, horizon, clouds, mid, near, trees, sky=None, contrast=1.25, mist=(6, 18, 0.32),
          rough=(0.3, 0.32)):
    """One plate as a value study at SS times its size, painted and filtered to 1 px per point.
    frame: the Matterhorn's summit (x, y fractions) and pyramid height in points; mid, near: crest keys (fractions)
    of the ridge wading in the mist at its foot and of the near ridge, roughened by `rough` (lower on the thin
    plates, whose long segments would otherwise throw up false peaks); trees: [(height range pt, spacing pt,
    coverage, value)] on the near ridge. Returns value, glow, land, olive (0..1)."""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    V, angle = om.sky_field(w, h, rng, sun, horizon, **(sky or {}))
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
    olive = np.zeros((h, w))
    # The Matterhorn, then the ridge at its foot, then the near ridge.
    sx, sy, height = frame
    cy = oc.view_crest(w, h, sx, sy, height * SS)
    v, cover, snow_lit, nx, crisp = oc.matterhorn(w, h, rng, cy, sx, sy, height * SS)
    V = V + (v - V) * cover
    glow = glow * (1 - cover) + snow_lit * cover
    land = np.maximum(land, cover)
    lean = lean * (1 - cover) + nx * cover
    keep = crisp
    for i, (keys, base) in enumerate(((mid, MID), (near, NEAR))):
        r = dict(base)
        cy = om.crest(keys, seed + 11 * (i + 1), w, h, rough[i])
        if i == 0:
            r["mist"] = mist
        v, cover, snow_lit, nx = om.mountain(w, h, rng, cy, r.pop("tone"), r.pop("light"), **r)
        keep *= 1 - cover
        V = V + (v - V) * cover
        glow = glow * (1 - cover) + snow_lit * cover
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + nx * cover
        olive = olive * (1 - cover) + cover * (0.55 if i == 0 else 1.0)
        near_cy = cy

    tree_mask = np.zeros((h, w))
    for height_pt, spacing, coverage, tone in trees:
        m = om.firs(w, h, rng, near_cy, height_pt, spacing, coverage)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        V = V + (tone - V) * m + 0.10 * rimlight * (1 - m * 0.5)
        glow *= 1 - m
        land = np.maximum(land, m)
        tree_mask = np.maximum(tree_mask, m)
        olive = np.maximum(olive, m)

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
    # The Matterhorn's drawing (the edge of its shadow, the Hornli ridge) laid back over the strokes, crisp.
    out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(keep, 0.5 * s) * 0.85
    out = out + (np.minimum(out, V) - out) * gaussian_filter(tree_mask, 0.5 * s) * 0.7
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
    land = gaussian_filter(land, 0.35 * s)
    olive = gaussian_filter(olive, 0.5 * s)
    return om.down(out), om.down(glow), om.down(land), om.down(olive)


def p(x, y):
    return (x, y)


def plate_large():
    # The whole pyramid stands in the plate, a little left of centre: the hooked summit high in open sky, the steep
    # left face falling to its foot behind a misty ridge, the shoulder running out to the right. Clouds bank low.
    return plate(324, 160, 709, frame=(0.4, 0.12, 104), sun=(0.84, 0.06), horizon=0.8,
                 sky=dict(dark_top=0.36, bright=0.84, low=0.7),
                 clouds=[(0.98, 0.12, 0.34, 0.1, 26, 0.45),
                         (0.9, 0.74, 0.34, 0.3, 46), (0.04, 0.76, 0.26, 0.2, 30)],
                 mid=[p(0, 0.74), p(0.15, 0.76), p(0.32, 0.8), p(0.55, 0.81), p(0.8, 0.8), p(1, 0.79)],
                 near=[p(0, 0.88), p(0.2, 0.89), p(0.45, 0.9), p(0.7, 0.895), p(1, 0.885)],
                 trees=[((8, 17), 5.5, 0.55, 0.07)], rough=(0.16, 0.3))


def plate_medium():
    # A panorama: the Matterhorn right of centre, lower ridges to the left, a band of firs along the foot.
    return plate(324, 64, 703, frame=(0.56, 0.11, 50), sun=(0.86, 0.02), horizon=0.84,
                 sky=dict(dark_top=0.36, bright=0.82, low=0.7),
                 clouds=[(0.16, 0.36, 0.24, 0.24, 24, 0.25), (0.98, 0.3, 0.22, 0.2, 20, 0.3),
                         (0.1, 0.84, 0.2, 0.24, 22), (0.92, 0.84, 0.2, 0.26, 22)],
                 mid=[p(0, 0.7), p(0.2, 0.74), p(0.4, 0.8), p(0.6, 0.84), p(0.8, 0.82), p(1, 0.8)],
                 near=[p(0, 0.9), p(0.25, 0.91), p(0.5, 0.93), p(0.75, 0.92), p(1, 0.91)],
                 trees=[((5, 10), 4.5, 0.55, 0.07)], mist=(3, 9, 0.3), rough=(0.1, 0.12))


def plate_small():
    # A close view: the summit left of centre, the shoulder running out toward the right edge.
    return plate(144, 54, 705, frame=(0.42, 0.13, 40), sun=(0.86, 0.04), horizon=0.84,
                 sky=dict(dark_top=0.36, bright=0.82, low=0.7),
                 clouds=[(1.0, 0.3, 0.34, 0.2, 18, 0.45), (0.02, 0.84, 0.3, 0.36, 22)],
                 mid=[p(0, 0.76), p(0.3, 0.8), p(0.6, 0.86), p(1, 0.84)],
                 near=[p(0, 0.92), p(0.3, 0.93), p(0.6, 0.94), p(1, 0.93)],
                 trees=[((5, 9), 4.2, 0.55, 0.07)], mist=(3, 9, 0.28), rough=(0.16, 0.16))


# MARK: The page

def paper(w, h, seed):
    """A brushed gesso board, quiet enough to print on: level strokes laid across, seen only by the light on their
    ridges and a little bristle drag, the soft cloud of the sheet's formation, hair-fine fibres, the tooth of the
    surface and a few foxing spots. Returns (dark alpha, light alpha), at the strength they are laid on."""
    rng = np.random.default_rng(seed)
    s = SS
    W, H = w * s, h * s
    k = w * h / (348 * 365)
    angle = 0.03 + 0.1 * np.tanh(1.2 * fbm(H, W, rng, base=2.0, octaves=2, persistence=0.4))
    tone = 0.5 + 0.02 * fbm(H, W, rng, base=4.0, octaves=3, persistence=0.5)
    out = mt.paint(np.stack([tone] * 3, axis=2), angle, rng,
                   [(int(420 * k), (8 * s, 16 * s), (50 * s, 130 * s)),
                    (int(1400 * k), (3 * s, 7 * s), (20 * s, 60 * s))], 0.03)
    out = gaussian_filter(out[..., 0], 0.6 * s)
    hp = out - gaussian_filter(out, 5 * s)                     # the strokes themselves, not the drift of tone
    g = gaussian_filter(out, 0.8 * s)
    ridge = -(sobel(g, axis=1) * 0.5 + sobel(g, axis=0))       # light from the upper left on each stroke's edge
    std = lambda a: a / (a.std() + 1e-9)
    value = 0.03 * std(hp) + 0.05 * std(ridge) + 0.03 * std(mt.bristles(H, W, rng, angle, 1.0))
    value += 0.035 * fbm(H, W, rng, base=5, octaves=4, persistence=0.6)       # the sheet's formation
    # Fibres: hair-fine curls, a few dark and a few light.
    fib = Image.new("F", (W, H), 0.0)
    d = ImageDraw.Draw(fib)
    for _ in range(int(900 * k)):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        a = rng.uniform(0, np.pi)
        pts = [(x, y)]
        for _ in range(int(rng.uniform(3, 8))):
            a += rng.normal(0, 0.5)
            x += np.cos(a) * 1.6 * s
            y += np.sin(a) * 1.6 * s
            pts.append((x, y))
        d.line(pts, fill=float(rng.choice([-1.0, 1.0], p=[0.6, 0.4]) * rng.uniform(0.4, 1.0)), width=1)
    value += 0.16 * gaussian_filter(np.asarray(fib, dtype=np.float64), 0.45)
    # Foxing: a few soft rust spots, one or two with a darker heart.
    fox = mt.speckle(H, W, rng, 0.000006 * 4 / s ** 2, (1.5 * s, 4.5 * s))
    value -= 0.22 * gaussian_filter(fox, 1.2 * s) / (gaussian_filter(fox, 1.2 * s).max() + 1e-9)
    # The tooth of the surface.
    value += 0.05 * gaussian_filter(rng.standard_normal((H, W)), 0.5)
    value = om.down(value)
    return np.clip(-value, 0, 1), np.clip(value, 0, 1)


# MARK: The board's wallpaper

def wallpaper(w, h, seed):
    """The board's home screen: the plate's own subject painted large and dim in espresso and olive (it frames the
    widgets, so it stays low and soft): the Matterhorn far off under a low evening sky, ridges and firs below."""
    value, glow, land, olive = plate(w, h, seed, frame=(0.68, 0.36, 250), sun=(0.25, 0.3), horizon=0.7,
                                     sky=dict(dark_top=0.22, bright=0.7, low=0.6),
                                     clouds=[(0.12, 0.3, 0.5, 0.12, 60, 0.35), (0.3, 0.62, 0.5, 0.22, 70),
                                             (1.0, 0.2, 0.5, 0.12, 50, 0.4)],
                                     mid=[p(0, 0.62), p(0.2, 0.64), p(0.45, 0.7), p(0.7, 0.72), p(1, 0.7)],
                                     near=[p(0, 0.8), p(0.3, 0.82), p(0.6, 0.8), p(1, 0.83)],
                                     trees=[((26, 60), 16, 0.6, 0.06)], contrast=1.1, mist=(20, 60, 0.3))
    value = gaussian_filter(value, 1.0)
    stops = [(0.0, 0x0E0B08), (0.3, 0x241D15), (0.55, 0x47402E), (0.75, 0x786B4D), (0.92, 0xAE986C), (1.0, 0xD3BE96)]
    ostops = [(0.0, 0x0B0C08), (0.3, 0x1C2016), (0.55, 0x353A27), (0.75, 0x5E6447), (1.0, 0x9DA07C)]

    def gmap(stops):
        rgb = np.zeros(value.shape + (3,))
        for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
            t = np.clip((value - a0) / (a1 - a0), 0, 1)
            sel = (value >= a0) & (value <= a1)
            rgb[sel] = (hexrgb(c0) * (1 - t[..., None]) + hexrgb(c1) * t[..., None])[sel]
        return rgb

    rgb = mix(gmap(stops), gmap(ostops), olive)
    rgb = mix(rgb, hexrgb(0xD9A866), 0.22 * gaussian_filter(glow, 1.5) * smoothstep(0.5, 0.9, value))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    vign = np.hypot((xx / w - 0.5) * 1.2, (yy / h - 0.48) * 1.0)
    return mt.shade(rgb * 0.85, -0.4 * smoothstep(0.3, 0.85, vign))


# MARK: Preview

def preview(folder, name, value, glow, land, olive):
    c0, c1, c2 = hexrgb(0x24160D), hexrgb(0xEFE0C4), hexrgb(0xF4D49C)
    ol0, ol1 = hexrgb(0x1A1A0E), hexrgb(0xA8A57A)
    rgb = mix(np.ones(value.shape + (3,)) * c0, np.ones(value.shape + (3,)) * c1, value)
    og = mix(np.ones(value.shape + (3,)) * ol0, np.ones(value.shape + (3,)) * ol1, value)
    rgb = mix(rgb, og, olive)
    rgb = mix(rgb, np.ones(value.shape + (3,)) * c2, glow * 0.5)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize(
        (value.shape[1] * 2, value.shape[0] * 2), Image.BICUBIC).save(os.path.join(folder, f"pv-{name}.png"))


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    jobs = {"plate-large": plate_large, "plate-medium": plate_medium, "plate-small": plate_small}
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        value, glow, land, olive = fn()
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
        save_alpha(name + "-land", land)
        save_alpha(name + "-olive", olive)
        if pv:
            preview(pv, name, value, glow, land, olive)
    if not only or "paper" in only:
        dark, light = paper(348, 365, 711)
        save_alpha("paper-lo", dark)
        save_alpha("paper-hi", light)
    if not only or "veil" in only:
        save_alpha("veil", om.veil(324, 160, 713))
    if not only or "wallpaper" in only:
        save_rgb("wallpaper", wallpaper(780, 805, 715))


if __name__ == "__main__":
    main()
