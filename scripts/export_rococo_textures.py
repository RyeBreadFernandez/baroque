#!/usr/bin/env python3
"""Copies the rococo widgets' images from MockLab into Shared/PaintTextures.xcassets as Rococo* imagesets, each cut to
its frame at 2 px per point (JPEG, so the app stays small):

  RococoLimestone  480x480   the painted limestone the stone widgets are laid on (rococo/travertine.jpg)
  RococoHero       696x730   the large Day widget: the user's Kings Canyon, repainted (rococo/photos/kings-canyon.jpg)
  RococoTall       696x730   the large Quote widget: the sunset on the beach (rococo/photos/sunset.jpg)
  RococoWide       696x328   the medium Quote widget: the dead tree (rococo/photos/dead-tree.jpg)
  RococoSquare     328x328   the small Quote widget: the river under the pines (rococo/photos/river.jpg)
  RococoFlowers    304x296   the Today widget's panel: the still life's roses (rococo/flowers.jpg)
  RococoStillLife  328x328   the Still Life widget, small: the whole bouquet in its glass, nothing on it
  RococoStillLifeLarge 696x730  the same, large
  RococoPhoto-<name>        696x730   the user's repainted photographs that take turns on the large Day widget
  RococoPhoto-<name>-small  328x328   the same, for the Photograph widget (Shared/RococoStyle.swift, RococoPhotos)

WidgetKit refuses a widget whose images add up to too many pixels; every widget here stays under one large image
(696x730), well within it. The sources are painted by MockLab/Textures/rococo/make.py and photos.py.

It also fills the app's own catalog (Baroque/Assets.xcassets) from the Blender renders in MockLab/Textures/rococo/icons/
(MockLab/Textures/travertine/icons/build.py with ICON_SET=rococo):
  AppIcon          Baroque's icon, Sun Arc in gold on painted limestone (appicon.png, 1024 px, opaque)
  HomeIcons/Icon*  the user's 24 home screen icons, 512 px and opaque, which the app saves to Photos for Shortcuts
  Wallpaper        The Bathing Pool cut to the screen (rococo/wallpaper.jpg), which the app saves to Photos

Run: python3 scripts/export_rococo_textures.py   (deterministic, offline)
"""
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True
import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "MockLab", "Textures", "rococo")
CATALOG = os.path.join(ROOT, "Shared", "PaintTextures.xcassets")
APP = os.path.join(ROOT, "Baroque", "Assets.xcassets")
ICONS = os.path.join(SRC, "icons")
spec = importlib.util.spec_from_file_location("export", os.path.join(ROOT, "MockLab", "Textures", "travertine", "icons", "export.py"))
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)

# name: (source, (width, height) in px, the part shown: left, top and width as fractions; the height follows)
IMAGES = {
    "RococoLimestone": ("travertine.jpg", (480, 480), (0.0, 0.0, 1.0)),
    "RococoTall": ("photos/sunset.jpg", (696, 730), (0.0, 0.25, 1.0)),
    "RococoWide": ("photos/dead-tree.jpg", (696, 328), (0.0, 0.38, 1.0)),
    "RococoSquare": ("photos/river.jpg", (328, 328), (0.0, 0.0, 1.0)),
    "RococoFlowers": ("flowers.jpg", (304, 296), (0.42, 0.3, 0.58)),
    "RococoStillLife": ("flowers.jpg", (328, 328), (0.0, 0.16, 1.0)),
    "RococoStillLifeLarge": ("flowers.jpg", (696, 730), (0.0, 0.14, 1.0)),
}


