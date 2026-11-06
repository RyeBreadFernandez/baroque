"""Shared painter for the Sun Arc world scenes (fuji, glencoe, dolomites, tuscany): the Sun Arc canvas's own
machinery, generalised so a scene's subject is any stack of painted layers.

This module lives in scenes/fuji/ and is imported by path from each of those four scenes' make.py (it is not a
scene of its own). It imports, by path and without editing them:
  weather-sun-arc/make.py      the Sun Arc canvas (and through it old-master-cover/make.py, old-master/make.py and
                               scripts/make_textures.py: sky_field, cumulus, mountain, crest, firs, the stroke painter)

What it adds:
  Skyline              a traced skyline (a scene's <name>.json): normalised from a photograph's trace, then placed
                       on a canvas at one scale (never stretched)
  compose()            arc_painting() with pluggable layers: sky and cumulus, then each layer far to near, each
                       returning its value, coverage, lit snow, stroke direction and crisp lines; then the same
                       stroke passes, filters and front mask as the Sun Arc canvas
  water_layer(), cypress_shape(), streaks(), lambert(), ...   small painters the scenes use
  write(), preview()   the four alpha PNGs, and a day-palette preview with the arc and the type boxes drawn on

All painting is at SS (2) times the widget's size and filtered to 1 px per point, as in the Sun Arc canvas.
"""
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True  # importing the Sun Arc make.py (and through it the Cover's, Old Master's, scripts/)

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
SCENES = os.path.dirname(HERE)
SUN_ARC = os.path.dirname(SCENES)
_spec = importlib.util.spec_from_file_location("sa_make", os.path.join(SUN_ARC, "make.py"))
sa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sa)
oc, om, mt, SS = sa.oc, sa.om, sa.mt, sa.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix

W, H = 348, 365                      # the large Weather canvas, points
ARC = (0.5, 0.575, 0.42, 0.45)       # the Matterhorn's arc; a scene may move it (scene.json)


# MARK: Skylines traced from photographs

def skyline_from_trace(trace_path, out_path, meta, step=2, unit=None, top=None, lines=None):
    """Normalises a full trace ({"width", "height", "x0", "y": [row for every column from x0]}, photo px) and writes
    the scene's skyline JSON: the summit (the highest point, or `top` = column) at (0, 0), x right and y down, in
    units of `unit` photo px (default: the drop from the summit to the trace's lowest point), kept every `step`
    columns. lines: {name: [[x, y], ...] in photo px}, other lines on the same photograph (drawn by eye, or traced
    like the skyline), stored in the same units."""
    with open(trace_path) as f:
        t = json.load(f)
    y = np.asarray(t["y"], dtype=np.float64)
    x0 = int(t["x0"])
    i = int(np.argmin(y)) if top is None else int(top) - x0
    sx, sy = x0 + i, float(y[i])
    unit = float(unit or (y.max() - sy))
    cols = sorted(set(range(0, len(y), step)) | {i, len(y) - 1})
    data = dict(meta)
    data["trace"] = {"photo_px": [int(t["width"]), int(t["height"])], "summit": [sx, round(sy, 1)],
                     "unit_px": round(unit, 2), "columns": [x0, x0 + len(y) - 1], "step": step}
    data["units"] = "summit at (0, 0), x right and y down, in units of trace.unit_px photo px"
    data["x"] = [round((x0 + c - sx) / unit, 5) for c in cols]
    data["y"] = [round(float(y[c] - sy) / unit, 5) for c in cols]
    if lines:
        data["lines"] = {k: [[round((px - sx) / unit, 5), round((py - sy) / unit, 5)] for px, py in v]
                         for k, v in lines.items()}
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    print(f"{os.path.basename(out_path)}: {len(cols)} points, unit {unit:.1f} px of {t['width']}")


