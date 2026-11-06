"""The painter shared by the four California Sun Arc scenes (half-dome, whitney, big-sur, joshua-tree; each scene's
make.py imports this file by its path). It paints the large Weather canvas (348 x 365 pt) as one grey value study, the
way MockLab/Textures/weather-sun-arc/make.py paints the Matterhorn, and with the same machinery, imported from its path
and never copied or edited: Old Master's sky_field, cumulus, mountain and firs, the Cover's within(), and the stroke
passes of scripts/make_textures.py.

A Canvas is built in depth order, far to near:

    sky and cumulus  ->  layers of land (ridges, the traced subject, trees, boulders, water)  ->  strokes

Every layer is land: it is written into the front mask, so the gilt arc's feet and the setting sun pass behind it.
Strokes follow each layer's own direction field: round the billows in the sky, down the fall line on rock, level on
water, round each boulder, up the trunks.

Written per scene (1 px per point, alpha only, as the Sun Arc widget reads them):
    large-lo.png, large-hi.png   the lower and upper half of the value (glazed at run time with CoverLight)
    large-glow.png               the brightest lights (lit cloud, lit rock), glazed in the colour of the sun
    large-front.png              the land, drawn again over the arc and the sun
"""
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True  # importing the Sun Arc make.py (and through it the Cover, Old Master, scripts/)

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
SA_DIR = os.path.dirname(os.path.dirname(HERE))  # MockLab/Textures/weather-sun-arc
_spec = importlib.util.spec_from_file_location("sa_make", os.path.join(SA_DIR, "make.py"))
sa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sa)
oc, om, mt, SS = sa.oc, sa.om, sa.mt, sa.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix

W, H = 348, 365  # the large Weather canvas, in points


# MARK: Files

def save_alpha(folder, name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(folder, name + ".png"),
                                                                              optimize=True)
    print(f"{os.path.basename(folder)}/{name}.png: {a.shape[1]}x{a.shape[0]}")


def write(folder, value, glow, land, name="large"):
    save_alpha(folder, name + "-lo", np.clip(value * 2, 0, 1))
    save_alpha(folder, name + "-hi", np.clip(value * 2 - 1, 0, 1))
    save_alpha(folder, name + "-glow", glow)
    save_alpha(folder, name + "-front", land)


def load(path):
    with open(path) as f:
        return json.load(f)


