#!/usr/bin/env python3
"""gen_house_textures.py — tileable PBR textures for the house: brick walls and
terracotta roof tiles. Writes albedo + a simple normal map into
assets/textures/pbr/ under dedicated surface names (brick, rooftile) so they
don't touch the shared stone/wood surfaces used by rocks and trunks.

MaterialKit.make("brick"/"rooftile", tint) auto-loads these (texname == surface).
Pure Pillow + numpy. Env FIG_VIEW_DIR=<dir> writes previews.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
PBR = os.path.join(ROOT, "assets", "textures", "pbr")
VIEW = os.environ.get("FIG_VIEW_DIR", "")
N = 256
rng = np.random.default_rng(11)


def _normal_from_height(h):
    """Tileable normal map from a height field (0..1)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    strength = 3.0
    nx, ny, nz = -dx * strength, -dy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.dstack([nx / ln, ny / ln, nz / ln]) * 0.5 + 0.5
    return Image.fromarray((out * 255).astype(np.uint8), "RGB")


def brick():
    alb = np.zeros((N, N, 3), np.float32)
    h = np.zeros((N, N), np.float32)
    mortar = np.array([150, 142, 128], np.float32)
    alb[:] = mortar
    bh, mortar_px, bw = 32, 5, 64
    for ri, y0 in enumerate(range(0, N, bh)):
        off = (bw // 2) if (ri % 2) else 0
        for x0 in range(-bw, N, bw):
            x = x0 + off
            base = np.array([150 + rng.uniform(-22, 18),
                             72 + rng.uniform(-16, 14),
                             56 + rng.uniform(-12, 12)], np.float32)
            for xx in range(x + mortar_px // 2, x + bw - mortar_px // 2):
                for yy in range(y0 + mortar_px // 2, y0 + bh - mortar_px // 2):
                    xi, yi = xx % N, yy % N
                    # subtle within-brick mottling
                    alb[yi, xi] = np.clip(base + rng.uniform(-8, 8), 20, 235)
                    h[yi, xi] = 1.0
    # soften mortar->brick edge in the height a touch
    img = Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8), "RGB")
    img.save(os.path.join(PBR, "brick_albedo.png"))
    _normal_from_height(h).save(os.path.join(PBR, "brick_normal.png"))
    return img


def rooftile():
    alb = np.zeros((N, N, 3), np.float32)
    h = np.zeros((N, N), np.float32)
    tw, rowh = 32, 40
    for ri, y0 in enumerate(range(0, N, rowh)):
        off = (tw // 2) if (ri % 2) else 0
        for x0 in range(-tw, N, tw):
            x = x0 + off
            base = np.array([176 + rng.uniform(-20, 16),
                             92 + rng.uniform(-14, 12),
                             60 + rng.uniform(-10, 10)], np.float32)
            for xi in range(x, x + tw):
                # rounded ridge across the tile width (lighter centre)
                u = ((xi - x) / tw) * 2 - 1
                ridge = 1.0 - 0.5 * u * u
                col = np.clip(base * (0.7 + 0.45 * ridge), 20, 240)
                for yy in range(y0, y0 + rowh + 6):      # +6 overlap onto next row
                    yi = yy % N
                    v = (yy - y0) / rowh
                    shade = 1.0 if v < 0.82 else 0.6     # shadow line at the tile lip
                    alb[yi, xi % N] = col * shade
                    h[yi, xi % N] = ridge * (1.0 - 0.5 * max(0.0, v - 0.82) / 0.18)
    img = Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8), "RGB")
    img.save(os.path.join(PBR, "rooftile_albedo.png"))
    _normal_from_height(h).save(os.path.join(PBR, "rooftile_normal.png"))
    return img


def main():
    os.makedirs(PBR, exist_ok=True)
    b = brick()
    r = rooftile()
    print("wrote brick_albedo.png brick_normal.png rooftile_albedo.png rooftile_normal.png ->", PBR)
    if VIEW:
        os.makedirs(VIEW, exist_ok=True)
        # 2x2 tiled previews so the tiling reads
        for name, im in [("brick", b), ("rooftile", r)]:
            t = Image.new("RGB", (N * 2, N * 2))
            for yy in (0, N):
                for xx in (0, N):
                    t.paste(im, (xx, yy))
            t.save(os.path.join(VIEW, "tex_" + name + ".png"))


if __name__ == "__main__":
    main()