class Skyline:
    """A stored skyline, placed on a canvas: the summit at (sx, sy) (fractions) and one unit `size` points tall,
    at one scale across and down."""

    def __init__(self, path):
        with open(path) as f:
            self.data = json.load(f)
        self.x = np.asarray(self.data["x"])
        self.y = np.asarray(self.data["y"])

    def crest(self, w, h, sx, sy, size, ends="level"):
        """y (px) of the skyline for every column of a w x h px canvas, `size` px to the unit. Past the traced ends
        the line runs on level (ends="level") or on at its end slope (ends="slope")."""
        u = ((np.arange(w) + 0.5) - sx * w) / size
        y = np.interp(u, self.x, self.y)
        if ends == "slope":
            k = 8
            sl = (self.y[k] - self.y[0]) / (self.x[k] - self.x[0])
            sr = (self.y[-1] - self.y[-1 - k]) / (self.x[-1] - self.x[-1 - k])
            y = np.where(u < self.x[0], self.y[0] + sl * (u - self.x[0]), y)
            y = np.where(u > self.x[-1], self.y[-1] + sr * (u - self.x[-1]), y)
        return sy * h + y * size

    def line(self, name, w, h, sx, sy, size):
        """Another stored line as canvas px [(x, y), ...]."""
        return [(sx * w + px * size, sy * h + py * size) for px, py in self.data["lines"][name]]


def polyline_y(points, w):
    """y for every column from a polyline [(x, y), ...] in px (level past its ends)."""
    pts = sorted(points)
    xs, ys = zip(*pts)
    return np.interp(np.arange(w) + 0.5, xs, ys)


# MARK: Small painters

def norm3(x, y, z):
    n = np.sqrt(x * x + y * y + z * z) + 1e-9
    return x / n, y / n, z / n


def lambert(nx, ny, nz, light, power=1.5):
    lx, ly, lz = norm3(*light)
    return np.clip(0.5 + 0.5 * (nx * lx + ny * ly + nz * lz), 0, 1) ** power


def below(cy, h, soft=0.8):
    """Coverage of everything under a crest (per column y, px)."""
    yy = np.arange(h, dtype=np.float64)[:, None]
    return smoothstep(-soft * SS, soft * SS, yy - cy[None, :])


def streaks(h, w, rng, angle, length, base=60, octaves=2):
    """Noise smeared along a direction field: unit variance."""
    s = mt.lic(fbm(h, w, rng, base=base, octaves=octaves), angle, max(4, int(length)), step=1.0)
    return (s - s.mean()) / (s.std() + 1e-9)


def cypress_shape(x, base, height, width, rng, lean=0.0):
    """An Italian cypress: a tall closed flame, widest a third of the way up, the tip drawn out, the outline
    a little tufted. Returns polygon points (px)."""
    n = 26
    left, right = [], []
    for i in range(n + 1):
        f = i / n                                   # 0 at the base, 1 at the tip
        prof = (np.sin(np.pi * min(1.0, f * 1.45 + 0.05)) ** 0.7) * (1 - f) ** 0.55 * 1.25
        prof = min(prof, 1.0) * (0.92 + 0.16 * rng.uniform())
        hw = width / 2 * prof
        y = base - f * height
        cx = x + lean * f * height
        left.append((cx - hw * rng.uniform(0.9, 1.05), y))
        right.append((cx + hw * rng.uniform(0.9, 1.05), y))
    trunk = [(x + width * 0.06, base + height * 0.02), (x - width * 0.06, base + height * 0.02)]
    return right + [(x + lean * height, base - height)] + list(reversed(left)) + trunk


def draw_mask(w, h, polys, k=2):
    """Polygons (px) to a soft 0..1 mask (drawn at k times, then reduced)."""
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    for poly in polys:
        d.polygon([(px * k, py * k) for px, py in poly], fill=255)
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


