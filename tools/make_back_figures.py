#!/usr/bin/env python3
"""make_back_figures.py — synthesize a BACK view of a character from the front
full-body figure, so a figure can show its back when walking away from the
camera (no face).

Two modes (chosen per stem):
  pack=True  (pilgrim, pilgrim_child) — big canvas backpack + bedroll + straps
             over the torso (they carry the burden).
  pack=False (hopeful, ...)           — smooth garment back (no pack), just the
             back of the head + the coat back + legs.

Input : assets/characters/figures/<stem>.webp   (front full body)
Output: assets/characters/figures/<stem>_back.webp
Env: FIG_VIEW_DIR=<dir> writes a grey-checked preview.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
FIG = os.path.join(ROOT, "assets", "characters", "figures")
VIEW = os.environ.get("FIG_VIEW_DIR", "")
PACK_STEMS = {"pilgrim", "pilgrim_child"}


def _skin(rgb):
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (R > 110) & (R < 248) & (R >= G) & (G >= B * 0.92) & ((R - B) > 16) & ((R - B) < 175)


def _white(rgb):
    return (rgb[..., 0] > 200) & (rgb[..., 1] > 200) & (rgb[..., 2] > 190)


def build_back(stem):
    pack = stem in PACK_STEMS
    im = Image.open(os.path.join(FIG, stem + ".webp")).convert("RGBA")
    bb = im.split()[-1].getbbox()
    if bb:
        im = im.crop(bb)
    arr = np.asarray(im).astype(np.float32)
    H, W = arr.shape[:2]
    mask = arr[..., 3] > 40
    ys = np.where(mask.any(axis=1))[0]
    xs = np.where(mask.any(axis=0))[0]
    top, bot = int(ys.min()), int(ys.max())
    l, r = int(xs.min()), int(xs.max())
    ch = bot - top
    cw = r - l
    cx = (l + r) / 2.0
    out = arr.copy()

    capband = mask[top:top + max(2, int(ch * 0.10)), l:r + 1]
    cap = np.median(arr[top:top + max(2, int(ch * 0.10)), l:r + 1, :3][capband], axis=0)

    # 1) Back of the head: a clean rounded cap over the face (both modes).
    head_bot = top + int(ch * 0.30)
    hxs = np.where(mask[top:head_bot].any(axis=0))[0]
    hl, hr = (int(hxs.min()), int(hxs.max())) if hxs.size >= 2 else (l, r)
    hcx = (hl + hr) / 2.0
    hrx = max(4.0, (hr - hl) / 2.0) * 1.05
    hcy = (top + head_bot) / 2.0
    hry = max(4.0, (head_bot - top) / 2.0) * 1.05
    for y in range(top, head_bot):
        dy = (y - hcy) / hry
        if abs(dy) > 1.0:
            continue
        span = hrx * math.sqrt(max(0.0, 1.0 - dy * dy))
        a = max(0, int(hcx - span)); b = min(W - 1, int(hcx + span))
        if b <= a:
            continue
        u = np.linspace(0, 1, b - a + 1)
        out[y, a:b + 1, :3] = np.clip(cap[None, :] * (1.0 - 0.38 * (2 * u - 1) ** 2)[:, None] * 0.9, 0, 255)
        out[y, a:b + 1, 3] = 255.0

    torso_bot = top + int(ch * 0.62)
    if pack:
        canvas = np.array([108, 78, 46], np.float32)
        canvas_dk = np.array([78, 56, 33], np.float32)
        roll = np.array([150, 124, 86], np.float32)
        pack_top = top + int(ch * 0.20)
        ph = max(1, torso_bot - pack_top)
        half = cw * 0.52
        for y in range(pack_top, torso_bot):
            t = (y - pack_top) / ph
            wf = 1.0 - 0.22 * abs(2 * t - 1) ** 1.3
            a = max(0, int(cx - half * wf)); b = min(W - 1, int(cx + half * wf))
            if b <= a:
                continue
            u = np.linspace(0, 1, b - a + 1)
            cyl = 1.0 - 0.34 * (2 * u - 1) ** 2
            sheen = 0.12 * np.exp(-((u - 0.5) / 0.16) ** 2)
            base = canvas if t > 0.16 else canvas_dk
            out[y, a:b + 1, :3] = np.clip(base[None, :] * (cyl + sheen)[:, None] * (1.06 - 0.34 * t), 0, 255)
            out[y, a:b + 1, 3] = 255.0
        for y in range(max(top, pack_top - int(ch * 0.02)), pack_top + int(ch * 0.07)):  # bedroll
            a = max(0, int(cx - half * 1.02)); b = min(W - 1, int(cx + half * 1.02))
            if b <= a:
                continue
            u = np.linspace(0, 1, b - a + 1)
            out[y, a:b + 1, :3] = np.clip(roll[None, :] * (0.7 + (1.0 - 0.5 * (2 * u - 1) ** 2)[:, None] * 0.5), 0, 255)
            out[y, a:b + 1, 3] = 255.0
        for sgn in (-1, 1):                                                            # straps
            sxc = cx + sgn * half * 0.62
            for y in range(pack_top, torso_bot):
                a = max(0, int(sxc - cw * 0.04)); b = min(W - 1, int(sxc + cw * 0.04))
                if b > a:
                    out[y, a:b + 1, :3] = canvas_dk * 0.8
                    out[y, a:b + 1, 3] = 255.0
    else:
        # Smooth garment back (no pack): hide front details, keep silhouette.
        gband = arr[head_bot:head_bot + max(4, int(ch * 0.14)), l:r + 1, :3]
        gm = mask[head_bot:head_bot + max(4, int(ch * 0.14)), l:r + 1] & ~_skin(gband) & ~_white(gband)
        gar = np.median(gband[gm], axis=0) if gm.sum() > 6 else np.median(gband.reshape(-1, 3), axis=0)
        for y in range(head_bot, torso_bot):
            rowxs = np.where(mask[y])[0]
            if rowxs.size < 2:
                continue
            a, b = int(rowxs.min()), int(rowxs.max())
            u = np.linspace(0, 1, b - a + 1)
            cyl = 1.0 - 0.30 * (2 * u - 1) ** 2
            seam = 1.0 - 0.12 * np.exp(-((u - 0.5) / 0.06) ** 2)   # faint spine
            t = (y - head_bot) / max(1, torso_bot - head_bot)
            out[y, a:b + 1, :3] = np.clip(gar[None, :] * (cyl * seam)[:, None] * (1.0 - 0.10 * t), 0, 255)
            out[y, a:b + 1, 3] = 255.0

    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    a2 = np.asarray(img).astype(np.float32)
    a2[..., 3] = np.asarray(Image.fromarray(a2[..., 3].astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), np.float32)
    img = Image.fromarray(np.clip(a2, 0, 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(FIG, stem + "_back.webp"), "WEBP", quality=92, method=4)
    if VIEW:
        os.makedirs(VIEW, exist_ok=True)
        bg = Image.new("RGBA", img.size, (224, 224, 228, 255))
        bg.alpha_composite(img)
        bg.convert("RGB").save(os.path.join(VIEW, "back_view_" + stem + ".png"))
    return ("pack" if pack else "plain"), img.size


def main():
    for s in (sys.argv[1:] or ["pilgrim", "hopeful"]):
        try:
            print("OK", s, build_back(s))
        except Exception as e:
            import traceback; traceback.print_exc(); print("FAIL", s, e)


if __name__ == "__main__":
    main()
