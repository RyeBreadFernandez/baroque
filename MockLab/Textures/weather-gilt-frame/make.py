#!/usr/bin/env python3
"""Gilt Frame textures: an oil painting of the Matterhorn hanging in a carved gilt frame on an oxblood damask
gallery wall, with an engraved brass museum plate for the weather.

Everything is painted here, deterministically, from height fields and the app's brush (scripts/make_textures.py,
through Old Master's and Old Master Cover's make.py, imported from their paths, not copied):

  The frame   a Louis XIV water-gilt frame, carved in a few bold members (so each is several pixels wide at 1 px per
              point): a gadrooned outer torus, a sanded cove, a beaded astragal and a dark sight slip, with a ribbed
              shell cartouche and two acanthus leaves at each corner, just breaking the outline. The to-do card's
              slimmer frame has a torus of large pearls instead of gadroons.
              The moulding is a height field swept round the rectangle (mitred at the corners) and lit like gold from
              a picture light above and to the left: a broad warm reflection of the lit room on faces turned up, the
              dark of the floor on faces turned down, a sharp specular on the burnished rounds, the sanded cove matte,
              grime in the hollows and the red bole showing where the gilt is worn off the high points.
  The painting  a value study of the Matterhorn from the Riffelsee, its pyramid traced from a photograph
              (old-master-cover/matterhorn.json, one scale), standing over the still lake that mirrors its foot, a
              dark shore and firs at the edges; painted with Old Master's strokes and glazed at run time (shadow, mid,
              light and glow), so one canvas serves the golden day, dusk, the moonlit night and grey weather.
  The wall    oxblood silk damask, the pattern woven only as a change of sheen.
  The brass   brushed brass for the museum plate (bevel, screws and engraving are drawn by SwiftUI).
  The card    aged ivory card for the to-do widget's framed card.

Files (1 px per point; alpha files are LA PNGs whose alpha is the value):
  frame-large.png  348x365  RGBA  the weather frame of each size, at its place on the widget (GFGeometry in Swift)
  frame-medium.png 348x164  RGBA
  frame-small.png  164x164  RGBA
  card-medium.png  348x164  RGBA  the slimmer frame of the to-do card, medium and small
  card-small.png   164x164  RGBA
  painting-<size>-lo.png, -hi.png, -glow.png   the painting inside each weather frame, at the size of the frame's
                   sight (large 200x190, medium 132x96, small 102x98): the lower and upper halves of the value and the
                   brightest lights, tinted at run time as a three-stop gradient map
  wall.jpg         348x365  RGB   the damask wall behind every widget (medium and small use its top left)
  brass.jpg        240x120  RGB   brushed brass
  card.jpg         330x140  RGB   ivory card
  wallpaper.jpg    780x805  RGB   the board's home screen: the same wall, larger (not a widget texture)

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-gilt-frame/make.py [names...]
  names: frames, paintings, wall, brass, card, wallpaper (default: all). --preview <folder> writes composites there.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing the sibling painters (and through them scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates, sobel

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name, folder):
    spec = importlib.util.spec_from_file_location(name, os.path.join(os.path.dirname(HERE), folder, "make.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


oc = _load("gf_oc_make", "old-master-cover")   # the traced Matterhorn painter
om = oc.om                                      # Old Master: sky, cumulus, ranges, firs
mt = om.mt                                      # scripts/make_textures.py: fbm, lic, paint, bristles
SS = om.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"),
                                                                              optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def save_rgba(name, rgba):
    a8 = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(a8, "RGBA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {rgba.shape[1]}x{rgba.shape[0]}")


def save_rgb(name, rgb, quality=90):
    a8 = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(a8, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=quality, optimize=True)
    print(f"{name}.jpg: {rgb.shape[1]}x{rgb.shape[0]}")


def down(a, k):
    """Box filter by k (k x k pixels to one)."""
    h, w = a.shape[0] // k, a.shape[1] // k
    if a.ndim == 2:
        return a[:h * k, :w * k].reshape(h, k, w, k).mean(axis=(1, 3))
    return a[:h * k, :w * k].reshape(h, k, w, k, a.shape[2]).mean(axis=(1, 3))


def norm3(x, y, z):
    n = np.sqrt(x * x + y * y + z * z) + 1e-9
    return x / n, y / n, z / n


# MARK: Geometry (points; mirrored in GFGeometry in Swift)
# name: (canvas width, height, frame x, y, width, height, moulding width, corner cartouche scale, style)
# The sight (the painting's opening) is the frame rect inset by the moulding width.

FRAMES = {
    "frame-large": (348, 365, 44, 14, 260, 250, 30, 1.0, "weather"),
    "frame-medium": (348, 164, 14, 12, 176, 140, 22, 0.9, "weather"),
    "frame-small": (164, 164, 14, 10, 136, 132, 17, 0.85, "weather"),
    "card-medium": (348, 164, 10, 10, 328, 144, 13, 0.8, "card"),
    "card-small": (164, 164, 10, 10, 144, 144, 13, 0.8, "card"),
}

SSF = 4  # the frames are modelled at 4x and box-filtered down, so every carved edge is antialiased


# MARK: The frame

def profile(t, style):
    """The moulding's section, outer edge (t = 0) to the sight edge (t = 1), in moulding widths of height: a few bold
    members, so each is several pixels wide at 1 px per point. Returns height, a matte factor (1 on the sanded cove,
    0 on the burnished rounds) and the bands the carving is placed in."""
    if style == "card":
        stops = dict(lip=(0.0, 0.05), torus=(0.05, 0.5), cove=(0.5, 0.8), astragal=(0.8, 0.9), slip=(0.9, 1.0))
    else:
        stops = dict(lip=(0.0, 0.05), torus=(0.05, 0.46), cove=(0.46, 0.76), astragal=(0.76, 0.88), slip=(0.88, 1.0))
    h = np.zeros_like(t)
    matte = np.zeros_like(t)
    bands = {}

    def band(name):
        lo, hi = stops[name]
        return (t >= lo) & (t < hi), np.clip((t - lo) / (hi - lo), 0, 1)

    m, u = band("lip")                                   # the frame's outer side, turning away
    h = np.where(m, 0.12 + 0.18 * np.sin(u * np.pi / 2), h)
    m, u = band("torus")                                 # the great round, carved
    round_ = np.sqrt(np.clip(1 - (2 * u - 1) ** 2, 0, 1))
    h = np.where(m, 0.30 + 0.30 * round_ ** 0.85, h)
    bands["torus"] = m * round_
    bands["torus_u"] = np.where(m, u, 0)
    m, u = band("cove")                                  # the hollow, sanded and matte
    h = np.where(m, 0.08 + 0.22 * (1 - np.sqrt(np.clip(1 - (1 - u) ** 2, 0, 1))), h)
    matte = np.where(m, smoothstep(0.0, 0.15, u) * smoothstep(1.0, 0.8, u), matte)
    m, u = band("astragal")                              # a burnished half-round
    h = np.where(m, 0.08 + 0.09 * np.sqrt(np.clip(1 - (2 * u - 1) ** 2, 0, 1)), h)
    bands["astragal"] = m * 1.0
    bands["astragal_u"] = np.where(m, u, 0)
    m, u = band("slip")                                  # the sight slip, flat and toned dark
    h = np.where(m, 0.05 - 0.02 * u, h)
    bands["slip"] = m * 1.0
    return h, matte, bands


def cartouche(p, q, W, rng):
    """A corner cartouche in corner coordinates (p along one rail and q along the other, both in pixels measured in
    from the frame's outer corner): a finely ribbed scallop shell over the mitre, springing from a rolled volute and
    just breaking the frame's outline at the corner, with a short acanthus leaf lying along each rail on the torus.
    Returns height (moulding widths) and coverage."""
    P, Q = p / W, q / W
    hx = hy = 0.6
    a = ((hx - P) + (hy - Q)) / np.sqrt(2)              # out along the diagonal, toward the corner
    b = ((P - hx) - (Q - hy)) / np.sqrt(2)              # across it
    r = np.hypot(a, b)
    th = np.arctan2(b, a)
    ribs = 13
    rim = 0.8 + 0.04 * np.abs(np.cos(ribs / 2 * th)) ** 0.5   # finely scalloped
    fan = (np.abs(th) < 1.05) & (r < rim)
    rib = np.abs(np.cos(ribs / 2 * th)) ** 1.2
    dome = np.sqrt(np.clip(1 - (r / rim) ** 2, 0, 1))
    shell = np.where(fan, 0.62 + 0.28 * dome + 0.07 * rib * smoothstep(0.1, 0.35, r), 0)
    shell = shell * smoothstep(1.05, 0.92, np.abs(th))
    # The volute at the hinge: a roll lying across the diagonal.
    roll_d = np.abs(a + 0.04) / 0.13
    roll_l = np.abs(b) / 0.34
    volute = np.where((roll_d < 1) & (roll_l < 1),
                      0.86 + 0.12 * np.sqrt(np.clip(1 - roll_d ** 2, 0, 1)) * np.sqrt(np.clip(1 - roll_l ** 4, 0, 1)), 0)
    leaves = np.zeros_like(P)
    for along, across in ((P, Q), (Q, P)):
        x = (along - 0.86) / 0.85                        # 0 at the shell's flank, 1 at the leaf's tip
        xc = np.clip(x, 0, 1)
        width = 0.19 * np.sin(np.pi * np.clip(xc * 0.85 + 0.15, 0, 1)) ** 0.8
        lob = 1 + 0.14 * np.cos(xc * 2 * np.pi) ** 2
        y = (across - 0.25) / (width * lob + 1e-6)
        inleaf = (x > 0) & (x < 1) & (np.abs(y) < 1)
        body = np.sqrt(np.clip(1 - y ** 2, 0, 1))
        leaf = 0.66 + 0.13 * body - 0.06 * np.exp(-(y / 0.16) ** 2) * smoothstep(0.0, 0.2, xc)
        leaves = np.maximum(leaves, np.where(inleaf, leaf - 0.06 * xc, 0))
    hgt = np.maximum.reduce([shell, volute, leaves])
    return hgt, (hgt > 0).astype(np.float64)


def gilt_frame(name):
    """One carved gilt frame at its place on a widget-sized canvas: RGBA, 1 px per point."""
    cw, ch, fx, fy, fw, fh, W, cscale, style = FRAMES[name]
    rng = np.random.default_rng(sum(map(ord, name)) * 7919)
    k = SSF
    w, h = cw * k, ch * k
    x0, y0, x1, y1 = fx * k, fy * k, (fx + fw) * k, (fy + fh) * k
    Wp = W * k
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    dl, dr, dt, db = xx - x0, x1 - xx, yy - y0, y1 - yy
    stack = np.stack([dt, db, dl, dr])
    d = stack.min(axis=0)
    side = stack.argmin(axis=0)                      # 0 top, 1 bottom, 2 left, 3 right
    t = d / Wp
    inside = (t >= 0) & (t <= 1)
    hgt, matte, bands = profile(np.clip(t, 0, 1), style)
    # Along each rail, measured out from the rail's centre, so the carving meets itself at the mitres.
    horizontal = side < 2
    s = np.where(horizontal, xx - (x0 + x1) / 2, yy - (y0 + y1) / 2)

    # Gadroons on the torus: convex lobes leaning toward the corners, grooved between; the card frame's torus is a
    # run of large pearls instead.
    tu = bands["torus_u"]
    if style == "card":
        pitch = 0.42 * Wp
        fr = np.abs(s) / pitch
        fr = fr - np.round(fr)
        r2 = (fr / 0.44) ** 2 + ((2 * tu - 1) / 0.95) ** 2
        hgt = hgt + (bands["torus"] > 0) * (0.12 * np.sqrt(np.clip(1 - r2, 0, 1)) - 0.06 * (r2 >= 1))
    else:
        pitch = 0.36 * Wp
        fr = (np.abs(s) + 0.6 * (d - 0.05 * Wp)) / pitch
        fr = fr - np.floor(fr)
        g = np.sin(np.pi * fr) ** 0.6
        hgt = hgt + 0.11 * bands["torus"] ** 0.5 * (g - 0.55)
    # Beads on the astragal (the large frames only; on the small ones it stays a plain burnished round).
    if Wp >= 20 * k:
        pitch = 0.13 * Wp
        fr = np.abs(s) / pitch
        fr = fr - np.round(fr)
        r2 = (fr / 0.45) ** 2 + ((2 * bands["astragal_u"] - 1) / 0.95) ** 2
        hgt = hgt + bands["astragal"] * (0.035 * np.sqrt(np.clip(1 - r2, 0, 1)) - 0.015 * (r2 >= 1))
    # Sanding on the cove: fine grain that dulls it.
    grain = fbm(h, w, rng, base=w / 6, octaves=2, persistence=0.6)
    hgt = hgt + 0.006 * matte * grain

    hgt = np.where(inside, hgt, 0.0)
    cover = inside.astype(np.float64)
    carved = np.zeros_like(hgt)

    # Corner cartouches, standing proud of the moulding and breaking its outline at the corner.
    if cscale > 0:
        Wc = Wp * cscale
        for (cx, cy, ix, iy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
            ys = slice(int(max(0, min(cy - iy * 0.6 * Wc, cy + iy * 2.4 * Wc))), int(min(h, max(cy - iy * 0.6 * Wc, cy + iy * 2.4 * Wc))))
            xs = slice(int(max(0, min(cx - ix * 0.6 * Wc, cx + ix * 2.4 * Wc))), int(min(w, max(cx - ix * 0.6 * Wc, cx + ix * 2.4 * Wc))))
            sl = (ys, xs)
            ch_, cc = cartouche((xx[sl] - cx) * ix, (yy[sl] - cy) * iy, Wc, rng)
            raised = ch_ * (1.0 if style != "card" else 0.9)
            hgt[sl] = np.where(cc > 0, np.maximum(hgt[sl], raised), hgt[sl])
            carved[sl] = np.maximum(carved[sl], cc)
            cover[sl] = np.maximum(cover[sl], cc)

    # The sight: the frame ends at the painting.
    sight = (xx > x0 + Wp) & (xx < x1 - Wp) & (yy > y0 + Wp) & (yy < y1 - Wp)
    cover = np.where(sight, 0, cover)
    hgt = np.where(sight, 0, hgt)

    # Lighting. Height in pixels: one moulding width of height is 0.55 moulding widths of depth.
    H = gaussian_filter(hgt * Wp * 0.55, 0.6 * k)
    gy, gx = np.gradient(H)
    nx, ny, nz = norm3(-gx, -gy, np.ones_like(gx))
    L = norm3(-0.38, -0.8, 0.62)                      # the picture light: above, a little to the left
    lam = nx * L[0] + ny * L[1] + nz * L[2]
    # Reflection of the room: the lit wall and ceiling above, the dark floor below.
    rx, ry, rz = 2 * nz * nx, 2 * nz * ny, 2 * nz * nz - 1
    env = smoothstep(0.55, -0.75, ry + 0.25 * rx)
    spec = np.clip(rx * L[0] + ry * L[1] + rz * L[2], 0, 1)
    spec = spec ** 30 * (1 - 0.85 * matte) + 0.3 * spec ** 5 * (1 - matte)
    # Grime in the hollows (ambient occlusion from the height field).
    ao = np.clip((gaussian_filter(H, 2.5 * k) - H) / (0.12 * Wp), 0, 1) + \
         0.6 * np.clip((gaussian_filter(H, 0.9 * k) - H) / (0.04 * Wp), 0, 1)
    ao = np.clip(ao, 0, 1)
    face = 0.5 + 0.5 * lam
    env = 0.32 + 0.68 * smoothstep(0.05, -0.7, ry + 0.3 * rx) - 0.27 * smoothstep(0.0, 0.6, ry)
    v = 0.05 + 0.24 * face ** 1.5 + 0.62 * env * (1 - 0.45 * matte) + 0.24 * matte * face
    v = v * (1 - 0.62 * ao) + 0.65 * spec
    # The rails turned to the light read brighter overall; the bottom rail, under its own shadow, darker.
    v *= 1.08 - 0.22 * np.clip((yy - y0) / (y1 - y0), 0, 1)   # the picture light falls off down the frame
    v = np.clip(v, 0, 1.15)

    # Gold: a gradient map from the dark of the hollows to the pale glint.
    stops = [(0.0, 0x140C04), (0.16, 0x33230C), (0.32, 0x634318), (0.48, 0x9A7026), (0.62, 0xC49A40),
             (0.76, 0xE2BE62), (0.9, 0xF6E2A0), (1.15, 0xFFFAE6)]
    rgb = np.zeros(v.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        tt = np.clip((v - a0) / (a1 - a0), 0, 1)[..., None]
        sel = ((v >= a0) & (v <= a1))[..., None]
        rgb = np.where(sel, hexrgb(c0) * (1 - tt) + hexrgb(c1) * tt, rgb)
    # Toned gilding: a slow drift of warmer and greener gold, so it is not a plated object.
    tone = fbm(h, w, rng, base=5, octaves=3)
    rgb = mix(rgb, rgb * hexrgb(0xC9B48A) * 1.15, 0.25 * smoothstep(0.2, 1.5, tone))
    # Worn gilt: the red bole on the high points of the carving and the rims, where hands and dusting reach.
    curv = H - gaussian_filter(H, 1.2 * k)
    high = smoothstep(0.012 * Wp, 0.05 * Wp, curv)
    wear_n = fbm(h, w, rng, base=w / 22, octaves=3)
    worn = high * smoothstep(0.35, 1.2, wear_n) * 0.75
    bole = hexrgb(0x7A3220) * (0.55 + 0.6 * face)[..., None]
    rgb = mix(rgb, bole, np.clip(worn, 0, 1) * cover)
    # Dust settled in the hollows of the carving, dark and a little green.
    rgb = mix(rgb, hexrgb(0x2A2312), 0.35 * ao * smoothstep(0.3, 1.0, fbm(h, w, rng, base=w / 30, octaves=2) + 1))
    # The sight slip is toned dark (a darker gilt, as in many period frames), so the painting's edge is crisp.
    if "slip" in bands:
        rgb = mix(rgb, rgb * 0.55, 0.8 * bands["slip"] * (carved < 0.5))
    rgba = np.concatenate([rgb, cover[..., None]], axis=2)
    rgba[..., :3] *= rgba[..., 3:4]
    out = down(rgba, k)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-4, out[..., :3] / np.maximum(a, 1e-4), 0)
    return np.clip(out, 0, 1)


# MARK: The painting

# Each painting fills its frame's sight. peak: the Matterhorn's summit (x, y fractions) and the height of its pyramid
# in points (one scale, from matterhorn.json); water: the lake's edge (fraction of the height); mid: the dark ridge in
# front of the mountain's foot (keys); shore: the near bank in the bottom corners (keys); firs: ((min, max height), spacing) in pt.
# Mirrored in GFGeometry.paintings in Swift (the lake's edge, for the sun's and moon's reflection).
PAINTINGS = {
    "large": dict(size=(200, 190), seed=811, peak=(0.47, 0.11, 84), water=0.64, sun=(0.3, 0.12), horizon=0.6,
                  sky=dict(dark_top=0.2, bright=0.74, low=0.66),
                  clouds=[(0.02, 0.36, 0.42, 0.2, 40, 0.5), (1.0, 0.3, 0.36, 0.16, 34, 0.55),
                          (0.12, 0.5, 0.3, 0.12, 30), (0.92, 0.52, 0.26, 0.1, 26)],
                  mid=[(0, 0.585), (0.18, 0.6), (0.4, 0.618), (0.62, 0.61), (0.82, 0.6), (1, 0.59)],
                  shore=[(0, 0.86), (0.12, 0.9), (0.26, 0.97), (0.4, 1.06), (0.6, 1.08), (0.76, 0.98), (0.9, 0.9),
                         (1, 0.85)],
                  firs=[(8, 26), 7.0]),
    "medium": dict(size=(132, 96), seed=813, peak=(0.5, 0.13, 48), water=0.68, sun=(0.3, 0.12), horizon=0.64,
                   sky=dict(dark_top=0.2, bright=0.72, low=0.66),
                   clouds=[(0.0, 0.42, 0.4, 0.22, 26, 0.5), (1.0, 0.36, 0.34, 0.2, 22, 0.55)],
                   mid=[(0, 0.62), (0.2, 0.635), (0.45, 0.655), (0.7, 0.645), (1, 0.63)],
                   shore=[(0, 0.86), (0.14, 0.92), (0.3, 1.04), (0.7, 1.06), (0.86, 0.94), (1, 0.86)],
                   firs=[(6, 16), 6.0]),
    "small": dict(size=(102, 98), seed=815, peak=(0.5, 0.12, 46), water=0.67, sun=(0.3, 0.12), horizon=0.63,
                  sky=dict(dark_top=0.2, bright=0.72, low=0.66),
                  clouds=[(0.0, 0.42, 0.42, 0.2, 22, 0.5), (1.0, 0.38, 0.36, 0.18, 20, 0.55)],
                  mid=[(0, 0.615), (0.25, 0.63), (0.5, 0.65), (0.75, 0.64), (1, 0.625)],
                  shore=[(0, 0.86), (0.16, 0.92), (0.32, 1.05), (0.7, 1.06), (0.86, 0.93), (1, 0.86)],
                  firs=[(5, 13), 5.0]),
}

LIGHT = (0.55, -0.6, 0.6)   # from the upper right, as on the Matterhorn in the photograph
MID = dict(tone=0.22, haze=0.08, haze_v=0.6, roughness=0.28, contrast=1.0, light=LIGHT, mist=(4, 16, 0.32))
SHORE = dict(tone=0.11, contrast=0.5, roughness=0.32, gully=0.25, light=LIGHT)


def riffelsee(name):
    """The Matterhorn above the Riffelsee: sky and cloud, the traced pyramid, a misty ridge at its foot, the still
    lake mirroring it (the reflection darker, rippled toward the viewer, laid in level strokes), the dark near bank
    with a few firs. A value study at SS, painted and filtered to 1 px per point. Returns value, glow (0..1)."""
    cfg = PAINTINGS[name]
    pw, ph = cfg["size"]
    w, h = pw * SS, ph * SS
    rng = np.random.default_rng(cfg["seed"])
    V, angle = om.sky_field(w, h, rng, cfg["sun"], cfg["horizon"], **cfg["sky"])
    glow = np.zeros((h, w))
    for layer in ([m for m in cfg["clouds"] if len(m) > 5], [m for m in cfg["clouds"] if len(m) <= 5]):
        if layer:
            cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, cfg["sun"])
            V = V + (cv - V) * ccover
            glow = glow * (1 - ccover) + clit * 0.9
            angle = np.where(ccover > 0.3, ctan, angle)
    # The Matterhorn, then the ridge at its foot.
    sx, sy, height = cfg["peak"]
    cy = oc.view_crest(w, h, sx, sy, height * SS)
    v, cover, snow_lit, nx, keep = oc.matterhorn(w, h, rng, cy, sx, sy, height * SS)
    V = V + (v - V) * cover
    glow = glow * (1 - cover) + snow_lit * cover
    land, lean = cover, nx * cover
    mid = dict(MID)
    cy2 = om.crest(cfg["mid"], cfg["seed"] + 1, w, h, mid.pop("roughness"))
    v, cover2, snow2, nx2 = om.mountain(w, h, rng, cy2, mid.pop("tone"), mid.pop("light"), **mid)
    V = V + (v - V) * cover2
    glow = glow * (1 - cover2) + snow2 * cover2
    keep = keep * (1 - cover2)
    land = np.maximum(land, cover2)
    lean = lean * (1 - cover2) + nx2 * cover2
    small_firs = om.firs(w, h, rng, cy2, (2.5, 5.5), 3.2, 0.55)
    V = V + (0.16 - V) * small_firs
    glow *= 1 - small_firs

    # The lake: the picture above mirrored in it, darker and a little softer, the reflection broken by faint
    # level ripples that grow toward the viewer, and a few wind lines catching the sky.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    yw = cfg["water"] * h
    depth = np.clip((yy - yw) / (h - yw), 0, 1)
    ripple = (0.1 + 0.7 * depth) * SS * (np.sin(yy * 1.1 / SS + 2.0 * fbm(h, w, rng, base=6, octaves=2))
                                         + 0.4 * fbm(h, w, rng, base=w / 6, octaves=2, stretch=4.0))
    src_y = np.clip(2 * yw - yy + 0.3 * SS * depth * fbm(h, w, rng, base=w / 10, octaves=2, stretch=5.0), 0, h - 1)
    src_x = np.clip(xx + ripple, 0, w - 1)
    Vr = map_coordinates(V, [src_y, src_x], order=1, mode="nearest")
    Gr = map_coordinates(glow, [src_y, src_x], order=1, mode="nearest")
    Kr = map_coordinates(keep, [src_y, src_x], order=1, mode="nearest")
    Vr = gaussian_filter(Vr, (0.25 * SS, 0.5 * SS))
    wind = smoothstep(1.2, 2.4, fbm(h, w, rng, base=w / 3, octaves=3, stretch=9.0)) * (0.3 + 0.7 * depth)
    Vl = 0.04 + 0.74 * Vr + 0.06 * wind - 0.06 * depth
    lake = smoothstep(yw - 0.4 * SS, yw + 0.4 * SS, yy)
    V = V * (1 - lake) + Vl * lake
    glow = glow * (1 - lake) + 0.5 * Gr * (1 - 0.6 * depth) * lake
    keep = keep * (1 - lake) + 0.7 * Kr * lake
    # A bright line where the water meets the far bank.
    V = V + 0.1 * np.exp(-((yy - yw - 0.6 * SS) / (0.5 * SS)) ** 2)
    water = lake.copy()

    # The near bank in the bottom corners, and its firs.
    shore = dict(SHORE)
    cy3 = om.crest(cfg["shore"], cfg["seed"] + 2, w, h, shore.pop("roughness"))
    v, cover3, _, nx3 = om.mountain(w, h, rng, cy3, shore.pop("tone"), shore.pop("light"), **shore)
    V = V + (v - V) * cover3
    glow *= 1 - cover3
    keep *= 1 - cover3
    water *= 1 - cover3
    land = np.maximum(land * (1 - lake), cover3)
    lean = lean * (1 - lake) * (1 - cover3) + nx3 * cover3
    (fh0, fh1), spacing = cfg["firs"]
    firs = om.firs(w, h, rng, cy3, (fh0, fh1), spacing, 0.6)
    firs *= smoothstep(0.42 * w, 0.2 * w, np.abs(xx - w / 2))     # only toward the corners
    rim = np.clip(-sobel(gaussian_filter(firs, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
    V = V + (0.06 - V) * firs + 0.08 * rim * (1 - firs * 0.5)
    glow *= 1 - firs
    land = np.maximum(land, firs)
    water *= 1 - firs

    # Brushwork: round the billows in the sky, down the slopes on land, level on the water.
    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    angle = np.where(water > 0.5, 0.02 * fbm(h, w, rng, base=4, octaves=2), angle)
    k = pw * ph / (348 * 365)
    s = SS
    solid = (land > 0.5).astype(np.float64)
    wet = (water > 0.5).astype(np.float64)
    air = np.clip(1 - solid - wet, 0, 1)
    sky_out = mt.paint(np.stack([oc.within(V, air, 6 * SS)] * 3, axis=2), angle, rng,
                       [(int(380 * k), (5 * s, 9 * s), (12 * s, 28 * s)), (int(1300 * k), (2.5 * s, 4.5 * s), (6 * s, 15 * s)),
                        (int(2600 * k), (1.2 * s, 2.2 * s), (3.5 * s, 8 * s)), (int(3400 * k), (0.7 * s, 1.1 * s), (3 * s, 6 * s))],
                       0.03)
    land_out = mt.paint(np.stack([oc.within(V, solid, 6 * SS)] * 3, axis=2), angle, rng,
                        [(int(500 * k), (3.5 * s, 7 * s), (5 * s, 12 * s)), (int(1600 * k), (2 * s, 3.5 * s), (4 * s, 8 * s)),
                         (int(2600 * k), (1.1 * s, 2 * s), (2.5 * s, 5 * s)), (int(3000 * k), (0.7 * s, 1.0 * s), (2 * s, 4 * s))],
                        0.04)
    water_out = mt.paint(np.stack([oc.within(V, wet, 4 * SS)] * 3, axis=2), angle, rng,
                         [(int(900 * k), (1.6 * s, 2.6 * s), (4 * s, 10 * s)), (int(2600 * k), (0.8 * s, 1.3 * s), (3 * s, 7 * s)),
                          (int(3000 * k), (0.6 * s, 0.9 * s), (2 * s, 5 * s))], 0.03)
    out = (sky_out[..., 0] * air + land_out[..., 0] * solid + water_out[..., 0] * wet) / np.maximum(air + solid + wet, 1e-6)
    out = gaussian_filter(out, 0.4 * s)
    out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(keep, 0.5 * s) * 0.85
    out = out + (np.minimum(out, V) - out) * gaussian_filter(np.maximum(firs, small_firs), 0.5 * s) * 0.7
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.05 * s
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * 1.28, 0, 1) ** 1.06
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.8, 0.98, out) * air * 0.8), 0, 1)
    return down(out, SS), down(glow, SS)


def preview_painting(folder, name, value, glow):
    """Day glaze: chocolate shadow, warm umber, cream light, golden glow."""
    h, w = value.shape
    c0, c1, c2, gl = hexrgb(0x2A1A0C), hexrgb(0x8C6A3E), hexrgb(0xF0DDB0), hexrgb(0xF5D088)
    lo = np.clip(value * 2, 0, 1)[..., None]
    hi = np.clip(value * 2 - 1, 0, 1)[..., None]
    rgb = c0 * (1 - lo) + c1 * lo
    rgb = rgb * (1 - hi) + c2 * hi
    rgb = rgb * (1 - 0.6 * glow[..., None]) + gl * 0.6 * glow[..., None]
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC).save(
        os.path.join(folder, f"pv-painting-{name}.png"))


# MARK: The wall, the brass and the card

def damask_motif(tw, th, k):
    """One repeat of a silk damask (tw x th px at k times): a pointed ogee medallion holding a pomegranate on a
    leafy stem, mirrored about the repeat's centre line, with a small four-petal flower between the medallions.
    Returns a 0..1 mask of the satin figure."""
    img = Image.new("L", (tw * k, th * k), 0)
    d = ImageDraw.Draw(img)
    W, H = tw * k, th * k
    cx = W / 2

    def poly(pts, fill=255):
        d.polygon([(x * W, y * H) for x, y in pts], fill=fill)

    def ell(x, y, rx, ry, fill=255):
        d.ellipse([(x - rx) * W, (y - ry) * H, (x + rx) * W, (y + ry) * H], fill=fill)

    # The ogee medallion's outline: a band between two pointed ovals.
    n = 120
    outer, inner = [], []
    for i in range(n + 1):
        v = i / n
        half = 0.44 * np.sin(np.pi * v) ** 0.75 * (1 - 0.18 * np.sin(2 * np.pi * v))
        outer.append((0.5 + half, 0.04 + 0.92 * v))
        half_i = max(0.0, half - 0.05)
        inner.append((0.5 + half_i, 0.06 + 0.88 * v))
    ring = outer + [(1 - x, y) for x, y in reversed(outer)]
    hole = inner + [(1 - x, y) for x, y in reversed(inner)]
    poly(ring, 255)
    poly(hole, 0)
    # The pomegranate: a round fruit with a crown, on a stem with two pairs of leaves.
    ell(0.5, 0.42, 0.13, 0.11)
    poly([(0.42, 0.33), (0.45, 0.24), (0.5, 0.3), (0.55, 0.24), (0.58, 0.33)])
    ell(0.5, 0.42, 0.06, 0.05, 0)
    ell(0.5, 0.42, 0.03, 0.025, 255)
    poly([(0.485, 0.52), (0.515, 0.52), (0.51, 0.86), (0.49, 0.86)])
    for side in (-1, 1):
        for (y, size) in ((0.6, 1.0), (0.74, 0.8)):
            pts = []
            for i in range(25):
                tt = i / 24
                x = 0.5 + side * (0.02 + 0.2 * size * tt)
                yy_ = y - 0.06 * size * np.sin(np.pi * tt) - 0.04 * tt
                pts.append((x, yy_))
            for i in range(24, -1, -1):
                tt = i / 24
                x = 0.5 + side * (0.02 + 0.2 * size * tt)
                yy_ = y + 0.02 * size * np.sin(np.pi * tt) - 0.04 * tt
                pts.append((x, yy_))
            poly(pts)
    # The small flower between the medallions (at the repeat's corners and the mid-sides, half-dropped).
    for (x, y) in ((0, 0), (1, 0), (0, 1), (1, 1), (0, 0.5), (1, 0.5)):
        for (dx, dy) in ((0.06, 0), (-0.06, 0), (0, 0.045), (0, -0.045)):
            ell(x + dx, y + dy, 0.035, 0.026)
    m = np.asarray(img, dtype=np.float64) / 255
    return m


def damask(w, h, seed, repeat=(64, 92), base=0x4C1219, scale=1.0):
    """Oxblood silk damask, evenly lit (the widgets light it): the figure woven in satin, which catches the light
    along its weave, on a matte ground; a fine weave and the slow unevenness of fabric stretched on a wall."""
    rng = np.random.default_rng(seed)
    k = 3
    tw, th = int(repeat[0] * scale), int(repeat[1] * scale)
    motif = damask_motif(tw, th, k)
    motif = down(motif, k)
    # Half-drop repeat.
    reps_x, reps_y = w // tw + 2, h // th + 3
    col = np.concatenate([motif] * reps_y, axis=0)
    cols = [np.roll(col, (i % 2) * th // 2, axis=0) for i in range(reps_x)]
    sheet = np.concatenate(cols, axis=1)[th // 3: th // 3 + h, tw // 3: tw // 3 + w]
    sheet = gaussian_filter(sheet, 0.35)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    weave = 0.5 * np.sin(yy * np.pi / 1.0) * 0.5 + 0.5 * fbm(h, w, rng, base=w / 1.5, octaves=1, stretch=6.0)
    stretch = fbm(h, w, rng, base=3, octaves=3, persistence=0.5)
    satin = 0.075 * sheet * (0.8 + 0.2 * fbm(h, w, rng, base=w / 4, octaves=2, stretch=8.0))
    v = 1.0 + satin + 0.012 * weave + 0.03 * stretch - 0.02 * (1 - sheet) * fbm(h, w, rng, base=w / 8, octaves=2)
    rgb = hexrgb(base)[None, None, :] * v[..., None]
    # The satin figure is a touch warmer and redder than the ground.
    rgb = mix(rgb, rgb * hexrgb(0xFFE4D8) * 1.08, 0.5 * sheet)
    return np.clip(rgb, 0, 1)


def brass(w, h, seed):
    """Brushed brass: long level scratches over a slow, uneven sheen."""
    rng = np.random.default_rng(seed)
    streak = fbm(h, w, rng, base=w / 3, octaves=3, stretch=24.0)
    fine = fbm(h, w, rng, base=w / 1.2, octaves=1, stretch=40.0)
    sheen = fbm(h, w, rng, base=2, octaves=2)
    v = np.clip(0.64 + 0.03 * streak + 0.025 * fine + 0.035 * sheen, 0.41, 0.89)
    stops = [(0.4, 0x6E5020), (0.55, 0xA9853E), (0.65, 0xC9A35A), (0.78, 0xE6CB88), (0.9, 0xF6E7B8)]
    rgb = np.zeros(v.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        tt = np.clip((v - a0) / (a1 - a0), 0, 1)[..., None]
        sel = ((v >= a0) & (v <= a1))[..., None]
        rgb = np.where(sel, hexrgb(c0) * (1 - tt) + hexrgb(c1) * tt, rgb)
    # Tarnish: a faint brown bloom in patches.
    rgb = mix(rgb, rgb * hexrgb(0xB89870), 0.35 * smoothstep(0.6, 1.8, fbm(h, w, rng, base=4, octaves=3)))
    return np.clip(rgb, 0, 1)


def card(w, h, seed):
    """Aged ivory card: laid lines, a soft toning toward the edges and a few spots of foxing."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    laid = 0.5 + 0.5 * np.sin(xx * 2 * np.pi / 1.6)
    chain = np.exp(-((xx % 24) - 12) ** 2 / 0.8)
    fibre = fbm(h, w, rng, base=w / 3, octaves=3, persistence=0.6)
    tone = fbm(h, w, rng, base=3, octaves=3)
    edge = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) / min(w, h)
    v = 1.0 + 0.01 * laid + 0.012 * chain + 0.02 * fibre + 0.025 * tone - 0.1 * smoothstep(0.18, 0.0, edge)
    rgb = hexrgb(0xEADFC4)[None, None, :] * v[..., None]
    fox = smoothstep(2.0, 3.0, fbm(h, w, rng, base=w / 9, octaves=3))
    rgb = mix(rgb, hexrgb(0xC9A57A), 0.45 * fox)
    rgb = mix(rgb, hexrgb(0xD6C29C), 0.4 * smoothstep(0.12, 0.0, edge))
    return np.clip(rgb, 0, 1)