def water_layer(top, tone=0.07, reflect=0.0, ripple=0.03, seed_angle=0.0, fade=0.12, shore=None):
    """Still dark water from row `top` (fraction) down: level strokes, a few lighter ripple lines, and (reflect > 0)
    the painting above flipped about the shore line, broken by ripples, darkened and fading fast so the type below
    stays on dark water. shore: per-column shoreline y (px) or None (level at `top`)."""
    def layer(ctx):
        w, h, rng, V = ctx["w"], ctx["h"], ctx["rng"], ctx["V"]
        yy, xx = ctx["yy"], ctx["xx"]
        line = np.full(w, top * h) if shore is None else shore
        cover = below(line, h, 0.6)
        depth = np.clip(yy - line[None, :], 0, None)
        rip = fbm(h, w, rng, base=6, octaves=4, stretch=8.0)
        glint = smoothstep(1.4, 2.6, fbm(h, w, rng, base=14, octaves=3, stretch=10.0)) * np.exp(-depth / (0.2 * h))
        v = tone + ripple * rip + 0.12 * glint - 0.03 * smoothstep(0, 0.3 * h, depth)
        if reflect:
            # the land above, flipped about the shore and broken by ripples, darkened and fading fast
            src = np.clip(2 * line[None, :] - yy + 3 * SS * fbm(h, w, rng, base=30, octaves=2, stretch=6.0), 0, h - 1)
            rv = map_coordinates(V, [src, xx], order=1, mode="nearest")
            k = np.exp(-depth / (fade * h))
            v = v + (np.clip(rv * 0.55, 0, 1) - v) * reflect * k
        angle = seed_angle + 0.04 * fbm(h, w, rng, base=3, octaves=2)
        return dict(value=np.clip(v, 0, 1), cover=cover, angle=angle, ground=True)
    return layer


# MARK: The canvas

def compose(w, h, seed, sun, horizon, clouds, layers, sky=None, calm=None, contrast=1.3,
            ground_dark=(0.61, 0.95, 0.45), sky_post=None):
    """A value study at SS times the widget's size, painted and filtered to 1 px per point: the Sun Arc canvas's
    arc_painting() with its subject made of layers. Each layer is a function ctx -> dict:
        value, cover        the layer's value and coverage (0..1) at SS
        glow                lit snow or other brightest lights (optional)
        lean                stroke lean on land, -1..1 (strokes run down the fall line, leaning with it), or
        angle               the stroke direction itself (radians), for water and fields
        keep                lines to lay back crisp over the strokes (optional)
        crest               the layer's crest (per column y), for later layers (optional)
        tree                True for trees (their drawing is laid back, their glow removed)
        ground              True for the near ground (it keeps its darkness)
    ctx: w, h (px at SS), rng, V (the value so far), yy, xx, crests (of the layers so far), sun, land.
    sky_post(ctx, V) -> V: an optional pass over the sky before the land (e.g. a far haze band).
    Returns value, glow, land (0..1), at 1 px per point."""
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
    for group in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
        if not group:
            continue
        cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, group, sun)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit * 0.9
        angle = np.where(ccover > 0.3, ctan, angle)
    ctx = dict(w=w, h=h, rng=rng, yy=yy, xx=xx, sun=sun, crests=[], V=V)
    if sky_post is not None:
        V = sky_post(ctx, V)

    land = np.zeros((h, w))
    lean = np.zeros((h, w))
    own = np.full((h, w), np.nan)        # stroke directions a layer sets itself
    keep = np.zeros((h, w))
    tree_mask = np.zeros((h, w))
    ground = np.zeros((h, w))
    for layer in layers:
        ctx["V"], ctx["land"] = V, land
        out = layer(ctx)
        cover = out["cover"]
        V = V + (out["value"] - V) * cover
        glow = glow * (1 - cover) + (out["glow"] * cover if "glow" in out else 0)
        if out.get("tree"):
            glow *= 1 - cover
            tree_mask = np.maximum(tree_mask, cover)
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + out.get("lean", 0.0) * cover
        if "angle" in out:
            own = np.where(cover > 0.5, out["angle"], own)
        else:
            own = np.where(cover > 0.5, np.nan, own)
        keep = np.maximum(keep * (1 - cover), out.get("keep", 0.0))
        ground = np.maximum(ground * (1 - cover), cover if out.get("ground") else 0.0)
        ctx["crests"].append(out.get("crest"))
    g0, g1, amount = ground_dark
    V = V * (1 - amount * smoothstep(g0 * h, g1 * h, yy) * land)

    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    land_angle = np.where(np.isnan(own), land_angle, own)
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


