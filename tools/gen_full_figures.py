#!/usr/bin/env python3
"""gen_full_figures.py — rebuild FULL-BODY billboard cutouts from expanded art.

Workflow:
  1. In Photoshop/Firefly, take each dialogue portrait (assets/characters/<stem>.png),
     use Generative Expand to extend the canvas DOWNWARD and fill in legs + feet
     (keep the same face, clothing and oil-painting style → a full standing figure).
  2. Remove the background (best) and export a TRANSPARENT PNG, OR leave it opaque.
  3. Save it as assets/characters/figures_full/<stem>.png   (exact stem, see list).
  4. Run:  python3 tools/gen_full_figures.py
     → writes a clean transparent assets/characters/figures/<stem>.webp (full body),
       which AssetLib.figure() uses for the in-world billboards.
     Dialogue portraits (assets/characters/<stem>.png) are left untouched.

Transparent input  -> just trimmed to content (no quality loss).
Opaque input       -> background removed via GrabCut (needs opencv-python), then trimmed.

Requires: numpy, Pillow (+ opencv-python for opaque inputs).
"""
import os, glob
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "assets", "characters", "figures_full")
OUT = os.path.join(ROOT, "assets", "characters", "figures")

try:
    import cv2
    _HAS_CV2 = True
except Exception:
    _HAS_CV2 = False


def _autocrop_rgba(im):
    bb = im.split()[-1].getbbox()
    return im.crop(bb) if bb else im


def _has_transparency(im):
    return np.asarray(im.split()[-1]).min() < 16


def _grabcut(im):
    rgb = np.asarray(im.convert("RGB")); h, w = rgb.shape[:2]
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    bm = max(4, int(min(h, w) * 0.04))
    mask[int(h*0.03):int(h*0.99), int(w*0.10):int(w*0.90)] = cv2.GC_PR_FGD
    mask[:bm, :] = cv2.GC_BGD; mask[-bm:, :] = cv2.GC_BGD
    mask[:, :bm] = cv2.GC_BGD; mask[:, -bm:] = cv2.GC_BGD
    mask[int(h*0.10):int(h*0.97), int(w*0.38):int(w*0.62)] = cv2.GC_FGD
    bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(bgr, mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype("uint8")
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, k)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, k)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        fg = np.where(lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA]), 255, 0).astype("uint8")
    alpha = cv2.GaussianBlur(fg, (0, 0), 1.1)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def main():
    os.makedirs(SRC, exist_ok=True); os.makedirs(OUT, exist_ok=True)
    files = sorted(glob.glob(os.path.join(SRC, "*.png")) + glob.glob(os.path.join(SRC, "*.webp")))
    if not files:
        print("No files in", SRC)
        print("Drop full-body character art there first (named <stem>.png).")
        return
    for p in files:
        stem = os.path.splitext(os.path.basename(p))[0]
        im = Image.open(p).convert("RGBA")
        if _has_transparency(im):
            co, mode = _autocrop_rgba(im), "transparent"
        elif _HAS_CV2:
            co, mode = _autocrop_rgba(_grabcut(im)), "grabcut"
        else:
            co, mode = im, "OPAQUE (install opencv-python for a clean cutout!)"
        co.save(os.path.join(OUT, stem + ".webp"), "WEBP", quality=92, method=4)
        print(f"  OK figures/{stem}.webp  {co.size}  [{mode}]")
    print("Done. Reload the project in Godot so it re-imports the .webp files.")


if __name__ == "__main__":
    main()
