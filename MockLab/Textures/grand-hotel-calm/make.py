#!/usr/bin/env python3
"""Grand Hotel Calm: one quiet card stock for the slabs that carry text.

Grand Hotel's cream card (Textures/grand-hotel/cream.jpg) is painted with strokes strong enough to read as marble
behind 13 pt type. This paints the same card with the same brush (Grand Hotel's `board`, which uses the shipped
scripts/make_textures.py functions), then pulls every pixel most of the way back to the card's mean colour, so the
strokes are still there as a faint grain but no longer compete with the ink. The full-strength cream is laid only
along the slab's rim at run time (GCSlab), so brushwork shows at the edges and in the scene, not behind the words.

  vellum.jpg  340x270  quiet cream card (the register, the quote cards); about 1 px per point of the largest slab

Run from anywhere (deterministic):  python3 MockLab/Textures/grand-hotel-calm/make.py
Leaves Textures/grand-hotel untouched.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing the sibling make.py must not leave a __pycache__ behind

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gh_make", os.path.join(os.path.dirname(HERE), "grand-hotel", "make.py"))
gh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gh)


def calm(img, keep):
    """Keeps `keep` of each pixel's distance from the mean colour: the brushwork, turned down."""
    mean = img.reshape(-1, 3).mean(axis=0)
    return mean + (img - mean) * keep


def save(name, img):
    px = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=92, subsampling=0)
    grey = px.astype(np.float64).mean(axis=2)
    print(f"{name}.jpg: {img.shape[1]}x{img.shape[0]}  luminance sd {grey.std():.1f}")


def main():
    # Larger, softer strokes than Grand Hotel's cream, in colours closer together, then turned down to about a third.
    card = gh.board(340, 270, 211, (0xFBF1E2, 0xF4E5D0, 0xFFF8EE, 0xF7E6DC), s=1.7, relief=0.12, bristle=0.008)
    save("vellum", calm(card, 0.32))


if __name__ == "__main__":
    main()