# MARK: Output

def save_alpha(folder, name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(folder, name + ".png"),
                                                                              optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def write(folder, name, value, glow, land):
    save_alpha(folder, name + "-lo", np.clip(value * 2, 0, 1))
    save_alpha(folder, name + "-hi", np.clip(value * 2 - 1, 0, 1))
    save_alpha(folder, name + "-glow", glow)
    save_alpha(folder, name + "-front", land)


def write_arc(folder, arc):
    """scene.json: the large canvas's arc, when it differs from the Matterhorn's."""
    path = os.path.join(folder, "scene.json")
    if tuple(arc) == ARC:
        if os.path.exists(path):
            os.remove(path)
        return
    with open(path, "w") as f:
        json.dump({"large": list(arc)}, f)
        f.write("\n")
    print("scene.json:", list(arc))


# The large layout's type (points), for previews: the month, the sun times at the arc's feet, the temperature and
# the notes beside it (SAWeatherLarge).
TYPE_BOXES = [(16, 15, 112, 29), (20, 213, 92, 230), (256, 213, 328, 230), (16, 255, 168, 338), (180, 266, 330, 342)]


def preview(path, value, glow, land, arc=ARC, boxes=True, scale=3):
    """Day-palette composite with the arc drawn on (solid to a third, dashed after) and the type boxes outlined."""
    h, w = value.shape
    c0, c1, c2 = hexrgb(0x24170F), hexrgb(0xEEDDC2), hexrgb(0xF6CF98)
    rgb = mix(np.ones(value.shape + (3,)) * c0, np.ones(value.shape + (3,)) * c1, value)
    rgb = mix(rgb, np.ones(value.shape + (3,)) * c2, glow * 0.6)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((w * scale, h * scale), Image.BICUBIC)
    d = ImageDraw.Draw(img)
    cx, hz, rx, ry = arc
    pts = [((cx * w + rx * w * np.cos(np.pi * (1 - t))) * scale, (hz * h - ry * h * np.sin(np.pi * (1 - t))) * scale)
           for t in np.linspace(0, 1, 200)]
    front = Image.fromarray((np.clip(land, 0, 1) * 255).astype(np.uint8)).resize((w * scale, h * scale), Image.BICUBIC)
    arc_img = Image.new("L", img.size, 0)
    da = ImageDraw.Draw(arc_img)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        if i < 66 or (i // 3) % 2 == 0:
            da.line([a, b], fill=255, width=scale)
    arc_a = np.asarray(arc_img, dtype=np.float64) / 255 * (1 - np.asarray(front, dtype=np.float64) / 255)
    arr = np.asarray(img, dtype=np.float64)
    arr = arr * (1 - arc_a[..., None]) + np.array([236, 196, 138]) * arc_a[..., None]
    img = Image.fromarray(arr.astype(np.uint8))
    if boxes:
        d = ImageDraw.Draw(img)
        for x0, y0, x1, y1 in TYPE_BOXES:
            d.rectangle([x0 * scale, y0 * scale, x1 * scale, y1 * scale], outline=(255, 90, 60), width=1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main(folder, large, arc=ARC, trace=None):
    """A scene's command line: no arguments paints the large canvas into `folder` (and scene.json if the arc moves);
    --preview <png> also writes a preview; --trace runs the scene's `trace` function (rebuilds its skyline JSON from
    a full trace kept outside the repo)."""
    if "--trace" in sys.argv:
        trace(*sys.argv[sys.argv.index("--trace") + 1:])
        return
    value, glow, land = large()
    write(folder, "large", value, glow, land)
    write_arc(folder, arc)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], value, glow, land, arc)