def wallpaper(w, h, seed):
    """The board's home screen: the same damask wall, larger and darker, in the half-dark of a gallery after hours
    (not a widget texture)."""
    rgb = damask(w, h, seed, repeat=(64, 92), base=0x3C0E14)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    vign = np.hypot((xx / w - 0.5) * 1.1, (yy / h - 0.42) * 1.0)
    rgb = mt.shade(rgb, -0.45 * smoothstep(0.25, 0.85, vign))
    return np.clip(rgb, 0, 1)


# MARK: Preview

def preview_frame(folder, name, rgba):
    h, w = rgba.shape[:2]
    bg = np.ones((h, w, 3)) * hexrgb(0x3A0E12)
    img = bg * (1 - rgba[..., 3:4]) + rgba[..., :3] * rgba[..., 3:4]
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, f"pv-{name}-1x.png"))
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC).save(
        os.path.join(folder, f"pv-{name}-3x.png"))


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]

    def want(group):
        return not only or group in only

    if want("frames"):
        for name in FRAMES:
            rgba = gilt_frame(name)
            save_rgba(name, rgba)
            if pv:
                preview_frame(pv, name, rgba)

    if want("paintings"):
        for name in PAINTINGS:
            if only and "paintings" not in only and name not in only:
                continue
            value, glow = riffelsee(name)
            save_alpha(f"painting-{name}-lo", np.clip(value * 2, 0, 1))
            save_alpha(f"painting-{name}-hi", np.clip(value * 2 - 1, 0, 1))
            save_alpha(f"painting-{name}-glow", glow)
            if pv:
                preview_painting(pv, name, value, glow)

    if want("wall"):
        save_rgb("wall", damask(348, 365, 901))
    if want("brass"):
        save_rgb("brass", brass(240, 120, 903), quality=92)
    if want("card"):
        save_rgb("card", card(330, 140, 905), quality=92)
    if want("wallpaper"):
        save_rgb("wallpaper", wallpaper(780, 805, 907), quality=88)


if __name__ == "__main__":
    main()
