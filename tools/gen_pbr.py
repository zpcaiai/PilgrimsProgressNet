#!/usr/bin/env python3
"""
gen_pbr.py — procedural, tileable PBR surface library for the world rebuild.

All original, public-domain-safe (no external imagery). Generates, for each
named surface used by MaterialKit.gd:

  assets/textures/pbr/<surface>_albedo.png   base colour (sRGB)
  assets/textures/pbr/<surface>_normal.png   tangent-space normal (OpenGL +Y)
  assets/textures/pbr/<surface>_rough.png    roughness (grayscale)
  assets/textures/pbr/<surface>_ao.png        ambient occlusion (grayscale)

…and derives relief maps for the 16 existing chapter ground albedos:

  assets/textures/ground/<id>_n.png           normal  (from albedo luminance)
  assets/textures/ground/<id>_r.png           roughness

Every map is periodic (FFT-based noise) so it tiles seamlessly. Maps are loaded
existence-checked by AssetLib, so any subset is fine.

Usage:  python3 tools/gen_pbr.py [surfaces|ground|all]
Requires: numpy, Pillow.

NOTE on import: for maximum fidelity set the *_normal/_rough/_ao and ground
*_n/_r textures to import as linear (sRGB off); under the painterly post-process
the default import is already visually fine.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
PBR = os.path.join(ROOT, "assets", "textures", "pbr")
GROUND = os.path.join(ROOT, "assets", "textures", "ground")
SIZE = 512


def ensure(d):
    os.makedirs(d, exist_ok=True)


# ---------------------------------------------------------------------------
# Periodic (tileable) noise
# ---------------------------------------------------------------------------
def fft_noise(size, beta=2.2, seed=0):
    r = np.random.default_rng(seed)
    white = r.standard_normal((size, size))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1e-6
    F = F / (f ** (beta / 2.0))
    out = np.fft.ifft2(F).real
    out -= out.min()
    mx = out.max()
    return out / mx if mx > 1e-9 else out


def fbm(size, octaves=5, beta=2.0, seed=0):
    acc = np.zeros((size, size))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        acc += amp * fft_noise(size, beta, seed + o * 17)
        tot += amp
        amp *= 0.55
    acc /= tot
    acc -= acc.min()
    mx = acc.max()
    return acc / mx if mx > 1e-9 else acc


def norm01(a):
    a = a - a.min()
    mx = a.max()
    return a / mx if mx > 1e-9 else a


# ---------------------------------------------------------------------------
# Map encoders
# ---------------------------------------------------------------------------
def height_to_normal(h, strength=2.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    out = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], -1)
    return Image.fromarray((out * 255).astype("uint8"), "RGB")


def gray(a):
    g = (np.clip(a, 0, 1) * 255).astype("uint8")
    return Image.fromarray(np.stack([g, g, g], -1), "RGB")


def rgb(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype("uint8"), "RGB")


def save(img, folder, name):
    ensure(folder)
    p = os.path.join(folder, name)
    img.save(p)
    print(f"  ✓ {os.path.relpath(p, ROOT)}")


# ---------------------------------------------------------------------------
# Pattern height fields
# ---------------------------------------------------------------------------
def wood_height(seed):
    x = np.linspace(0, 1, SIZE, endpoint=False)[None, :].repeat(SIZE, 0)
    grain = fbm(SIZE, 5, 2.4, seed)
    grain = norm01(np.sin((x * 26 + grain * 4.0) * math.pi))  # rings/grain along x
    planks = np.abs(((np.linspace(0, 6, SIZE, endpoint=False)) % 1.0) - 0.5)[:, None].repeat(SIZE, 1)
    planks = norm01(1.0 - np.clip(planks * 8 - 3, 0, 1))
    return norm01(grain * 0.7 + fbm(SIZE, 4, 2.0, seed + 3) * 0.3) * 0.85 + planks * 0.15


def marble_height(seed):
    base = fbm(SIZE, 6, 2.6, seed)
    x = np.linspace(0, 1, SIZE, endpoint=False)[None, :].repeat(SIZE, 0)
    veins = np.abs(np.sin((x * 5 + base * 6.0) * math.pi))
    return norm01(1.0 - veins * 0.6 + base * 0.2)


def cobble_height(seed, cells=7):
    r = np.random.default_rng(seed)
    pts = r.random((cells * cells, 2))
    yy, xx = np.mgrid[0:SIZE, 0:SIZE] / float(SIZE)
    d1 = np.full((SIZE, SIZE), 10.0)
    for (px, py) in pts:
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                dx = xx - (px + ox)
                dy = yy - (py + oy)
                d1 = np.minimum(d1, np.sqrt(dx * dx + dy * dy))
    cells_h = norm01(1.0 - d1 * cells * 0.9)
    joints = np.clip(cells_h * 1.4 - 0.2, 0, 1)
    return norm01(joints + fbm(SIZE, 4, 2.0, seed + 5) * 0.15)


def water_height(seed):
    return fbm(SIZE, 4, 3.0, seed) * 0.4


# ---------------------------------------------------------------------------
# Surface library  (matches MaterialKit.SURFACES)
#   color, beta, hstrength, rough_lo, rough_hi, var, pattern
# ---------------------------------------------------------------------------
SURF = {
    "stone":        ((0.52, 0.51, 0.50), 2.0, 2.2, 0.78, 0.96, 0.10, None),
    "mossy_stone":  ((0.44, 0.47, 0.39), 2.0, 2.2, 0.80, 0.97, 0.16, None),
    "cobble":       ((0.46, 0.44, 0.42), 2.2, 3.0, 0.75, 0.95, 0.10, "cobble"),
    "marble":       ((0.86, 0.85, 0.83), 2.8, 1.0, 0.20, 0.40, 0.08, "marble"),
    "gold":         ((0.95, 0.74, 0.34), 3.0, 0.8, 0.22, 0.40, 0.06, None),
    "mud":          ((0.31, 0.25, 0.19), 1.8, 2.4, 0.45, 0.70, 0.12, None),
    "grass":        ((0.33, 0.50, 0.25), 1.7, 1.6, 0.85, 0.99, 0.18, None),
    "dry_earth":    ((0.55, 0.45, 0.31), 1.9, 2.0, 0.85, 0.99, 0.14, None),
    "sand":         ((0.71, 0.62, 0.44), 2.4, 1.4, 0.88, 0.99, 0.08, None),
    "wood":         ((0.45, 0.31, 0.19), 2.2, 1.6, 0.62, 0.85, 0.12, "wood"),
    "bark":         ((0.31, 0.23, 0.17), 1.8, 2.6, 0.82, 0.97, 0.16, "wood"),
    "ash":          ((0.22, 0.21, 0.22), 1.9, 2.0, 0.85, 0.98, 0.10, None),
    "cloth":        ((0.50, 0.30, 0.30), 3.0, 0.8, 0.88, 0.99, 0.10, None),
    "foliage":      ((0.30, 0.50, 0.25), 1.6, 1.2, 0.85, 0.98, 0.22, None),
    "water":        ((0.20, 0.31, 0.36), 3.0, 1.4, 0.04, 0.12, 0.06, "water"),
}


def build_surface(name, params):
    color, beta, hstr, r_lo, r_hi, var, pattern = params
    seed = (abs(hash(name)) % 9000) + 1
    if pattern == "wood":
        h = wood_height(seed)
    elif pattern == "marble":
        h = marble_height(seed)
    elif pattern == "cobble":
        h = cobble_height(seed)
    elif pattern == "water":
        h = water_height(seed)
    else:
        h = fbm(SIZE, 5, beta, seed)

    # Albedo: base colour shaded by height, plus low-freq colour drift.
    shade = 0.72 + 0.5 * h
    drift = (fbm(SIZE, 3, 2.4, seed + 101) - 0.5) * var
    base = np.array(color)[None, None, :]
    alb = base * shade[..., None] + drift[..., None]
    alb = np.clip(alb, 0, 1)

    rough = r_lo + (r_hi - r_lo) * (1.0 - h)
    ao = 0.55 + 0.45 * h

    save(rgb(alb), PBR, f"{name}_albedo.png")
    save(height_to_normal(h, hstr), PBR, f"{name}_normal.png")
    save(gray(rough), PBR, f"{name}_rough.png")
    save(gray(ao), PBR, f"{name}_ao.png")


def build_all_surfaces():
    print("Surfaces ->", PBR)
    for name, params in SURF.items():
        build_surface(name, params)


# ---------------------------------------------------------------------------
# Derive relief maps for the existing chapter ground albedos
# ---------------------------------------------------------------------------
def build_ground_maps():
    print("Ground relief ->", GROUND)
    for fn in sorted(os.listdir(GROUND)):
        if not fn.endswith(".png"):
            continue
        stem = fn[:-4]
        if stem.endswith("_n") or stem.endswith("_r") or stem.endswith("_child"):
            continue
        src = Image.open(os.path.join(GROUND, fn)).convert("L").resize((SIZE, SIZE))
        src = src.filter(ImageFilter.GaussianBlur(1.2))
        h = norm01(np.asarray(src, dtype=np.float32) / 255.0)
        save(height_to_normal(h, 1.6), GROUND, f"{stem}_n.png")
        rough = 0.6 + 0.32 * (1.0 - h)
        save(gray(rough), GROUND, f"{stem}_r.png")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("surfaces", "all"):
        build_all_surfaces()
    if mode in ("ground", "all"):
        build_ground_maps()
    print("done.")


if __name__ == "__main__":
    main()
