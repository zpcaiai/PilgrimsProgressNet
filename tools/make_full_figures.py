#!/usr/bin/env python3
"""make_full_figures.py — turn the half-body busts into FULL-BODY figures locally.

Reads the ORIGINAL bust cutouts from assets/characters/figures_busts_backup/ (so
re-running never double-extends an already-extended figure) and synthesises a
full lower body per a per-stem MODE:
  legs   - two rounded breeches legs + gap + shoes        (the men: pilgrim, ...)
  skirt  - a single flared, folded dress to the floor     (your_family[_child])
  robe   - a draped cassock to the floor + shoe tips      (evangelist/shepherds/interpreter)
  shadow - a dissipating dark plume                        (apollyon, a monster)

Colours are sampled from a clean garment band (skin + white excluded so scrolls,
collars and the wife's children don't bleed in); shapes are shaded procedurally
(cylinder shading on legs, folds on cloth, darkening toward the floor). Output is
assets/characters/figures_full/<stem>.png; run tools/gen_full_figures.py to
rebuild assets/characters/figures/<stem>.webp.

Procedural stopgap (no AI). Drop real full-body art into figures_full/ to replace
any figure. Usage:
  python3 tools/make_full_figures.py                 # all
  python3 tools/make_full_figures.py pilgrim hopeful # a subset
Env: FIG_VIEW_DIR=<dir> writes grey-checked previews.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "assets", "characters", "figures_busts_backup")
SRC_FALLBACK = os.path.join(ROOT, "assets", "characters", "figures")
FULL = os.path.join(ROOT, "assets", "characters", "figures_full")
VIEW = os.environ.get("FIG_VIEW_DIR", "")

EXT_FRAC = 0.95
EXT_CHILD = 0.78
# Family groups: extend only a little (short skirt hem) so the wife + two
# children stay large and fully visible rather than being shrunk above a long skirt.
EXT_OVERRIDE = {"your_family": 0.42, "your_family_child": 0.42}
CHILDREN = {"pilgrim_child", "your_family_child"}
MODE = {
    "apollyon": "shadow",
    "evangelist": "robe", "the_shepherds": "robe", "the_interpreter": "robe",
    "your_family": "skirt", "your_family_child": "skirt",
}  # default -> "legs"


def _load(stem):
    p = os.path.join(SRC, stem + ".webp")
    if not os.path.exists(p):
        p = os.path.join(SRC, stem + ".png")
    if not os.path.exists(p):
        p = os.path.join(SRC_FALLBACK, stem + ".webp")
    im = Image.open(p).convert("RGBA")
    bb = im.split()[-1].getbbox()
    return im.crop(bb) if bb else im


def _skin(rgb):
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return ((R > 110) & (R < 248) & (R >= G) & (G >= B * 0.92) & ((R - B) > 16) & ((R - B) < 175))


def _white(rgb):
    return (rgb[..., 0] > 200) & (rgb[..., 1] > 200) & (rgb[..., 2] > 190)


def _garment_profile(arr, mask, l0, r0):
    H, W = mask.shape
    rgb = arr[..., :3]
    garment = mask & ~(_skin(rgb) & mask) & ~(_white(rgb) & mask)
    bh = max(12, int(H * 0.14))
    best_top, best = int(H * 0.6), -1.0
    for top in range(int(H * 0.45), H - bh, max(4, bh // 3)):
        sc = float(garment[top:top + bh, l0:r0 + 1].sum())
        if sc > best:
            best, best_top = sc, top
    top = best_top
    cols = np.arange(l0, r0 + 1)
    vals, valx = [], []
    for x in cols:
        g = garment[top:top + bh, x]
        if g.sum() >= 3:
            vals.append(np.median(arr[top:top + bh, x, :3][g], axis=0)); valx.append(x)
    if len(valx) < 2:
        base = np.median(arr[int(H * 0.6):H, l0:r0 + 1, :3].reshape(-1, 3), axis=0)
        return np.tile(base, (r0 - l0 + 1, 1))
    valx = np.array(valx); vals = np.array(vals)
    prof = np.empty((r0 - l0 + 1, 3))
    for c in range(3):
        prof[:, c] = np.interp(cols, valx, vals[:, c])
    k = max(3, int((r0 - l0) * 0.08)); pad = k // 2; ker = np.ones(k) / k
    for c in range(3):
        e = np.pad(prof[:, c], (pad, pad), mode="edge")
        prof[:, c] = np.convolve(e, ker, mode="valid")[: prof.shape[0]]
    return prof


def _row_colors(prof, width):
    P = prof.shape[0]
    idx = np.linspace(0, 1, width) * (P - 1)
    col = np.empty((width, 3))
    for c in range(3):
        col[:, c] = np.interp(idx, np.arange(P), prof[:, c])
    return col


def _fill(out, y, nl, nr, rgb):
    # rgb spans [nl..nr]; clamp to the image and trim rgb to match.
    W = out.shape[1]
    a = max(0, nl); b = min(W - 1, nr)
    if b < a:
        return
    lo = a - nl
    hi = lo + (b - a) + 1
    out[y, a:b + 1, :3] = rgb[lo:hi]
    out[y, a:b + 1, 3] = 255.0


def _legs(out, H, W, cx, hw, ext, prof, base):
    coatH = int(ext * 0.18)
    for d in range(coatH):                                   # coat hem over the thighs
        half = hw * (1.0 - 0.06 * d / max(1, coatH))
        nl, nr = int(cx - half), int(cx + half)
        w = nr - nl + 1
        if w < 3:
            continue
        col = _row_colors(prof, w)
        fold = 1.0 + 0.05 * np.sin(np.linspace(0, 3 * math.pi, w))
        _fill(out, H + d, nl, nr, np.clip(col * fold[:, None] * (1.0 - 0.10 * d / coatH), 0, 255))
    legReg = ext - coatH
    gap = hw * 0.14
    for d in range(legReg):
        y = H + coatH + d
        tt = d / max(1, legReg)
        outer = hw * 0.92 * (1.0 - 0.16 * tt)
        grad = 1.0 - 0.34 * tt
        if 0.48 < tt < 0.55:                              # knee crease
            grad *= 0.88
        for xa, xb in [(cx - outer, cx - gap * 0.5), (cx + gap * 0.5, cx + outer)]:
            a, b = int(xa), int(xb)
            w = b - a + 1
            if w < 2:
                continue
            u = np.linspace(0, 1, w)
            cyl = 1.0 - 0.42 * (2 * u - 1) ** 2           # round leg
            sheen = 0.14 * np.exp(-((u - 0.46) / 0.13) ** 2)  # bright sheen line
            shade = np.clip(cyl + sheen, 0.0, 1.3)
            _fill(out, y, a, b, np.clip(base * grad * shade[:, None], 0, 255))
    return coatH, gap


def _skirt(out, H, W, cx, hw, ext, prof):
    phase = 0.6
    for d in range(ext):
        t = d / ext
        half = hw * (1.0 + 0.42 * t)                         # A-line flare
        nl, nr = int(cx - half), int(cx + half)
        w = nr - nl + 1
        if w < 3:
            continue
        col = _row_colors(prof, w)
        fold = 1.0 + 0.11 * np.sin(np.linspace(0, 5 * math.pi, w) + phase)
        grad = 1.03 - 0.30 * t
        if t > 0.9:
            grad *= 1.0 - 0.22 * (t - 0.9) / 0.1
        _fill(out, H + d, nl, nr, np.clip(col * fold[:, None] * grad, 0, 255))


def _robe(out, H, W, cx, hw, ext, prof):
    phase = 0.2
    for d in range(ext):
        t = d / ext
        half = hw * (1.0 + 0.12 * t)
        nl, nr = int(cx - half), int(cx + half)
        w = nr - nl + 1
        if w < 3:
            continue
        col = _row_colors(prof, w)
        fold = 1.0 + 0.09 * np.sin(np.linspace(0, 4 * math.pi, w) + phase)
        grad = 1.02 - 0.28 * t
        if t > 0.9:
            grad *= 1.0 - 0.22 * (t - 0.9) / 0.1
        _fill(out, H + d, nl, nr, np.clip(col * fold[:, None] * grad, 0, 255))


def _shadow(out, H, W, cx, hw, ext, base):
    dark = base * 0.7
    for d in range(ext):
        t = d / ext
        half = max(2.0, hw * (1.0 - 0.9 * t))
        nl, nr = int(cx - half), int(cx + half)
        if nr - nl < 2:
            continue
        out[H + d, nl:nr + 1, :3] = np.clip(dark * (1.0 - 0.5 * t), 0, 255)
        out[H + d, nl:nr + 1, 3] = 255.0 * (1.0 - t) ** 1.3


def _rim_light(out, y0, y1):
    """Warm rim along the lit (right) edge + a shadowed left edge, down the new
    lower body — kills the flat-fill look and ties it to the world light."""
    warm = np.array([255, 224, 158], np.float32)
    for y in range(y0, y1):
        xs = np.where(out[y, :, 3] > 8)[0]
        if xs.size < 6:
            continue
        l, r = int(xs[0]), int(xs[-1])
        for k in range(5):
            x = r - k
            if 0 <= x < out.shape[1] and out[y, x, 3] > 8:
                f = (5 - k) / 5 * 0.55
                out[y, x, :3] = np.clip(out[y, x, :3] * (1 - f) + warm * f, 0, 255)
        for k in range(4):
            x = l + k
            if 0 <= x < out.shape[1] and out[y, x, 3] > 8:
                out[y, x, :3] = out[y, x, :3] * (1 - (4 - k) / 4 * 0.30)


def build(stem):
    im = _load(stem)
    arr = np.asarray(im).astype(np.float32)
    H, W = arr.shape[:2]
    mask = arr[..., 3] > 40
    K = max(8, int(H * 0.12))
    xs = np.where(mask[H - K:H, :].any(axis=0))[0]
    if xs.size < 2:
        xs = np.where(mask.any(axis=0))[0]
    l0, r0 = int(xs.min()), int(xs.max())
    cx = (l0 + r0) / 2.0
    hw = min((r0 - l0) / 2.0, W * 0.33)

    mode = MODE.get(stem, "legs")
    ext = int(H * EXT_OVERRIDE.get(stem, EXT_CHILD if stem in CHILDREN else EXT_FRAC))
    newH = H + ext
    out = np.zeros((newH, W, 4), np.float32)
    out[:H] = arr
    prof = _garment_profile(arr, mask, l0, r0)
    base = np.median(prof, axis=0)

    coatH, gap = (0, 0.0)
    if mode == "legs":
        coatH, gap = _legs(out, H, W, cx, hw, ext, prof, base)
    elif mode == "skirt":
        _skirt(out, H, W, cx, hw, ext, prof)
    elif mode == "robe":
        _robe(out, H, W, cx, hw, ext, prof)
    else:
        _shadow(out, H, W, cx, hw, ext, base)

    if mode != "shadow":
        _rim_light(out, H, newH)
        sub = out[H:, :, :3]                      # subtle painterly grain
        msk = out[H:, :, 3] > 8
        n = np.random.default_rng(3).normal(0, 4.0, sub.shape)
        sub[msk] += n[msk]
        np.clip(sub, 0, 255, out=sub)

    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    dr = ImageDraw.Draw(img)
    shoe = tuple(int(v) for v in np.clip(base * 0.42, 14, 95)) + (255,)
    buckle = (214, 198, 144, 255)
    if mode == "legs":
        sw, sh = hw * 0.58, ext * 0.055
        sy = newH - sh * 1.05
        for sgn in (-1, 1):
            scx = cx + sgn * (gap * 0.5 + hw * 0.42)
            dr.ellipse([scx - sw * 0.5, sy, scx + sw * 0.5, sy + sh], fill=shoe)
            dr.ellipse([scx - sw * 0.15, sy + sh * 0.12, scx + sw * 0.7, sy + sh], fill=shoe)  # toe
            dr.rectangle([scx - sw * 0.06, sy + sh * 0.16, scx + sw * 0.10, sy + sh * 0.44], fill=buckle)  # buckle
    elif mode == "robe":
        sw, sh = hw * 0.42, ext * 0.045
        sy = newH - sh * 1.05
        for sgn in (-1, 1):
            scx = cx + sgn * hw * 0.28
            dr.ellipse([scx - sw * 0.5, sy, scx + sw * 0.5, sy + sh], fill=shoe)
            dr.rectangle([scx - sw * 0.06, sy + sh * 0.18, scx + sw * 0.09, sy + sh * 0.46], fill=buckle)  # buckle

    # soften the join (subtle, no band)
    a = np.asarray(img).astype(np.float32)
    blend = max(4, int(ext * 0.035))
    y0, y1 = max(0, H - blend), min(newH, H + blend)
    strip = Image.fromarray(np.clip(a[y0:y1], 0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(2.0))
    a[y0:y1] = np.asarray(strip, np.float32)
    ach = a[..., 3].copy()
    soft = np.asarray(Image.fromarray(ach.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), np.float32)
    ach[H + blend:] = soft[H + blend:]
    a[..., 3] = ach
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

    os.makedirs(FULL, exist_ok=True)
    img.save(os.path.join(FULL, stem + ".png"))
    if VIEW:
        os.makedirs(VIEW, exist_ok=True)
        bg = Image.new("RGBA", img.size, (224, 224, 228, 255))
        bg.alpha_composite(img)
        bg.convert("RGB").save(os.path.join(VIEW, "full_view_" + stem + ".png"))
    return mode, img.size


def main():
    stems = sys.argv[1:] or sorted(
        os.path.splitext(f)[0] for f in os.listdir(SRC) if f.endswith((".webp", ".png")))
    for s in stems:
        try:
            m, sz = build(s)
            print(f"  OK {s:20s} [{m}] {sz}")
        except Exception as e:
            import traceback; traceback.print_exc(); print(f"  FAIL {s}: {e}")


if __name__ == "__main__":
    main()
