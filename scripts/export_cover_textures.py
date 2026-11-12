#!/usr/bin/env python3
"""Copies the Old Master Cover textures into MockLab's archive catalog.

The Cover paintings are painted by MockLab/Textures/old-master-cover/make.py (value studies as alpha PNGs, 1 px per
point of each widget, the mountain from matterhorn.json). The look left the app on 2026-11-06; MockLab still renders
it (PaintKit). This copies every PNG there into MockLab/Archive.xcassets as an imageset named in UpperCamelCase with a
Cover prefix:

    day-large-lo.png -> CoverDayLargeLo      gilt.png -> CoverGilt      veil.png -> CoverVeil

Each imageset holds one universal image (the same Contents.json as write() in scripts/make_textures.py). Cover*
imagesets that are no longer produced are removed; anything else in the catalog is left alone.

    python3 scripts/export_cover_textures.py            copy the existing PNGs
    python3 scripts/export_cover_textures.py --paint    repaint them first (make.py: deterministic, offline;
                                                        needs numpy, scipy, Pillow)
The copy itself needs only the standard library. No __pycache__ is left behind.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys

sys.dont_write_bytecode = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "MockLab", "Textures", "old-master-cover")
CATALOG = os.path.join(ROOT, "MockLab", "Archive.xcassets")   # retired from the app on 2026-11-06; MockLab still renders it
PREFIX = "Cover"


def asset_name(stem):
    """day-large-lo -> CoverDayLargeLo"""
    return PREFIX + "".join(part[:1].upper() + part[1:] for part in re.split(r"[-_ ]+", stem) if part)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError(f"{path} is not a PNG")
    return struct.unpack(">II", head[16:24])


def remove_pycache():
    for top in (SRC, os.path.join(os.path.dirname(SRC), "old-master"), os.path.dirname(os.path.abspath(__file__))):
        for folder, dirs, _ in os.walk(top):
            if "__pycache__" in dirs:
                shutil.rmtree(os.path.join(folder, "__pycache__"))
                dirs.remove("__pycache__")


def main():
    if "--paint" in sys.argv[1:]:
        subprocess.run([sys.executable, "-B", os.path.join(SRC, "make.py")], check=True)
        remove_pycache()

    if not os.path.isdir(CATALOG):                      # a fresh catalog, as Xcode would start one
        os.makedirs(CATALOG)
        with open(os.path.join(CATALOG, "Contents.json"), "w") as f:
            json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    produced = set()
    for filename in sorted(os.listdir(SRC)):
        stem, ext = os.path.splitext(filename)
        if ext.lower() != ".png":
            continue
        name = asset_name(stem)
        produced.add(name)
        folder = os.path.join(CATALOG, name + ".imageset")
        os.makedirs(folder, exist_ok=True)
        for old in os.listdir(folder):
            os.remove(os.path.join(folder, old))
        shutil.copyfile(os.path.join(SRC, filename), os.path.join(folder, name + ".png"))
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump({"images": [{"filename": name + ".png", "idiom": "universal"}],
                       "info": {"author": "xcode", "version": 1}}, f, indent=2)
        w, h = png_size(os.path.join(folder, name + ".png"))
        print(f"{name}: {w}x{h}")

    for entry in sorted(os.listdir(CATALOG)):
        if entry.startswith(PREFIX) and entry.endswith(".imageset") and entry[:-len(".imageset")] not in produced:
            shutil.rmtree(os.path.join(CATALOG, entry))
            print(f"removed stale {entry}")

    remove_pycache()


if __name__ == "__main__":
    main()
