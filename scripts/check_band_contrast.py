#!/usr/bin/env python3
"""Measures "Today" and the date on the large Today's band when it shows the Daily Brief's picture of the day.

The brief's picture is a painting from a museum, and it may be much lighter than the still life, white even, where the
words sit. The app's -renderWidgets draws the band over three stand-ins cut by BandImage ("light", white where the
words are; "photo", a repainted photograph; "dark", a nocturne), by day and by night, each with a "-ground" twin that
leaves the words out. This finds the words' pixels (cream, on the dark stand-in, where they can't be mistaken for the
picture), reads what lies under each of them in the ground render, and gives the WCAG contrast of the cream against
it: the worst pixel, the 5th percentile and the median, for "Today" and for the date. Every line must reach 4.5:1 at
its worst pixel.

Run:  launch the Debug app with -renderWidgets (see docs/ARCHITECTURE.md), copy Documents/renders out of the
      simulator, then: python3 scripts/check_band_contrast.py <renders folder>
Exits 1 if any line falls short.
"""
import os
import sys

import numpy as np
from PIL import Image

TARGET = 4.5
CREAM = np.array([0xF7, 0xF0, 0xE4], dtype=float)   # RococoInk.cream
DESIGN_WIDTH = 348.0                                  # the large widget at the iPhone 17 size, in points
BAND = (10, 10, 328, 82)                              # the band, x, y, w, h in points
PICTURES = ("light", "photo", "dark")
TIMES = ("day", "night")


def luminance(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def load(folder, name):
    path = os.path.join(folder, name + ".png")
    if not os.path.exists(path):
        sys.exit(f"No {path}: run the app with -renderWidgets and copy its Documents/renders here.")
    return np.asarray(Image.open(path).convert("RGB")).astype(float)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    cream_y = float(luminance(CREAM))
    failed = False
    for time in TIMES:
        # The words' pixels: cream in the render over the dark stand-in, and not cream without the words.
        words = load(folder, f"402-today-large-picture-dark-{time}")
        bare = load(folder, f"402-today-large-picture-dark-{time}-ground")
        px = words.shape[1] / DESIGN_WIDTH
        x, y, w, h = (int(round(v * px)) for v in BAND)
        inside = np.zeros(words.shape[:2], dtype=bool)
        inside[y:y + h, x:x + w] = True
        glyph = inside & (np.abs(words - CREAM).max(axis=-1) <= 6) & (np.abs(bare - CREAM).max(axis=-1) > 40)
        left = np.zeros_like(glyph)
        left[:, :x + w // 2] = True
        for picture in PICTURES:
            ground = luminance(load(folder, f"402-today-large-picture-{picture}-{time}-ground"))
            cells = []
            for label, mask in (("Today", glyph & left), ("date", glyph & ~left)):
                ratios = (cream_y + 0.05) / (ground[mask] + 0.05)
                worst, p5, median = ratios.min(), np.percentile(ratios, 5), np.median(ratios)
                failed |= worst < TARGET
                mark = " " if worst >= TARGET else "!"
                cells.append(f"{label} {worst:5.2f}{mark} {p5:5.2f} {median:5.2f}  ({mask.sum()} px)")
            print(f"  {picture:6} {time:5}  " + "   ".join(cells))
    print(f"\nWorst pixel, 5th percentile and median contrast of the cream words; target {TARGET}:1 at the worst pixel.")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
