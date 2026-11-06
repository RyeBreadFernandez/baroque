#!/usr/bin/env python3
"""Copies the user's app icons out of the Blender renders as opaque 1024 px PNGs named by app, ready for the Shortcuts
app's "Add to Home Screen" (it wants a square image; iOS rounds the corners itself). The transparent corners are filled
from the stone around them. Run after build.py:  python3 MockLab/Textures/travertine/icons/export.py [travertine|rococo]
(writes to screenshots/<set>/icons-for-shortcuts/)."""
import os
import sys

sys.dont_write_bytecode = True
import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
# The home screen's apps, as TVApps lists them (dock, then pages one to three).
APPS = ["Claude", "Messages", "Safari", "Obsidian",
        "Gmail", "Photos", "Camera", "YouTube", "Settings", "Spotify", "Maps", "Calendar",
        "Weather", "AllTrails", "Uber Eats", "Netflix", "Equinox", "Find My", "Slack", "Clock",
        "Wallet", "App Store", "Files", "Venmo"]


def export(src_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    keep = set()
    for app in APPS:
        img = cv2.imread(os.path.join(src_dir, app.lower().replace(" ", "") + ".png"), cv2.IMREAD_UNCHANGED)
        big = cv2.resize(img, (1024, 1024), interpolation=cv2.INTER_LANCZOS4)
        rgb, alpha = big[..., :3], big[..., 3]
        # Fill the rounded corners (and the soft edge) with the stone just inside them.
        hole = (alpha < 250).astype(np.uint8) * 255
        opaque = cv2.inpaint(rgb, hole, 12, cv2.INPAINT_TELEA)
        cv2.imwrite(os.path.join(out_dir, app + ".png"), opaque)
        keep.add(app + ".png")
    # Icons for apps no longer on the home screen.
    for f in os.listdir(out_dir):
        if f.endswith(".png") and f not in keep:
            os.remove(os.path.join(out_dir, f))
    print(f"{len(keep)} icons in {out_dir}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "travertine"
    src = HERE if which == "travertine" else os.path.join(os.path.dirname(os.path.dirname(HERE)), which, "icons")
    export(src, os.path.join(ROOT, "screenshots", which, "icons-for-shortcuts"))
