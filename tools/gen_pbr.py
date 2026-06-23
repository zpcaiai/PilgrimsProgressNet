#!/usr/bin/env python3
"""
gen_pbr.py — procedural, tileable, photoreal-leaning PBR surface library.

All original, public-domain-safe (no external imagery). For each named surface
used by MaterialKit.gd it writes a full PBR set:

  assets/textures/pbr/<surface>_albedo.png   base colour (sRGB)
  assets/textures/pbr/<surface>_normal.png   tangent-space normal (OpenGL +Y)
  assets/textures/pbr/<surface>_rough.png    roughness (grayscale, linear)
  assets/textures/pbr/<surface>_ao.png        ambient occlusion (grayscale, linear)

…and derives relief (normal + roughness) for the chapter ground albedos.

What makes this "photoreal-leaning" rather than flat noise:
  * material-aware STRUCTURE — real running-bond brick with recessed mortar,
    irregular ashlar stone joints, overlapping roof-tile scallops, rounded
    cobbles with dark joints, plank seams + elliptical knots, cracked dry earth,
    wind ripples in sand, clumped grass, woven cloth, fibrous bark;
  * per-ELEMENT colour + height variation (every brick / stone / plank differs);
  * CREVICE ambient occlusion baked from a wide cavity of the height field, so
    joints and pits self-shadow the way photographed surfaces do;
  * material-correct ROUGHNESS (polished marble/gold low; mortar & grout high;
    damp lows slightly glossier), with fine breakup so highlights shimmer;
  * multi-octave micro-normal on top of the macro structure for close-up bite.

Every map is periodic (FFT noise + wrapped Worley + tiled lattices) so it tiles
seamlessly. Maps are existence-checked by AssetLib, so any subset is fine.

Usage:  python3 tools/gen_pbr.py [surfaces|ground|all] [SIZE]
Requires: numpy, Pillow.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
PBR = os.path.join(ROOT, "assets", "textures", "pbr")
GROUND = os.path.join(ROOT, "assets", "textures", "ground")
SIZE = 1024


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
    return norm01(acc)


def norm01(a):
    a = a - a.min()
    mx = a.max()
    return a / mx if mx > 1e-9 else a


def blur(a, radius):
    """Wrapped Gaussian blur via FFT (keeps tiling)."""
    n = a.shape[0]
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    g = np.exp(-2.0 * (math.pi ** 2) * (radius ** 2) * (fx ** 2 + fy ** 2))
    return np.fft.ifft2(np.fft.fft2(a) * g).real


# ---------------------------------------------------------------------------
# Periodic Worley / cellular  (rounded stones, blocks, clods)
# ---------------------------------------------------------------------------
def worley(size, cells, seed, jitter=0.85):
    """Returns (f1, f2, cell_id) — nearest & 2nd-nearest distances (normalised by
    cell size) and an integer id of the nearest feature point. Periodic."""
    rng = np.random.default_rng(seed)
    gx, gy = np.meshgrid(np.arange(cells), np.arange(cells))
    px = (gx + 0.5 + jitter * (rng.random((cells, cells)) - 0.5)) / cells
    py = (gy + 0.5 + jitter * (rng.random((cells, cells)) - 0.5)) / cells
    ids = (gy * cells + gx).astype(np.int32)
    yy, xx = np.mgrid[0:size, 0:size] / float(size)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    cid = np.zeros((size, size), np.int32)
    for j in range(cells):
        for i in range(cells):
            for ox in (-1.0, 0.0, 1.0):
                for oy in (-1.0, 0.0, 1.0):
                    dx = xx - (px[j, i] + ox)
                    dy = yy - (py[j, i] + oy)
                    d = np.sqrt(dx * dx + dy * dy)
                    closer = d < f1
                    f2 = np.where(closer, f1, np.minimum(f2, d))
                    cid = np.where(closer, ids[j, i], cid)
                    f1 = np.where(closer, d, f1)
    return f1 * cells, f2 * cells, cid


def cell_random(cid, seed):
    """A stable per-cell random value in [0,1) for colour/height variation."""
    rng = np.random.default_rng(seed)
    lut = rng.random(int(cid.max()) + 1)
    return lut[cid]


# ---------------------------------------------------------------------------
# Map encoders
# ---------------------------------------------------------------------------
def height_to_normal(h, strength=2.5):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], -1)
    return Image.fromarray((out * 255).astype("uint8"), "RGB")


def ao_bake(h, wide=14.0, deep=2.2):
    """Crevice AO: where the surface sits below its local average it is occluded.
    Combined wide + narrow cavity gives both joint shadow and pit shadow."""
    cav = (blur(h, wide) - h) * deep + (blur(h, 4.0) - h) * deep
    ao = np.clip(1.0 - np.clip(cav, 0, 1) * 0.9, 0.0, 1.0)
    return ao


def gray(a):
    g = (np.clip(a, 0, 1) * 255).astype("uint8")
    return Image.fromarray(np.stack([g, g, g], -1), "RGB")


def rgb(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype("uint8"), "RGB")


def save(img, folder, name):
    ensure(folder)
    p = os.path.join(folder, name)
    img.save(p)
    print(f"  ok {os.path.relpath(p, ROOT)}")


# ---------------------------------------------------------------------------
# Material-aware height + colour fields. Each returns (h, extra) where extra is
# a dict that may carry {joint, cid, cvar, tint(HxWx3 multiplier)}.
# ---------------------------------------------------------------------------
def m_brick(seed, rows=8, aspect=2.4, mortar=0.06):
    sz = SIZE
    y = np.linspace(0, rows, sz, endpoint=False)[:, None].repeat(sz, 1)
    row = np.floor(y).astype(int)
    fy = y - row
    cols = max(2, int(round(rows * (sz / sz) / aspect * aspect)))  # ~rows*? keep simple
    cols = int(round(rows * aspect / 1.0))
    offset = (row % 2) * 0.5
    x = (np.linspace(0, cols, sz, endpoint=False)[None, :].repeat(sz, 0) + offset)
    col = np.floor(x).astype(int)
    fx = x - col
    cid = (row * 9973 + col * 131) % 100003
    # mortar mask: near brick edges in u or v
    m = (np.minimum(fx, 1 - fx) < mortar * aspect) | (np.minimum(fy, 1 - fy) < mortar)
    joint = m.astype(np.float32)
    # brick face: gently domed, each brick a slightly different height
    dome = 1.0 - ((fx - 0.5) ** 2 + (fy - 0.5) ** 2) * 0.6
    hv = cell_random(cid.astype(np.int32) % 99991, seed) * 0.18
    micro = fbm(sz, 5, 2.2, seed + 3) * 0.10
    h = dome * 0.7 + 0.3 + hv + micro
    h = np.where(joint > 0, blur(h, 1.0) * 0.45, h)  # recessed mortar
    cvar = cell_random(cid.astype(np.int32) % 99991, seed + 7)  # per-brick colour
    return norm01(h), {"joint": joint, "cvar": cvar, "micro": micro}


def m_ashlar(seed, cells=6):
    f1, f2, cid = worley(SIZE, cells, seed, jitter=0.9)
    joint = np.clip(1.0 - (f2 - f1) * 3.5, 0, 1)  # bright at block borders
    block = 1.0 - f1 * 0.5
    micro = fbm(SIZE, 5, 2.1, seed + 9) * 0.16
    hv = (cell_random(cid, seed + 2) - 0.5) * 0.18
    h = block + hv + micro
    h = h * (1.0 - joint * 0.8)  # recess the mortar lines
    cvar = cell_random(cid, seed + 5)
    return norm01(h), {"joint": joint, "cvar": cvar, "micro": micro}


def m_cobble(seed, cells=9):
    f1, f2, cid = worley(SIZE, cells, seed, jitter=0.7)
    dome = np.clip(1.0 - f1 * 1.05, 0, 1) ** 0.6  # rounded stone tops
    joint = np.clip(1.0 - (f2 - f1) * 4.0, 0, 1)
    micro = fbm(SIZE, 5, 2.2, seed + 4) * 0.14
    h = dome * (1.0 - joint * 0.9) + micro * dome
    cvar = cell_random(cid, seed + 6)
    return norm01(h), {"joint": joint, "cvar": cvar, "micro": micro}


def m_wood(seed, planks=5):
    sz = SIZE
    x = np.linspace(0, 1, sz, endpoint=False)[None, :].repeat(sz, 0)
    grain = fbm(sz, 6, 2.6, seed)
    rings = norm01(np.abs(np.sin((x * 22 + grain * 5.0) * math.pi)))
    seam = np.abs(((np.linspace(0, planks, sz, endpoint=False)) % 1.0) - 0.5)[:, None].repeat(sz, 1)
    plankmask = norm01(1.0 - np.clip(seam * 10 - 3.5, 0, 1))
    pid = np.floor(np.linspace(0, planks, sz, endpoint=False))[:, None].repeat(sz, 1).astype(np.int32)
    # knots
    rng = np.random.default_rng(seed + 30)
    knot = np.zeros((sz, sz))
    yy, xx = np.mgrid[0:sz, 0:sz] / float(sz)
    for _ in range(5):
        kx, ky, kr = rng.random(), rng.random(), rng.uniform(0.02, 0.05)
        d = np.sqrt(((xx - kx + 0.5) % 1 - 0.5) ** 2 + ((yy - ky + 0.5) % 1 - 0.5) ** 2)
        knot += np.clip(1.0 - d / kr, 0, 1) ** 2
    h = norm01(rings * 0.55 + grain * 0.3) * 0.8 + plankmask * 0.2 - knot * 0.25
    cvar = cell_random(pid % 9991, seed + 8)
    return norm01(h), {"grain": rings, "cvar": cvar, "seam": 1.0 - plankmask, "knot": np.clip(knot, 0, 1)}


def m_rooftile(seed, rows=9, cols=14):
    sz = SIZE
    x = np.linspace(0, cols, sz, endpoint=False)[None, :].repeat(sz, 0)
    y = np.linspace(0, rows, sz, endpoint=False)[:, None].repeat(sz, 1)
    rowi = np.floor(y).astype(int)
    fy = y - rowi
    fx = (x + (rowi % 2) * 0.5) % 1.0
    # half-cylinder scallops, each row overlaps the one below
    scallop = np.sqrt(np.clip(1.0 - (2 * (fx - 0.5)) ** 2, 0, 1))
    lip = np.clip(1.0 - fy * 1.4, 0, 1) ** 0.5
    h = scallop * 0.6 + lip * 0.4
    micro = fbm(sz, 4, 2.2, seed + 2) * 0.08
    cid = (rowi * 97 + np.floor(x).astype(int)) % 9991
    cvar = cell_random(cid.astype(np.int32), seed + 9)
    return norm01(h + micro), {"cvar": cvar}


def m_cracked(seed, cells=7):
    f1, f2, cid = worley(SIZE, cells, seed, jitter=0.95)
    crack = np.clip(1.0 - (f2 - f1) * 6.0, 0, 1)
    clod = 1.0 - f1 * 0.4
    micro = fbm(SIZE, 6, 2.0, seed + 3) * 0.22
    h = clod + micro
    h = h * (1.0 - crack * 0.85)
    cvar = cell_random(cid, seed + 4)
    return norm01(h), {"joint": crack, "cvar": cvar}


def m_sand(seed):
    base = fbm(SIZE, 6, 2.0, seed)
    x = np.linspace(0, 1, SIZE, endpoint=False)[None, :].repeat(SIZE, 0)
    y = np.linspace(0, 1, SIZE, endpoint=False)[:, None].repeat(SIZE, 1)
    ripple = 0.5 + 0.5 * np.sin((y * 18 + base * 5.0 + np.sin(x * 6) * 0.6) * math.pi)
    grain = fbm(SIZE, 7, 1.7, seed + 11)
    h = ripple * 0.5 + base * 0.3 + grain * 0.2
    return norm01(h), {"grain": grain}


def m_grass(seed):
    clump = fbm(SIZE, 5, 1.9, seed)
    blades = fbm(SIZE, 7, 1.4, seed + 21)
    patch = fbm(SIZE, 3, 2.6, seed + 5)  # large patches of colour
    h = norm01(clump * 0.6 + blades * 0.4)
    return h, {"patch": patch, "blades": blades}


def m_marble(seed):
    base = fbm(SIZE, 6, 2.7, seed)
    x = np.linspace(0, 1, SIZE, endpoint=False)[None, :].repeat(SIZE, 0)
    veins = np.abs(np.sin((x * 4 + base * 7.0) * math.pi))
    vein_mask = np.clip(1.0 - veins * 2.0, 0, 1)
    h = norm01(1.0 - veins * 0.5 + base * 0.2)
    return h, {"vein": vein_mask}


def m_cloth(seed):
    sz = SIZE
    u = np.linspace(0, 1, sz, endpoint=False)
    warp = 0.5 + 0.5 * np.sin(u * 2 * math.pi * 64)[None, :].repeat(sz, 0)
    weft = 0.5 + 0.5 * np.sin(u * 2 * math.pi * 64)[:, None].repeat(sz, 1)
    weave = np.maximum(warp, weft) * 0.5 + (warp * weft) * 0.5
    micro = fbm(sz, 4, 2.0, seed) * 0.3
    return norm01(weave * 0.7 + micro * 0.3), {}


def m_bark(seed):
    sz = SIZE
    y = np.linspace(0, 1, sz, endpoint=False)[:, None].repeat(sz, 1)
    ridges = fbm(sz, 6, 2.3, seed)
    furrow = np.abs(np.sin((ridges * 7.0 + y * 2.0) * math.pi))
    h = norm01(1.0 - furrow * 0.7 + fbm(sz, 5, 2.0, seed + 2) * 0.3)
    return h, {"joint": np.clip(furrow, 0, 1)}


def m_fbm(seed, beta):
    return fbm(SIZE, 6, beta, seed), {}


# ---------------------------------------------------------------------------
# Surface library  (matches MaterialKit.SURFACES)
# ---------------------------------------------------------------------------
def C(*v):
    return np.array(v, dtype=np.float32)


SURF = {
    # name: dict(color, pattern, fn-args, rough(lo,hi), nrm, var, accent)
    "stone":       dict(color=C(0.50, 0.49, 0.47), pat="ashlar", rough=(0.74, 0.95), nrm=3.0, var=0.10, accent=C(0.42,0.41,0.39)),
    "mossy_stone": dict(color=C(0.40, 0.45, 0.36), pat="ashlar", rough=(0.80, 0.97), nrm=3.0, var=0.18, accent=C(0.30,0.40,0.26)),
    "cobble":      dict(color=C(0.46, 0.44, 0.42), pat="cobble", rough=(0.70, 0.93), nrm=3.4, var=0.16, accent=C(0.34,0.33,0.31)),
    "brick":       dict(color=C(0.62, 0.30, 0.24), pat="brick",  rough=(0.78, 0.95), nrm=3.0, var=0.20, accent=C(0.80,0.78,0.72)),
    "rooftile":    dict(color=C(0.55, 0.27, 0.20), pat="rooftile", rough=(0.66, 0.88), nrm=2.6, var=0.16, accent=C(0.36,0.20,0.16)),
    "marble":      dict(color=C(0.88, 0.87, 0.85), pat="marble", rough=(0.12, 0.34), nrm=1.0, var=0.05, accent=C(0.55,0.55,0.58)),
    "gold":        dict(color=C(1.00, 0.78, 0.34), pat="fbm:3.0", rough=(0.18, 0.42), nrm=0.8, var=0.05, accent=C(0.85,0.6,0.2), metal=True),
    "mud":         dict(color=C(0.30, 0.24, 0.18), pat="cracked", rough=(0.45, 0.72), nrm=2.4, var=0.12, accent=C(0.20,0.16,0.12)),
    "grass":       dict(color=C(0.30, 0.46, 0.22), pat="grass",  rough=(0.84, 0.99), nrm=2.0, var=0.22, accent=C(0.42,0.40,0.20)),
    "dry_earth":   dict(color=C(0.54, 0.44, 0.30), pat="cracked", rough=(0.84, 0.99), nrm=2.2, var=0.16, accent=C(0.36,0.28,0.18)),
    "sand":        dict(color=C(0.74, 0.65, 0.46), pat="sand",   rough=(0.86, 0.99), nrm=1.6, var=0.08, accent=C(0.62,0.52,0.36)),
    "wood":        dict(color=C(0.45, 0.30, 0.18), pat="wood",   rough=(0.55, 0.82), nrm=2.0, var=0.14, accent=C(0.28,0.18,0.10)),
    "bark":        dict(color=C(0.30, 0.22, 0.16), pat="bark",   rough=(0.82, 0.97), nrm=3.2, var=0.16, accent=C(0.18,0.13,0.09)),
    "ash":         dict(color=C(0.21, 0.20, 0.21), pat="fbm:1.9", rough=(0.85, 0.98), nrm=2.0, var=0.10, accent=C(0.10,0.10,0.10)),
    "cloth":       dict(color=C(0.52, 0.30, 0.30), pat="cloth",  rough=(0.86, 0.99), nrm=1.4, var=0.08, accent=C(0.40,0.22,0.22)),
    "foliage":     dict(color=C(0.28, 0.48, 0.23), pat="grass",  rough=(0.82, 0.97), nrm=1.6, var=0.24, accent=C(0.18,0.34,0.16)),
    "water":       dict(color=C(0.18, 0.30, 0.35), pat="fbm:3.0", rough=(0.02, 0.12), nrm=1.2, var=0.05, accent=C(0.12,0.22,0.28)),
}


def make_height(pat, seed):
    if pat == "ashlar":
        return m_ashlar(seed)
    if pat == "cobble":
        return m_cobble(seed)
    if pat == "brick":
        return m_brick(seed)
    if pat == "rooftile":
        return m_rooftile(seed)
    if pat == "wood":
        return m_wood(seed)
    if pat == "bark":
        return m_bark(seed)
    if pat == "cracked":
        return m_cracked(seed)
    if pat == "sand":
        return m_sand(seed)
    if pat == "grass":
        return m_grass(seed)
    if pat == "marble":
        return m_marble(seed)
    if pat == "cloth":
        return m_cloth(seed)
    if pat.startswith("fbm:"):
        return m_fbm(seed, float(pat.split(":")[1]))
    return m_fbm(seed, 2.0)


def build_surface(name, p):
    color = p["color"]
    accent = p.get("accent", color * 0.7)
    seed = (abs(hash(name)) % 9000) + 1
    h, extra = make_height(p["pat"], seed)

    # ---- albedo: base, shaded by height, with per-element + drift variation ----
    shade = 0.74 + 0.42 * h
    alb = np.repeat(color[None, None, :], SIZE, 0).repeat(SIZE, 1) * shade[..., None]

    # low-frequency colour drift toward the accent (weathering / patches)
    drift = norm01(fbm(SIZE, 3, 2.6, seed + 101))
    alb = alb * (1 - p["var"] * drift[..., None]) + accent[None, None, :] * (p["var"] * drift[..., None])

    # per-element hue/value variation (bricks, stones, planks, tiles each differ)
    if "cvar" in extra:
        cv = (extra["cvar"] - 0.5) * (0.5 * p["var"] + 0.10)
        alb = np.clip(alb * (1.0 + cv[..., None]), 0, 1)
    # darken joints/cracks/seams toward accent
    for k in ("joint", "seam"):
        if k in extra:
            jm = np.clip(extra[k], 0, 1)
            alb = alb * (1 - 0.55 * jm[..., None]) + accent[None, None, :] * (0.55 * jm[..., None])
    # special: grass colour patches; knots darken wood; veins lighten marble
    if "patch" in extra:
        dry = C(0.55, 0.50, 0.24)
        alb = alb * (1 - 0.35 * extra["patch"][..., None]) + dry[None, None, :] * (0.35 * extra["patch"][..., None])
    if "knot" in extra:
        alb = np.clip(alb * (1.0 - 0.5 * extra["knot"][..., None]), 0, 1)
    if "vein" in extra:
        alb = np.clip(alb + 0.10 * extra["vein"][..., None], 0, 1)
    # fine grain breakup everywhere
    grain = (fbm(SIZE, 6, 1.7, seed + 202) - 0.5) * 0.06
    alb = np.clip(alb + grain[..., None], 0, 1)

    # ---- normal ----
    nrm_img = height_to_normal(h, p["nrm"])

    # ---- roughness: material range driven by height, joints rougher, grain ----
    lo, hi = p["rough"]
    rough = lo + (hi - lo) * (1.0 - h)
    if "joint" in extra:
        rough = np.clip(rough + 0.10 * np.clip(extra["joint"], 0, 1), 0, 1)
    rough = np.clip(rough + (fbm(SIZE, 5, 1.8, seed + 303) - 0.5) * 0.05, 0, 1)

    # ---- ambient occlusion: crevice cavity + joint darkening ----
    ao = ao_bake(h)
    if "joint" in extra:
        ao = np.clip(ao * (1.0 - 0.5 * np.clip(extra["joint"], 0, 1)), 0, 1)
    ao = np.clip(ao * (0.6 + 0.4 * h), 0, 1)

    save(rgb(alb), PBR, f"{name}_albedo.png")
    save(nrm_img, PBR, f"{name}_normal.png")
    save(gray(rough), PBR, f"{name}_rough.png")
    save(gray(ao), PBR, f"{name}_ao.png")
    if p.get("metal"):
        save(gray(np.ones((SIZE, SIZE)) * 0.95), PBR, f"{name}_metal.png")


def build_all_surfaces():
    print(f"Surfaces ({SIZE}px) -> {PBR}")
    for name, p in SURF.items():
        print(f"- {name}")
        build_surface(name, p)


# ---------------------------------------------------------------------------
# Derive relief maps for the existing chapter ground albedos
# ---------------------------------------------------------------------------
def build_ground_maps():
    if not os.path.isdir(GROUND):
        return
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
        save(height_to_normal(h, 1.8), GROUND, f"{stem}_n.png")
        rough = 0.6 + 0.32 * (1.0 - h)
        save(gray(rough), GROUND, f"{stem}_r.png")


def main():
    global SIZE
    args = [a for a in sys.argv[1:]]
    mode = "all"
    for a in args:
        if a.isdigit():
            SIZE = int(a)
        else:
            mode = a
    if mode in ("surfaces", "all"):
        build_all_surfaces()
    if mode in ("ground", "all"):
        build_ground_maps()
    print("done.")


if __name__ == "__main__":
    main()
