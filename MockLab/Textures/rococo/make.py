#!/usr/bin/env python3
"""Rococo: Baroque's travertine set repainted to sit on Hubert Robert's The Bathing Pool (1777-80, The Metropolitan
Museum of Art, open access, public domain), the user's wallpaper of 2026-11-04, with two more paintings the user sent
that evening: Fragonard's The Swing (1767, the Wallace Collection, public domain) and a flower still life in a glass
(the user's image; artist not identified here).

  bathing-pool.jpg  the painting without the scan's frame edge
  wallpaper.jpg     the phone's wallpaper: The Bathing Pool cropped to the screen, the rotunda left of centre
  the-swing.jpg, flowers.jpg   the other two paintings as sent
  wallpaper-swing.jpg    The Swing cropped to the screen round the girl on the swing
  wallpaper-flowers.jpg  the still life at its full width, its dark ground carried up the screen above the bouquet
  <stone>.jpg       900x900 the travertine set's stones (same names), laid in with oil strokes in the painting's
                    colours: weathered limestone from the pedestals and steps, the foliage greens, the teal of the
                    sky, the terracotta of the flower pots, the umber of the grove
  wall.jpg          1232x1300 the showcase's backdrop: pale painted plaster

Sources: source/the-bathing-pool.jpg (the Met's image), source/the-swing.jpg, source/flowers.jpg (as the user sent
them). Run (deterministic, no network):
    python3 MockLab/Textures/rococo/make.py [names...]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location("mt", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

EDGE = 26                 # the scan's black and gilt edge, in source pixels
PHONE = 402 / 874         # the screen's width over its height
CENTRE = 0.41             # the wallpaper's centre across the painting

# Stone: the four colours of mt.panel (two grounds, a light, a weathering), sampled from the painting and lifted
# a little, since a tile is seen small.
STONES = {
    "travertine": (0xBFAE8B, 0xA8956F, 0xD3C29C, 0x9C9E80),   # the lit limestone of the pedestals
    "olive": (0x5E6B45, 0x4A5636, 0x6F7B4E, 0x7D8A58),        # sunlit foliage
    "moss": (0x4E5A3E, 0x3C4630, 0x5D6646, 0x6A6B47),         # the grove in shade
    "verde": (0x7C9592, 0x627C79, 0x91A8A2, 0x8E9C8E),        # the sky between the clouds
    "terracotta": (0xA45C40, 0x864733, 0xB86C4C, 0x9A6040),   # the flower pots
    "umber": (0x4C4333, 0x393226, 0x5A5139, 0x434634),        # the dark of the trees
    "tan": (0xB08B60, 0x977550, 0xC29F72, 0xA28A5F),          # the ochre of the steps in sun
}


def source():
    im = Image.open(os.path.join(HERE, "source", "the-bathing-pool.jpg")).convert("RGB")
    return im.crop((EDGE, EDGE, im.width - EDGE, im.height - EDGE))


def painting():
    source().save(os.path.join(HERE, "bathing-pool.jpg"), quality=92, subsampling=0)
    print("bathing-pool.jpg")


def wallpaper():
    im = source()
    w = round(im.height * PHONE)
    x0 = min(max(0, round(CENTRE * im.width - w / 2)), im.width - w)
    im.crop((x0, 0, x0 + w, im.height)).save(os.path.join(HERE, "wallpaper.jpg"), quality=92, subsampling=0)
    print(f"wallpaper.jpg: {w}x{im.height}")


def painted(w, h, seed, colors, s=1.0, impasto=0.7):
    """Stone laid in as Robert paints it: broad, nearly level strokes of close values over a mottled ground, the
    lighter ones catching the light at their edges. Calmer than mt.panel, whose swirls read as fur on a big panel."""
    rng = np.random.default_rng(seed)
    angle = 0.06 + 0.22 * np.tanh(1.2 * mt.fbm(h, w, rng, base=1.6, octaves=2, persistence=0.4))
    a, b, c, weather = (mt.hexrgb(x) for x in colors)
    rgb = mt.mix(a, b, mt.smoothstep(-1.4, 1.4, mt.fbm(h, w, rng, base=2.5, octaves=4, persistence=0.5)))
    rgb = mt.mix(rgb, c, 0.55 * mt.smoothstep(0.4, 1.9, mt.fbm(h, w, rng, base=2.2, octaves=3, stretch=2.0)))
    rgb = mt.mix(rgb, weather, 0.4 * mt.smoothstep(0.6, 2.0, mt.fbm(h, w, rng, base=2, octaves=3)))
    out = mt.paint(rgb, angle, rng, [(int(380 * s * s), (12 * s, 22 * s), (30 * s, 80 * s)),
                                     (int(900 * s * s), (5 * s, 10 * s), (14 * s, 36 * s))], 0.04, hue=0.003)
    out = mt.gaussian_filter(out, (0.8 * s, 0.8 * s, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, 0.018))
    return mt.impasto(out, impasto, blur=0.9 * s)


def others():
    for name in ("the-swing", "flowers"):
        Image.open(os.path.join(HERE, "source", name + ".jpg")).save(os.path.join(HERE, name + ".jpg"), quality=92,
                                                                     subsampling=0)
    # The Swing: the girl on the swing a little right of centre.
    im = Image.open(os.path.join(HERE, "source", "the-swing.jpg"))
    w = round(im.height * PHONE)
    x0 = min(max(0, round(0.52 * im.width - w / 2)), im.width - w)
    im.crop((x0, 0, x0 + w, im.height)).save(os.path.join(HERE, "wallpaper-swing.jpg"), quality=92, subsampling=0)
    # The still life: keep the whole bouquet; carry its dark ground up the screen, softened so no seam shows.
    im = np.asarray(Image.open(os.path.join(HERE, "source", "flowers.jpg")).convert("RGB"), dtype=np.float64) / 255
    h, w, _ = im.shape
    im = im[8:]                                                 # the scan's dark top edge
    h = im.shape[0]
    extra, fade = round(w / PHONE) - h, 160
    # The ground below the painting's top edge, carried up and mottled the way the ground is painted, fading into it.
    top = mt.gaussian_filter(im[:fade].mean(axis=0), (24, 0))
    rng = np.random.default_rng(5)
    mott = mt.fbm(extra + fade, w, rng, base=3, octaves=5)
    grain = mt.gaussian_filter(rng.standard_normal((extra + fade, w)), 0.8)
    t = np.linspace(0, 1, extra + fade)[:, None, None]
    band = top[None] * (0.8 + 0.2 * t) * (1 + 0.05 * mott[..., None] + 0.035 * grain[..., None])
    a = np.clip((np.arange(extra + fade) - extra) / fade, 0, 1)[:, None, None]
    band[extra:] = band[extra:] * (1 - a[extra:]) + im[:fade] * a[extra:]
    out = np.concatenate([band, im[fade:]], axis=0)
    save(out, "wallpaper-flowers.jpg")


def stone(name, n=900):
    save(painted(n, n, sum(map(ord, name)) * 13, STONES[name], s=1.2), name + ".jpg")


def wall():
    save(painted(1232, 1300, 91, (0xE4DAC6, 0xD6CAB2, 0xEEE6D4, 0xCFCDB8), s=1.6, impasto=0.5), "wall.jpg")


def save(rgb, name):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name), quality=90, subsampling=0)
    print(f"{name}: {px.shape[1]}x{px.shape[0]}")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, make in [("painting", painting), ("wallpaper", wallpaper), ("others", others), ("wall", wall)]:
        if not only or name in only:
            make()
    for name in STONES:
        if not only or name in only:
            stone(name)


if __name__ == "__main__":
    main()
