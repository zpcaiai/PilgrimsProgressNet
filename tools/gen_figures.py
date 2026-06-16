#!/usr/bin/env python3
"""
gen_figures.py — make transparent character cutouts for in-world billboards.

The dialogue portraits in assets/characters/<stem>.png are framed figures on a
near-uniform painted background (cream/grey). This flood-fills that background
from the borders, makes it transparent, trims to the figure, and writes
assets/characters/figures/<stem>.webp — used by AssetLib.figure() to stand the
characters up in the 3D world as billboards (player = pilgrim, NPCs = their
portraits) instead of greybox capsules.

Drop your own transparent <stem>.webp (or .png) into assets/characters/figures/
to override any cutout with a cleaner hand-made one.

Usage: python3 tools/gen_figures.py
Requires: numpy, Pillow.
"""
import os, sys, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CHAR = os.path.join(ROOT, "assets", "characters")
OUT = os.path.join(CHAR, "figures")
SENTINEL = (255, 0, 255)


def cutout(path, thresh=36, feather=0.8):
	img = Image.open(path).convert("RGB")
	w, h = img.size
	work = img.copy()
	# Flood the background in from many border seeds. thresh is a SUM-of-channel
	# difference from the seed colour (0..765); kept LOW (~36) so the fill clears
	# the flat painted ground but can't cross the figure's edge into skin/cloth.
	seeds = [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2),
			(w // 2, 1), (w // 2, h - 2), (1, h // 2), (w - 2, h // 2),
			(w // 4, 1), (3 * w // 4, 1), (w // 4, h - 2), (3 * w // 4, h - 2)]
	for s in seeds:
		try:
			ImageDraw.floodfill(work, s, SENTINEL, thresh=thresh)
		except Exception:
			pass
	arr = np.asarray(work).astype(int)
	bg = (np.abs(arr[..., 0] - SENTINEL[0]) < 10) & (np.abs(arr[..., 1] - SENTINEL[1]) < 10) & (np.abs(arr[..., 2] - SENTINEL[2]) < 10)
	alpha = np.where(bg, 0.0, 255.0)
	# Oval feather: fade the rectangular corners/edges (where leftover ground
	# sits) into transparency, leaving a clean centred "cameo" of the figure.
	yy, xx = np.mgrid[0:h, 0:w]
	ov = ((xx - w / 2.0) / (w * 0.46)) ** 2 + ((yy - h / 2.0) / (h * 0.52)) ** 2
	ovmask = np.clip(1.0 - (ov - 0.82) / 0.34, 0.0, 1.0)
	alpha = (alpha * ovmask).astype("uint8")
	am = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(feather))
	a = np.asarray(am).astype("uint8")
	rgba = np.dstack([np.asarray(img), a])
	out = Image.fromarray(rgba, "RGBA")
	abbox = Image.fromarray(a, "L").getbbox()
	if abbox is not None:
		out = out.crop(abbox)
	return out


def main():
	os.makedirs(OUT, exist_ok=True)
	pngs = sorted(glob.glob(os.path.join(CHAR, "*.png")))
	if not pngs:
		print("no portraits found in", CHAR)
		return
	for p in pngs:
		stem = os.path.splitext(os.path.basename(p))[0]
		co = cutout(p)
		dest = os.path.join(OUT, stem + ".webp")
		co.save(dest, "WEBP", quality=92, method=3)
		print(f"  ✓ figures/{stem}.webp  {co.size}")
	print("done.")


if __name__ == "__main__":
	main()