def preview(path, value, glow, arc, night=False):
    """A quick colour composite (day or night palette) with the arc drawn on, for checking without Swift."""
    h, w = value.shape
    c0, c1, c2 = (hexrgb(0x24170F), hexrgb(0xEEDDC2), hexrgb(0xF6CF98)) if not night else \
        (hexrgb(0x0E0A08), hexrgb(0x8C8274), hexrgb(0xC9BFA8))
    rgb = mix(np.ones(value.shape + (3,)) * c0, np.ones(value.shape + (3,)) * c1, value)
    rgb = mix(rgb, np.ones(value.shape + (3,)) * c2, glow * 0.6)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC)
    cx, hz, rx, ry = arc
    d = ImageDraw.Draw(img)
    pts = [((cx * w + rx * w * np.cos(np.pi * (1 - t))) * 3, (hz * h - ry * h * np.sin(np.pi * (1 - t))) * 3)
           for t in np.linspace(0, 1, 200)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        if i < 66 or (i // 3) % 2 == 0:
            d.line([a, b], fill=(236, 196, 138), width=3)
    img.save(path)


# MARK: Geometry (all in canvas pixels at SS times the point size)

def crest(xs, ys, w, h, sx, sy, unit):
    """A traced line as a crest: the point (0, 0) of the trace at (sx, sy) (fractions of the canvas) and one trace
    unit `unit` px, at one scale across and down (never stretched). Past the traced ends the line runs on level."""
    u = ((np.arange(w) + 0.5) - sx * w) / unit
    return sy * h + np.interp(u, np.asarray(xs), np.asarray(ys)) * unit


def place(points, w, h, sx, sy, unit):
    """Trace points (units) to canvas pixels, with the same placement as crest()."""
    p = np.asarray(points, dtype=np.float64)
    return np.stack([sx * w + p[:, 0] * unit, sy * h + p[:, 1] * unit], axis=1)


def polygon(points, w, h, k=2):
    """A soft-edged 0..1 mask of a polygon (canvas pixels), drawn at k times and reduced."""
    img = Image.new("L", (w * k, h * k), 0)
    ImageDraw.Draw(img).polygon([(x * k, y * k) for x, y in points], fill=255)
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


def below(cy, h, soft=0.8):
    """Coverage of everything under a crest line."""
    yy = np.arange(h, dtype=np.float64)[:, None]
    return smoothstep(-soft * SS, soft * SS, yy - cy[None, :])


def line_x(points, h):
    """A near-vertical line given as (x, y) points (canvas px): its x for every row (level past its ends)."""
    p = np.asarray(points, dtype=np.float64)
    order = np.argsort(p[:, 1])
    return np.interp(np.arange(h) + 0.5, p[order, 1], p[order, 0])


def line_y(points, w):
    """A line given as (x, y) points (canvas px): its y for every column (level past its ends)."""
    p = np.asarray(points, dtype=np.float64)
    order = np.argsort(p[:, 0])
    return np.interp(np.arange(w) + 0.5, p[order, 0], p[order, 1])


def rle_mask(data, w, h, x0, y0, height):
    """A silhouette stored as run-length rows (see the joshua-tree trace) placed with its top-left at (x0, y0) px and
    scaled uniformly to `height` px; returns a soft 0..1 mask on a w x h canvas."""
    sw, sh = data["w"], data["h"]
    m = np.zeros((sh, sw), dtype=np.uint8)
    for r, runs in enumerate(data["rows"]):
        for a, n in zip(runs[0::2], runs[1::2]):
            m[r, a:a + n] = 255
    s = height / sh
    tw, th = max(1, int(round(sw * s * 2))), max(1, int(round(sh * s * 2)))
    img = Image.fromarray(m).resize((tw, th), Image.LANCZOS)
    canvas = Image.new("L", (w * 2, h * 2), 0)
    canvas.paste(img, (int(round(x0 * 2)), int(round(y0 * 2))))
    return np.asarray(canvas.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


# MARK: The canvas

class Canvas:
    def __init__(self, seed, w=W, h=H):
        self.pw, self.ph = w, h
        self.w, self.h = w * SS, h * SS
        self.rng = np.random.default_rng(seed)
        self.yy, self.xx = np.mgrid[0:self.h, 0:self.w].astype(np.float64)
        z = lambda: np.zeros((self.h, self.w))
        self.V, self.glow, self.land, self.keep, self.tree, self.ground = z(), z(), z(), z(), z(), z()
        self.ang = np.full((self.h, self.w), np.pi / 2)
        self.angle = None
        self.front = None  # the front mask, when some layer stands only partly in front (see add's `front`)

    def fbm(self, **kw):
        return fbm(self.h, self.w, self.rng, **kw)

    def sky(self, sun, horizon, clouds=(), calm=None, **kw):
        """Old Master's open sky and cumulus (dark banks first), with a calm passage where the arc runs."""
        V, angle = om.sky_field(self.w, self.h, self.rng, sun, horizon, **kw)
        if calm is not None:
            cx, cy, rx, ry, amount = calm
            d = np.hypot((self.xx / self.w - cx) / rx, (self.yy / self.h - cy) / ry)
            V = V + (gaussian_filter(V, 6 * SS) - V) * amount * smoothstep(1.15, 0.7, d)
        for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
            if not layer:
                continue
            cv, ccover, clit, ctan, _ = om.cumulus(self.w, self.h, self.rng, layer, sun)
            V = V + (cv - V) * ccover
            self.glow = self.glow * (1 - ccover) + clit * 0.9
            angle = np.where(ccover > 0.3, ctan, angle)
        self.V, self.angle, self.sun = V, angle, sun

    def add(self, v, cover, lit=None, lean=None, angle=None, keep=None, tree=False, ground=False, front=None):
        """One layer of land in front of everything before it. lean: Old Master's face lean (strokes down the fall
        line); angle: an explicit stroke direction field instead; keep: lines laid back crisp over the strokes;
        front: how far (0..1, a number or a field) the layer is drawn again in front of the arc and the sun (a
        hazed far range at less than 1 lets the arc read across it). Without it every layer is fully in front."""
        if front is not None and self.front is None:
            self.front = self.land.copy()
        if self.front is not None:
            fa = 1.0 if front is None else front
            self.front = self.front * (1 - cover) + cover * fa
        self.V = self.V + (v - self.V) * cover
        self.glow = self.glow * (1 - cover) + (0 if lit is None else lit * cover)
        self.land = np.maximum(self.land, cover)
        if angle is None:
            angle = np.pi / 2 + 0.95 * np.clip(0 if lean is None else lean, -1, 1) \
                + 0.15 * fbm(self.h, self.w, self.rng, base=6, octaves=2)
        self.ang = np.where(cover > 0.5, angle, self.ang)
        self.keep = self.keep * (1 - cover) + (0 if keep is None else keep * cover)
        self.tree = np.maximum(self.tree * (1 - cover), cover if tree else 0)
        self.ground = self.ground * (1 - cover) + (cover if ground else 0)

    def range(self, cy, tone, light, **kw):
        """Old Master's mountain() on a crest line (y px per column)."""
        v, cover, lit, nx = om.mountain(self.w, self.h, self.rng, cy, tone, light, **kw)
        self.add(v, cover, lit=lit, lean=nx)
        return cover

    def firs(self, cy, height, spacing, coverage, tone, rim=0.1):
        """Old Master's firs standing on a crest line, rim-lit on the side toward the open sky."""
        m = om.firs(self.w, self.h, self.rng, cy, height, spacing, coverage)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        v = tone + 0.012 * fbm(self.h, self.w, self.rng, base=10, octaves=3, stretch=0.4) + rim * rimlight
        self.add(v, m, angle=np.full((self.h, self.w), np.pi / 2), tree=True)
        return m

    def finish(self, contrast=1.3, ground_dark=(0.62, 1.0, 0.4)):
        """Darkens the near ground toward the bottom, lays the strokes and filters down to 1 px per point.
        Returns value, glow and land (the front mask), each 0..1 at the point size."""
        w, h, rng, s = self.w, self.h, self.rng, SS
        g0, g1, amount = ground_dark
        V = self.V * (1 - amount * smoothstep(g0 * h, g1 * h, self.yy) * self.land)
        land = self.land
        angle = np.where(land > 0.5, self.ang, self.angle)
        k = self.pw * self.ph / (348 * 365)
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
        out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(self.keep, 0.5 * s) * 0.85
        out = out + (np.minimum(out, V) - out) * gaussian_filter(self.tree, 0.5 * s) * 0.7
        out = out + (np.minimum(out, V + 0.04) - out) * gaussian_filter(self.ground, 0.5 * s)
        out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
        g = gaussian_filter(out, 0.7 * s)
        out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
        out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
        out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
        glow = gaussian_filter(self.glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
        glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
        land = gaussian_filter(land if self.front is None else self.front, 0.35 * s)
        return om.down(out), om.down(glow), om.down(land)


# MARK: Painters shared by more than one scene

def boulders(c, top, x0, x1, rng, size, tone, light=(-0.5, -0.65, 0.6), contrast=1.0, lit_amount=0.6, depth=None,
             grow=1.0, rim=0.0, cracks=0.0):
    """A pile of rounded granite boulders (the monzogranite of the Alabama Hills and Joshua Tree) heaped under `top`
    (y px per column) between x0 and x1 (px): stones packed in rows on a jittered grid, the crowns of the top row
    standing on the line, the rows behind drawn first; each a rounded, slightly squarish dome lit from `light`, its
    lower part and its joints in shadow, the deeper rows of the pile darker. size: (min, max) radius in px at the
    top of the pile, growing by `grow` times toward its foot; depth: how far down (px) the pile runs (default: to
    the bottom); cracks: how strongly to cut a few fractures across the stones and keep their lit crowns crisp
    (drawn from their own seed, so nothing else in the painting moves). Returns value, cover, lit, stroke angle and
    the joints to keep crisp."""
    w, h = c.w, c.h
    yy, xx = c.yy, c.xx
    lx, ly, lz = om.norm3(*light)
    value = np.zeros((h, w))
    lit = np.zeros((h, w))
    cover = np.zeros((h, w))
    angle = np.full((h, w), np.pi / 2)
    outline = np.zeros((h, w))
    span = h if depth is None else depth
    stones = []
    # Rows from the top of the pile down, each row's stones on a jittered stagger.
    t = 0.0
    row = 0
    while t < 1.0:
        f = 1 + (grow - 1) * t
        r0 = size[0] * f
        r1 = size[1] * f
        step = (r0 + r1) * 0.9
        x = x0 - r1 + (row % 2) * step * 0.5 + rng.uniform(0, step * 0.4)
        while x < x1 + r1:
            r = rng.uniform(r0, r1)
            col = int(np.clip(x, 0, w - 1))
            y = top[col] + r * rng.uniform(0.75, 1.0) + t * span + rng.uniform(-0.25, 0.25) * r * (row > 0)
            stones.append((x + rng.uniform(-0.2, 0.2) * r, y, r, t))
            x += step * rng.uniform(0.75, 1.15)
        t += (r0 + r1) * 0.6 / span
        row += 1
    stones.sort(key=lambda s: s[1])
    crng = np.random.default_rng(int(abs(top[w // 2])) + 7) if cracks else None
    for bx, by, r, t in stones:
        if by - r > h:
            continue
        ry = r * rng.uniform(0.68, 0.92)
        rot = rng.uniform(-0.45, 0.45)
        sq = rng.uniform(2.4, 3.6)                     # rounded but a little squarish, as weathered granite is
        X0, X1 = int(max(0, bx - r * 1.3)), int(min(w, bx + r * 1.3))
        Y0, Y1 = int(max(0, by - r * 1.3)), int(min(h, by + r * 1.3))
        if X1 <= X0 or Y1 <= Y0:
            continue
        dx, dy = xx[Y0:Y1, X0:X1] - bx, yy[Y0:Y1, X0:X1] - by
        u = (dx * np.cos(rot) + dy * np.sin(rot)) / r
        v = (-dx * np.sin(rot) + dy * np.cos(rot)) / ry
        rr = (np.abs(u) ** sq + np.abs(v) ** sq) ** (1 / sq)
        inside = smoothstep(1.0, 0.93, rr)
        z = np.sqrt(np.clip(1 - np.minimum(rr, 1) ** 2, 0, 1))
        nx, ny, nz = om.norm3(u, v, z * 0.9 + 0.2)
        lam = np.clip(nx * lx + ny * ly + nz * lz, -1, 1)
        shade = smoothstep(0.3, 0.7, 0.5 + 0.5 * lam) * 0.8 + 0.2 * np.clip(0.5 + 0.5 * lam, 0, 1)  # planes, not puffs
        joint = smoothstep(0.8, 1.0, rr) * smoothstep(-0.3, 0.6, v)        # the stone darkens into its lower joint
        deep = 1 - 0.35 * t                                                # the depths of the pile are darker
        val = tone * deep * (1 - 0.7 * contrast + 1.4 * contrast * shade) * (1 - 0.5 * joint)
        # The crown: a bright edge where the stone's rim turns to the light (an old master's touch of light).
        towards = np.clip((u * lx + v * ly) / np.maximum(np.hypot(u, v), 1e-6), 0, 1)
        crown = smoothstep(0.72, 0.9, rr) * smoothstep(1.0, 0.9, rr) * smoothstep(0.35, 0.85, towards)
        val = val + (min(1.0, tone * 2.4) - val) * crown * rim * deep
        val = val * (1 + 0.06 * rng.uniform(-1, 1))
        crack = np.zeros_like(rr)
        if cracks:
            for _ in range(int(crng.integers(0, 3))):                      # a fracture or two across the stone
                a = np.pi / 2 + crng.uniform(-0.9, 0.9)
                off = crng.uniform(-0.5, 0.5) * r
                dist = np.abs(dx * np.sin(a) - dy * np.cos(a) - off)
                crack = np.maximum(crack, smoothstep(0.45 * SS, 0.1 * SS, dist) * smoothstep(0.95, 0.75, rr))
            val = val * (1 - 0.55 * cracks * crack)
        sub = (slice(Y0, Y1), slice(X0, X1))
        value[sub] = value[sub] * (1 - inside) + val * inside
        lit[sub] = lit[sub] * (1 - inside) + (smoothstep(0.7, 0.95, shade) + crown * rim) * inside * lit_amount * deep
        angle[sub] = np.where(inside > 0.5, np.arctan2(v, u) + np.pi / 2 + rot, angle[sub])
        cover[sub] = np.maximum(cover[sub], inside)
        edge = smoothstep(0.86, 0.97, rr) * smoothstep(1.0, 0.97, rr)
        if cracks:
            edge = np.maximum(edge, cracks * np.maximum(crack, crown))
        outline[sub] = np.maximum(outline[sub] * inside, edge)
    # The joints between the stones: deep shadow, so the pile reads as stones and not as a wall.
    fill = below(top + size[1] * 0.5, h) * smoothstep(x0 - 2 * SS, x0 + 2 * SS, xx) * smoothstep(x1 + 2 * SS, x1 - 2 * SS, xx)
    if depth is not None:
        fill = fill * smoothstep(top[None, :] + depth + 2 * size[1], top[None, :] + depth, yy)
    # The heap is modelled as one mass first (Old Master's range on its skyline, lit from the same side), and the
    # stones only modulate it: each a little lighter on its lit side, the joints between them dark. So it reads as
    # a pile of boulders, not as a froth of separately lit balls.
    mass = om.mountain(w, h, c.rng, gaussian_filter(top, 4 * SS), tone, light, gully=0.2, contrast=0.9)[0]
    stone = np.where(cover > 0.01, value / np.maximum(tone, 1e-6), 1.0)
    value = mass * (0.7 + 0.3 * np.clip(stone, 0, 2)) * (1 - 0.65 * outline)
    value = value * cover + mass * 0.45 * (1 - cover)
    cover = np.maximum(cover, fill)
    grain = 0.04 * fbm(h, w, rng, base=60, octaves=3)
    value = np.clip(value * (1 + grain), 0, 1)
    return value, cover, lit, angle, outline


def water(c, horizon_y, near_tone, far_tone, rng, glitter_x=None, glitter=0.0):
    """Open water below a level horizon (y px): lighter toward the horizon where it mirrors the sky, darker toward
    the viewer, worked in long level strokes with broken swells; an optional path of glitter under the light at
    glitter_x (px). Returns value, cover, lit, angle."""
    w, h = c.w, c.h
    yy, xx = c.yy, c.xx
    cover = smoothstep(-0.6 * SS, 0.6 * SS, yy - horizon_y)
    depth = np.clip((yy - horizon_y) / (h - horizon_y), 0, 1)
    v = far_tone + (near_tone - far_tone) * depth ** 0.55
    swell = fbm(h, w, rng, base=6, octaves=4, persistence=0.6, stretch=9.0)
    fine = fbm(h, w, rng, base=30, octaves=3, stretch=7.0)
    v = v + (0.035 * swell + 0.02 * fine) * (1 - 0.5 * depth)
    lit = np.zeros((h, w))
    if glitter_x is not None and glitter:
        spread = (0.08 + 0.25 * depth) * w
        path = np.exp(-((xx - glitter_x) / spread) ** 2) * (1 - depth) ** 1.5
        sparks = smoothstep(0.9, 1.9, fine + 0.6 * swell)
        lit = glitter * path * sparks
        v = v + 0.25 * lit
    angle = 0.02 * fbm(h, w, rng, base=3, octaves=2)
    return np.clip(v, 0, 1), cover, lit * cover, angle
