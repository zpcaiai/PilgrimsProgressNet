#!/usr/bin/env python3
"""make_title_art.py — render the title-screen key art for Pilgrim's Road.

Main.gd already shows assets/ui/title_key_art.png behind the title menu (dimmed),
so this only paints the scene; the title words/buttons are overlaid by the menu.
Oil-storybook composition: dawn sky, the Celestial City glowing in distinct
spires on a far hill, layered hills with atmospheric perspective, a winding
"way" leading to the light, and a lone pilgrim with staff + pack upon it.

Pure Pillow + numpy. Output: assets/ui/title_key_art.png
Env: TITLE_VIEW_DIR=<dir> also writes a copy for review.
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "ui", "title_key_art.png")
VIEW = os.environ.get("TITLE_VIEW_DIR", "")
W, H = 1920, 1080
rng = np.random.default_rng(7)

CX, CY = int(W * 0.52), int(H * 0.38)   # city light / sun centre


def _lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def sky():
    top, mid, horizon = (26, 36, 76), (120, 112, 152), (242, 202, 134)
    img = np.zeros((H, W, 3), np.float32)
    for y in range(H):
        t = y / (H - 1)
        c = _lerp(top, mid, t / 0.55) if t < 0.55 else _lerp(mid, horizon, (t - 0.55) / 0.45)
        img[y, :, :] = c
    return img


def add_glow(img):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt((xx - CX) ** 2 + ((yy - CY) * 1.15) ** 2)
    img += np.exp(-(d / (W * 0.30)) ** 2)[..., None] * np.array([255, 226, 150], np.float32) * 0.85
    img += np.exp(-(d / (W * 0.085)) ** 2)[..., None] * np.array([255, 246, 214], np.float32) * 0.75
    return img


def add_rays(pil):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    n = 16
    for i in range(n):
        a = math.pi * (0.06 + 0.88 * i / n)
        L = W * 1.2
        sp = 0.016
        p1 = (CX + math.cos(a - sp) * L, CY + math.sin(a - sp) * L)
        p2 = (CX + math.cos(a + sp) * L, CY + math.sin(a + sp) * L)
        dr.polygon([(CX, CY), p1, p2], fill=(255, 233, 172, 13))
    pil.alpha_composite(ov.filter(ImageFilter.GaussianBlur(7)))
    return pil


def ridge(base_y, amp, rough, color, alpha, blur=0):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    pts = [(0, H)]
    for x in np.linspace(0, W, 64):
        y = base_y - amp * (0.6 * math.sin(x * 0.0016 + rough) + 0.4 * math.sin(x * 0.004 + rough * 2.0))
        y -= rng.uniform(-amp * 0.08, amp * 0.08)
        pts.append((x, y))
    pts.append((W, H))
    dr.polygon(pts, fill=color + (alpha,))
    if blur:
        ov = ov.filter(ImageFilter.GaussianBlur(blur))
    return ov


def city(pil):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    by = int(H * 0.50)
    gold, edge = (255, 223, 150), (255, 247, 214)
    spires = [(-185, 30, 140), (-120, 44, 225), (-58, 36, 300),
              (4, 52, 358), (66, 38, 290), (124, 46, 220), (182, 30, 140)]
    for dx, w, h in spires:
        cx0 = CX + dx
        x0, x1, top = cx0 - w // 2, cx0 + w // 2, by - h
        dr.rectangle([x0, top, x1, by], fill=gold + (255,))
        dr.polygon([(x0 - 3, top), (x1 + 3, top), (cx0, top - int(w * 1.5))], fill=edge + (255,))
    # cross atop the tallest spire (dx=4, h=358, w=52)
    tx = CX + 4
    ttop = by - 358 - int(52 * 1.5)
    dr.line([(tx, ttop - 42), (tx, ttop - 6)], fill=edge + (255,), width=5)
    dr.line([(tx - 15, ttop - 28), (tx + 15, ttop - 28)], fill=edge + (255,), width=5)
    pil.alpha_composite(ov.filter(ImageFilter.GaussianBlur(22)))
    pil.alpha_composite(ov)
    return pil


def road(pil):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    steps = 70
    for i in range(steps):
        t = i / (steps - 1)
        x = W * 0.46 + math.sin(t * math.pi * 1.3) * W * 0.055 * (1 - t) + (CX - 6 - W * 0.46) * t
        y = H * 0.995 + (H * 0.60 - H * 0.995) * t
        r = 58 * (1 - t) ** 1.2 + 5
        a = int(150 + 70 * t)  # brighter as it nears the light
        dr.ellipse([x - r, y - r * 0.42, x + r, y + r * 0.42], fill=(232, 210, 162, a))
    pil.alpha_composite(ov.filter(ImageFilter.GaussianBlur(5)))
    return pil


def pilgrim(pil):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    fx, fy = int(W * 0.435), int(H * 0.90)
    s = H * 0.016
    body = (36, 32, 44)
    dr.polygon([(fx, fy - 17 * s), (fx - 6 * s, fy), (fx + 6 * s, fy)], fill=body + (255,))
    dr.ellipse([fx - 6 * s, fy - 3 * s, fx + 6 * s, fy + 2 * s], fill=body + (255,))
    dr.ellipse([fx - 8.5 * s, fy - 13 * s, fx - 1.5 * s, fy - 5 * s], fill=(28, 25, 34, 255))  # pack
    dr.ellipse([fx - 2.4 * s, fy - 21 * s, fx + 2.4 * s, fy - 16 * s], fill=body + (255,))      # head
    dr.line([(fx + 4.5 * s, fy - 20 * s), (fx + 7.5 * s, fy + 1 * s)], fill=(24, 21, 28, 255), width=max(2, int(s)))
    rim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(rim).line([(fx + 2.4 * s, fy - 19 * s), (fx + 5 * s, fy - 2 * s)],
                             fill=(255, 226, 154, 190), width=max(2, int(s * 0.7)))
    pil.alpha_composite(ov)
    pil.alpha_composite(rim.filter(ImageFilter.GaussianBlur(1.4)))
    return pil


def vignette(img):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    v = np.clip(1.0 - 0.55 * np.clip(d - 0.35, 0, 1) ** 1.8, 0.25, 1.0)
    return img * v[..., None]


def main():
    base = add_glow(sky())
    pil = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    pil = add_rays(pil)
    pil.alpha_composite(ridge(H * 0.60, 70, 1.1, (150, 150, 185), 150, blur=3))
    pil.alpha_composite(ridge(H * 0.66, 95, 2.3, (96, 104, 140), 190, blur=2))
    pil = city(pil)
    pil.alpha_composite(ridge(H * 0.74, 130, 0.7, (54, 66, 92), 235, blur=1))
    pil.alpha_composite(ridge(H * 0.86, 150, 3.1, (28, 34, 50), 255))
    pil = road(pil)
    pil = pilgrim(pil)
    arr = vignette(np.asarray(pil.convert("RGB")).astype(np.float32))
    arr += rng.normal(0, 4.0, arr.shape)
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", OUT, out.size)
    if VIEW:
        os.makedirs(VIEW, exist_ok=True)
        out.save(os.path.join(VIEW, "title_key_art_view.png"))


if __name__ == "__main__":
    main()
