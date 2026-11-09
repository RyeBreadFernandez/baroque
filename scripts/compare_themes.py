#!/usr/bin/env python3
"""A side-by-side of the RococoTheme options on the author's home screen, page two (the small Day, Quote and Today
widgets on The Bathing Pool), and each option's large Today widget, for choosing a look.

Inputs: MockLab/out/themes/<option>/ (cd MockLab && THEMES=1 swift run --scratch-path .build-smalls RSmalls) and a
screenshot of page two (PAGE2, from scripts/mirror_setup.py). Writes MockLab/out/themes/compare.jpg.
"""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(__file__))
import readme_images as ri
from PIL import Image, ImageDraw

THEMES = os.path.join(ri.ROOT, "MockLab", "out", "themes")
ORDER = ["current", "quiet", "carved", "ivory"]
NAMES = {"current": "Current", "quiet": "Quiet", "carved": "Carved", "ivory": "Ivory"}


def main():
    page2 = os.environ["PAGE2"]
    cols = []
    for option in ORDER:
        ri.RENDERS = os.path.join(THEMES, option)
        phone = ri.rounded(ri.page(page2, ri.PAGE2_WIDGETS), 110)
        today = ri.rounded(Image.open(os.path.join(THEMES, option, "today-large.png")).convert("RGB"), 44)
        cols.append((option, phone, today))
    pad, gap, label = 60, 50, 70
    w = 784
    today_h = round(cols[0][2].height * w / cols[0][2].width)
    canvas = ri.ground((pad * 2 + len(cols) * w + (len(cols) - 1) * gap, pad * 2 + label + 1704 + gap + today_h), darken=0.6)
    d = ImageDraw.Draw(canvas)
    for i, (option, phone, today) in enumerate(cols):
        x = pad + i * (w + gap)
        d.text((x + w / 2, pad + 26), NAMES[option], font=ri.font(48), fill=ri.INK, anchor="mm")
        ri.shadow_paste(canvas, phone, (x, pad + label))
        ri.shadow_paste(canvas, today.resize((w, today_h), Image.LANCZOS), (x, pad + label + 1704 + gap))
    out = os.path.join(THEMES, "compare.jpg")
    canvas.convert("RGB").resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS).save(out, quality=86)
    print(out)


if __name__ == "__main__":
    main()
