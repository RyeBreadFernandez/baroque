#!/usr/bin/env python3
"""Makes the README's pictures in docs/images/, from demo data only (no one's real tasks or quotes):

  home-screen.jpg  the two home screen pages: screenshots of the author's iPhone 15 Pro (wallpaper, icons, dock) with
                   each widget replaced by the shipped widget view rendered with demo data at the size the phone draws it
  widgets.jpg      every widget at its design size on The Bathing Pool, named
  design-lab.jpg   looks explored in MockLab on the way to this one
  brief.jpg        the app's Daily Brief page, from the simulator with examples/Daily Brief/Today.md

Inputs:
  MockLab/out/readme/   README=1 swift run --scratch-path .build-smalls RSmalls   (from MockLab/)
  the two screenshots   PAGE1 and PAGE2 (scripts/mirror_setup.py saves them to build/mirror-shots/)
  the Brief screenshot  BRIEF (xcrun simctl io booted screenshot, after launching with -briefFile and -openBrief)
  MockLab/out/<look>/   the looks' boards, from their own swift run

Run: PAGE1=... PAGE2=... BRIEF=... python3 scripts/readme_images.py
"""
import glob
import os
import sys

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "docs", "images")
RENDERS = os.path.join(ROOT, "MockLab", "out", "readme")
LOOKS = os.path.join(ROOT, "MockLab", "out")
WALLPAPER = os.path.join(ROOT, "Baroque", "Assets.xcassets", "Wallpaper.imageset", "Wallpaper.jpg")
DIDOT = "/System/Library/Fonts/Supplemental/Didot.ttc"
INK = (247, 240, 228)

# Where the phone draws each widget on its 2x screenshots (784 x 1704 px): left, top, right, bottom.
PAGE1_WIDGETS = {"phone-day-large": (38, 163, 747, 868)}
PAGE2_WIDGETS = {"phone-day-small": (38, 163, 374, 497), "phone-quote-small": (412, 535, 747, 869),
                 "phone-today-small": (38, 907, 374, 1241)}
WIDGET_RADIUS = 43        # px at 2x


def font(size, index=0):
    try:
        return ImageFont.truetype(DIDOT, size, index=index)
    except OSError:
        return ImageFont.load_default()


def rounded(im, radius):
    """The image with transparent rounded corners, antialiased (drawn at 4x, then reduced)."""
    k = 4
    mask = Image.new("L", (im.width * k, im.height * k), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width * k - 1, im.height * k - 1), radius * k, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask.resize(im.size, Image.LANCZOS))
    return out


def page(screenshot, widgets):
    """A phone screenshot with its widgets replaced by the demo renders."""
    base = Image.open(screenshot).convert("RGBA").resize((784, 1704), Image.LANCZOS)
    for name, (l, t, r, b) in widgets.items():
        w = Image.open(os.path.join(RENDERS, name + ".png")).convert("RGB").resize((r - l, b - t), Image.LANCZOS)
        base.alpha_composite(rounded(w, WIDGET_RADIUS), (l, t))
    return base


def shadow_paste(canvas, im, xy, blur=24, offset=(0, 14), alpha=110):
    sh = Image.new("RGBA", (im.width + blur * 4, im.height + blur * 4), (0, 0, 0, 0))
    sh.paste((0, 0, 0, alpha), (blur * 2, blur * 2), im.split()[-1])
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (xy[0] - blur * 2 + offset[0], xy[1] - blur * 2 + offset[1]))
    canvas.alpha_composite(im, xy)


def ground(size, darken=0.35):
    wall = Image.open(WALLPAPER).convert("RGB")
    k = max(size[0] / wall.width, size[1] / wall.height)
    wall = wall.resize((round(wall.width * k), round(wall.height * k)), Image.LANCZOS)
    x, y = (wall.width - size[0]) // 2, (wall.height - size[1]) // 2
    g = wall.crop((x, y, x + size[0], y + size[1])).filter(ImageFilter.GaussianBlur(2))
    return Image.blend(g, Image.new("RGB", size, (20, 16, 12)), darken).convert("RGBA")