# The user's repainted photographs that take turns (2026-11-08: "have it so the image on the main screen rotates over
# time with some of the other images I have taken"), each cut for the large Day widget and for the small Photograph
# widget: (left, top, width) as fractions, the height following from the frame. The large cuts keep the left side and
# the top darkest, where the quote and the temperature sit.
PHOTOS = {
    "kings-canyon": ((0.03, 0.0, 0.953), (0.0, 0.0, 1.0)),
    "valley": ((0.02, 0.0, 0.953), (0.0, 0.0, 1.0)),
    "river": ((0.0, 0.0, 0.953), (0.0, 0.0, 1.0)),
    "dead-tree": ((0.03, 0.0, 0.953), (0.0, 0.0, 1.0)),
    "falls": ((0.04, 0.0, 0.953), (0.0, 0.0, 1.0)),
    "bryce": ((0.0, 0.24, 1.0), (0.0, 0.06, 1.0)),
    "arch": ((0.0, 0.28, 1.0), (0.0, 0.32, 1.0)),
    "zion": ((0.0, 0.36, 1.0), (0.0, 0.4, 1.0)),
    "sunset": ((0.0, 0.33, 1.0), (0.0, 0.38, 1.0)),
    "zion-canyon": ((0.3, 0.0, 0.436), (0.28, 0.0, 0.457)),
}
for _name, (_large, _small) in PHOTOS.items():
    IMAGES[f"RococoPhoto-{_name}"] = (f"photos/{_name}.jpg", (696, 730), _large)
    IMAGES[f"RococoPhoto-{_name}-small"] = (f"photos/{_name}.jpg", (328, 328), _small)


def cut(src, size, spot):
    im = Image.open(os.path.join(SRC, src)).convert("RGB")
    x, y, w = spot
    pw = w * im.width
    ph = pw * size[1] / size[0]
    box = (round(x * im.width), round(y * im.height), round(x * im.width + pw), round(y * im.height + ph))
    if box[3] > im.height:   # keep the cut inside the picture
        box = (box[0], im.height - (box[3] - box[1]), box[2], im.height)
    return im.crop(box).resize(size, Image.LANCZOS)


def imageset(folder, name, filename):
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)


def opaque(path, px):
    """A Blender icon with its transparent corners filled from the stone round them (iOS rounds them itself)."""
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    img = cv2.resize(img, (px, px), interpolation=cv2.INTER_AREA)
    if img.shape[2] == 4:
        hole = (img[..., 3] < 250).astype(np.uint8) * 255
        img = cv2.inpaint(img[..., :3], hole, 6, cv2.INPAINT_TELEA)
    return img


def app_icons():
    icon = os.path.join(APP, "AppIcon.appiconset", "AppIcon.png")
    cv2.imwrite(icon, opaque(os.path.join(ICONS, "appicon.png"), 1024))
    print("AppIcon: 1024x1024 from appicon.png")
    group = os.path.join(APP, "HomeIcons")
    os.makedirs(group, exist_ok=True)
    with open(os.path.join(group, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    for app in export.APPS:
        name = "Icon" + app.replace(" ", "")
        folder = os.path.join(group, name + ".imageset")
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder):
            os.remove(os.path.join(folder, f))
        cv2.imwrite(os.path.join(folder, name + ".png"), opaque(os.path.join(ICONS, app.lower().replace(" ", "") + ".png"), 512))
        imageset(folder, name, name + ".png")
    print(f"HomeIcons: {len(export.APPS)} icons, 512 px")
    folder = os.path.join(APP, "Wallpaper.imageset")
    os.makedirs(folder, exist_ok=True)
    Image.open(os.path.join(SRC, "wallpaper.jpg")).convert("RGB").save(os.path.join(folder, "Wallpaper.jpg"), quality=92, subsampling=0)
    imageset(folder, "Wallpaper", "Wallpaper.jpg")
    print("Wallpaper: The Bathing Pool")


def main():
    app_icons()
    for name, (src, size, spot) in IMAGES.items():
        folder = os.path.join(CATALOG, name + ".imageset")
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder):
            os.remove(os.path.join(folder, f))
        cut(src, size, spot).save(os.path.join(folder, name + ".jpg"), quality=90, subsampling=0)
        imageset(folder, name, name + ".jpg")
        print(f"{name}: {size[0]}x{size[1]} from {src}")


if __name__ == "__main__":
    main()
