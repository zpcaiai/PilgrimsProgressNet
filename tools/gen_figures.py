#!/usr/bin/env python3
"""
gen_figures.py — make clean transparent character cutouts for in-world billboards.

The dialogue portraits in assets/characters/<stem>.png are framed figures on a
painted background. This segments the figure out and writes a transparent
assets/characters/figures/<stem>.webp — used by AssetLib.figure() to stand the
cast up in the 3D world as billboards (player = pilgrim, NPCs = their portraits)
instead of greybox capsules.

Segmentation uses OpenCV GrabCut (clean foreground/background separation, no
model download). If OpenCV isn't available it falls back to a border flood-fill
+ oval feather (rougher).

Drop your own transparent <stem>.webp into assets/characters/figures/ to
override any cutout with a hand-made one (.webp wins over .png).

Usage: python3 tools/gen_figures.py
Requires: numpy, Pillow (+ opencv-python for best quality).
"""
import os, sys, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CHAR = os.path.join(ROOT, "assets", "characters")
OUT = os.path.join(CHAR, "figures")
SENTINEL = (255, 0, 255)

try:
	import cv2
	_HAS_CV2 = True
except Exception:
	_HAS_CV2 = False


def _autocrop(rgb, alpha):
	out = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
	bb = Image.fromarray(alpha, "L").getbbox()
	return out.crop(bb) if bb is not None else out


def grabcut_cutout(path, iters=6):
	rgb = np.asarray(Image.open(path).convert("RGB"))
	h, w = rgb.shape[:2]
	bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
	mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
	bm = max(4, int(min(h, w) * 0.04))
	# Probable foreground = the central framed area; the border is sure
	# background; a central band (torso/face of a centred portrait) is sure fg.
	mask[int(h * 0.05):int(h * 0.99), int(w * 0.14):int(w * 0.86)] = cv2.GC_PR_FGD
	mask[:bm, :] = cv2.GC_BGD
	mask[-bm:, :] = cv2.GC_BGD
	mask[:, :bm] = cv2.GC_BGD
	mask[:, -bm:] = cv2.GC_BGD
	mask[int(h * 0.18):int(h * 0.96), int(w * 0.40):int(w * 0.60)] = cv2.GC_FGD
	bgd = np.zeros((1, 65), np.float64)
	fgd = np.zeros((1, 65), np.float64)
	cv2.grabCut(bgr, mask, None, bgd, fgd, iters, cv2.GC_INIT_WITH_MASK)
	fg = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype("uint8")
	# Clean: close gaps, drop specks, keep the largest blob.
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
	fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, k)
	fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, k)
	n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
	if n > 1:
		fg = np.where(lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA]), 255, 0).astype("uint8")
	alpha = cv2.GaussianBlur(fg, (0, 0), 1.1)
	return _autocrop(rgb, alpha)


def floodfill_cutout(path, thresh=36, feather=0.8):
	img = Image.open(path).convert("RGB")
	w, h = img.size
	work = img.copy()
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
	yy, xx = np.mgrid[0:h, 0:w]
	ov = ((xx - w / 2.0) / (w * 0.46)) ** 2 + ((yy - h / 2.0) / (h * 0.52)) ** 2
	alpha = (alpha * np.clip(1.0 - (ov - 0.82) / 0.34, 0.0, 1.0)).astype("uint8")
	alpha = np.asarray(Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(feather))).astype("uint8")
	return _autocrop(np.asarray(img), alpha)


def cutout(path):
	if _HAS_CV2:
		try:
			return grabcut_cutout(path)
		except Exception as e:
			print("  (grabcut failed, falling back:", str(e)[:60], ")")
	return floodfill_cutout(path)


def main():
	os.makedirs(OUT, exist_ok=True)
	pngs = sorted(glob.glob(os.path.join(CHAR, "*.png")))
	if not pngs:
		print("no portraits found in", CHAR)
		return
	print("segmentation:", "GrabCut (OpenCV)" if _HAS_CV2 else "flood-fill fallback")
	for p in pngs:
		stem = os.path.splitext(os.path.basename(p))[0]
		co = cutout(p)
		dest = os.path.join(OUT, stem + ".webp")
		co.save(dest, "WEBP", quality=92, method=3)
		print(f"  ✓ figures/{stem}.webp  {co.size}")
	print("done.")


if __name__ == "__main__":
	main()