def home_screen(page1, page2):
    pages = [rounded(page(page1, PAGE1_WIDGETS), 110), rounded(page(page2, PAGE2_WIDGETS), 110)]
    pad, gap = 90, 80
    canvas = ground((pad * 2 + 784 * 2 + gap, pad * 2 + 1704), darken=0.55)
    for i, p in enumerate(pages):
        shadow_paste(canvas, p, (pad + i * (784 + gap), pad))
    canvas.convert("RGB").resize((canvas.width * 3 // 4, canvas.height * 3 // 4), Image.LANCZOS).save(os.path.join(OUT, "home-screen.jpg"), quality=84)


def widgets():
    rows = [
        [("day-large", "Day"), ("today-large", "Today"), ("quote-large", "Quote"), ("still-life-large", "Still Life")],
        [("day-medium", "Day"), ("today-medium", "Today"), ("quote-medium", "Quote")],
        [("day-small", "Day"), ("today-small", "Today"), ("quote-small", "Quote"), ("battery-small", "Battery"), ("still-life-small", "Still Life"), ("photograph-small", "Photograph")],
    ]
    scale = 0.5                      # the renders are at 3x; the sheet is at 1.5x
    gap, pad, label = 44, 70, 54
    tiles = [[(Image.open(os.path.join(RENDERS, n + ".png")).convert("RGB"), title) for n, title in row] for row in rows]
    tiles = [[(im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS), t) for im, t in row] for row in tiles]
    width = max(sum(im.width for im, _ in row) + gap * (len(row) - 1) for row in tiles) + pad * 2
    height = sum(max(im.height for im, _ in row) + label for row in tiles) + gap * (len(tiles) - 1) + pad * 2
    canvas = ground((width, height))
    d = ImageDraw.Draw(canvas)
    y = pad
    for row in tiles:
        row_w = sum(im.width for im, _ in row) + gap * (len(row) - 1)
        x = (width - row_w) // 2
        for im, title in row:
            shadow_paste(canvas, rounded(im, round(22 * 1.5)), (x, y), blur=14, offset=(0, 8), alpha=120)
            d.text((x + im.width / 2, y + im.height + 30), title, font=font(26), fill=INK, anchor="mm")
            x += im.width + gap
        y += max(im.height for im, _ in row) + label + gap
    canvas.convert("RGB").save(os.path.join(OUT, "widgets.jpg"), quality=86)


def design_lab():
    looks = [("weather-sun-arc", "board.png", "Sun arc"), ("field-journal", "board.png", "Field journal"),
             ("neon-rain", "board.png", "Neon rain"), ("grand-hotel", "board.png", "Grand hotel"),
             ("old-master-cover", "board.png", "Old master cover"), ("travertine", "home-1.png", "Travertine"),
             ("rococo", "home-1.png", "Rococo (shipped)")]
    cell_w, cell_h, gap, pad, label = 520, 420, 30, 50, 46
    cols = 4
    rows = (len(looks) + cols - 1) // cols
    canvas = ground((pad * 2 + cols * cell_w + (cols - 1) * gap, pad * 2 + rows * (cell_h + label) + (rows - 1) * gap), darken=0.6)
    d = ImageDraw.Draw(canvas)
    for i, (slug, file, title) in enumerate(looks):
        path = os.path.join(LOOKS, slug, file)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGB")
        im.thumbnail((cell_w, cell_h), Image.LANCZOS)
        x = pad + (i % cols) * (cell_w + gap) + (cell_w - im.width) // 2
        y = pad + (i // cols) * (cell_h + label + gap) + (cell_h - im.height) // 2
        shadow_paste(canvas, rounded(im, 16), (x, y), blur=10, offset=(0, 6), alpha=120)
        d.text((pad + (i % cols) * (cell_w + gap) + cell_w / 2, pad + (i // cols) * (cell_h + label + gap) + cell_h + 26),
               title, font=font(24), fill=INK, anchor="mm")
    canvas.convert("RGB").save(os.path.join(OUT, "design-lab.jpg"), quality=84)


def brief(screenshot):
    im = Image.open(screenshot).convert("RGB")
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    canvas = ground((im.width + 120, im.height + 120), darken=0.55)
    shadow_paste(canvas, rounded(im, 80), (60, 60))
    canvas.convert("RGB").save(os.path.join(OUT, "brief.jpg"), quality=86)


def main():
    os.makedirs(OUT, exist_ok=True)
    if not glob.glob(os.path.join(RENDERS, "*.png")):
        sys.exit("Render the widgets first: cd MockLab && README=1 swift run --scratch-path .build-smalls RSmalls")
    widgets()
    design_lab()
    if os.environ.get("PAGE1") and os.environ.get("PAGE2"):
        home_screen(os.environ["PAGE1"], os.environ["PAGE2"])
    if os.environ.get("BRIEF"):
        brief(os.environ["BRIEF"])
    for f in sorted(os.listdir(OUT)):
        print(f, Image.open(os.path.join(OUT, f)).size, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")


if __name__ == "__main__":
    main()
