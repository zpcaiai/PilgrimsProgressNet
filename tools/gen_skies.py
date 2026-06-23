#!/usr/bin/env python3
"""
gen_skies.py — procedural, seamless equirectangular sky panoramas per biome.

Writes assets/scenes/realistic/<chapter>.png, which RealisticMode loads as a
PanoramaSkyMaterial (AssetLib.realistic_backdrop). Each sky is original and
public-domain-safe: a physically-flavoured zenith->horizon gradient, a sun disc
with glow, multi-octave fbm cumulus clouds lit toward the sun, horizon haze and
a soft ground band. Periodic in longitude (x) so it wraps with no seam.

Usage:  python3 tools/gen_skies.py [W H]
Requires: numpy, Pillow.
"""
import os, math
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "scenes", "realistic")
W, H = 2048, 1024


def fft_noise(h, w, beta, seed):
    r = np.random.default_rng(seed)
    F = np.fft.fft2(r.standard_normal((h, w)))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2); f[0, 0] = 1e-6
    out = np.fft.ifft2(F / (f ** (beta / 2.0))).real
    out -= out.min(); m = out.max()
    return out / m if m > 1e-9 else out


def fbm(h, w, octaves, beta, seed):
    acc = np.zeros((h, w)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        acc += amp * fft_noise(h, w, beta, seed + o * 17); tot += amp; amp *= 0.55
    acc /= tot; acc -= acc.min(); m = acc.max()
    return acc / m if m > 1e-9 else acc


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def C(*v):
    return np.array(v, dtype=np.float32)


BIOMES = {
    "dawn":   dict(zen=C(0.30,0.45,0.72), hor=C(0.98,0.78,0.52), sun=C(1.0,0.92,0.72), su=0.5, sv=0.34,
                   sunsz=0.045, glow=0.34, cover=0.52, cc=C(1.0,0.93,0.84), cd=C(0.55,0.5,0.58),
                   haze=C(0.95,0.82,0.66), grnd=C(0.32,0.40,0.26), beta=2.4, seed=11),
    "glory":  dict(zen=C(0.45,0.55,0.78), hor=C(1.0,0.93,0.70), sun=C(1.0,0.97,0.82), su=0.5, sv=0.28,
                   sunsz=0.06, glow=0.5, cover=0.62, cc=C(1.0,0.97,0.88), cd=C(0.7,0.66,0.6),
                   haze=C(1.0,0.92,0.74), grnd=C(0.5,0.5,0.42), beta=2.5, seed=22),
    "marsh":  dict(zen=C(0.52,0.55,0.56), hor=C(0.72,0.73,0.70), sun=C(0.85,0.86,0.84), su=0.5, sv=0.30,
                   sunsz=0.0, glow=0.10, cover=0.85, cc=C(0.78,0.79,0.78), cd=C(0.5,0.52,0.53),
                   haze=C(0.7,0.72,0.68), grnd=C(0.3,0.32,0.27), beta=2.2, seed=33),
    "storm":  dict(zen=C(0.10,0.12,0.18), hor=C(0.26,0.30,0.40), sun=C(0.4,0.5,0.7), su=0.5, sv=0.42,
                   sunsz=0.0, glow=0.12, cover=0.92, cc=C(0.30,0.32,0.40), cd=C(0.08,0.09,0.13),
                   haze=C(0.22,0.26,0.34), grnd=C(0.10,0.11,0.14), beta=2.0, seed=44),
    "fire":   dict(zen=C(0.22,0.07,0.05), hor=C(0.85,0.28,0.10), sun=C(1.0,0.55,0.2), su=0.5, sv=0.40,
                   sunsz=0.0, glow=0.4, cover=0.9, cc=C(0.5,0.18,0.10), cd=C(0.14,0.05,0.05),
                   haze=C(0.7,0.25,0.10), grnd=C(0.16,0.08,0.07), beta=2.0, seed=55),
    "arid":   dict(zen=C(0.42,0.58,0.82), hor=C(0.85,0.82,0.70), sun=C(1.0,0.97,0.88), su=0.42, sv=0.22,
                   sunsz=0.05, glow=0.3, cover=0.18, cc=C(0.96,0.95,0.92), cd=C(0.7,0.7,0.68),
                   haze=C(0.9,0.85,0.72), grnd=C(0.6,0.52,0.38), beta=2.6, seed=66),
    "town":   dict(zen=C(0.55,0.56,0.58), hor=C(0.82,0.76,0.66), sun=C(0.95,0.88,0.74), su=0.5, sv=0.34,
                   sunsz=0.0, glow=0.18, cover=0.7, cc=C(0.82,0.78,0.72), cd=C(0.5,0.49,0.48),
                   haze=C(0.78,0.72,0.62), grnd=C(0.34,0.32,0.28), beta=2.3, seed=77),
    "forest": dict(zen=C(0.45,0.55,0.55), hor=C(0.86,0.80,0.55), sun=C(1.0,0.92,0.66), su=0.56, sv=0.36,
                   sunsz=0.04, glow=0.34, cover=0.55, cc=C(0.95,0.92,0.78), cd=C(0.45,0.5,0.42),
                   haze=C(0.84,0.82,0.62), grnd=C(0.26,0.34,0.22), beta=2.4, seed=88),
    "morn":   dict(zen=C(0.40,0.56,0.82), hor=C(0.92,0.80,0.80), sun=C(1.0,0.95,0.85), su=0.5, sv=0.32,
                   sunsz=0.04, glow=0.28, cover=0.4, cc=C(1.0,0.95,0.93), cd=C(0.6,0.62,0.7),
                   haze=C(0.92,0.86,0.84), grnd=C(0.34,0.4,0.3), beta=2.5, seed=99),
}

CHAPTERS = {
    "dawn": ["cross_and_tomb", "delectable_mountains", "palace_beautiful", "hill_difficulty"],
    "glory": ["celestial_city", "river_of_death"],
    "marsh": ["slough_of_despond"],
    "storm": ["valley_shadow_death", "doubting_castle"],
    "fire": ["valley_humiliation"],
    "arid": ["wilderness_road"],
    "town": ["vanity_fair", "city_of_destruction"],
    "forest": ["enchanted_ground"],
    "morn": ["wicket_gate", "interpreter_house"],
}


def render(p):
    vv = np.linspace(0, 1, H)[:, None].repeat(W, 1)      # 0 top .. 1 bottom
    uu = np.linspace(0, 1, W, endpoint=False)[None, :].repeat(H, 0)
    # base sky gradient (zenith -> horizon over the top half), ground below.
    t = smooth(0.0, 0.5, vv)
    sky = p["zen"][None, None, :] * (1 - t[..., None]) + p["hor"][None, None, :] * t[..., None]
    ground = p["hor"][None, None, :] * (1 - smooth(0.5, 0.62, vv))[..., None] + p["grnd"][None, None, :] * smooth(0.5, 0.62, vv)[..., None]
    img = np.where(vv[..., None] < 0.5, sky, ground)

    # sun direction in panorama space (wrap-aware in u).
    du = np.minimum(np.abs(uu - p["su"]), 1 - np.abs(uu - p["su"]))
    dv = vv - p["sv"]
    sd = np.sqrt((du * 2.2) ** 2 + dv ** 2)
    if p["glow"] > 0:
        g = np.exp(-(sd ** 2) / (0.16 ** 2)) * p["glow"]
        img = img + p["sun"][None, None, :] * g[..., None]
    if p["sunsz"] > 0:
        disc = smooth(p["sunsz"], p["sunsz"] * 0.6, sd)
        img = img * (1 - disc[..., None]) + p["sun"][None, None, :] * disc[..., None]

    # clouds: periodic fbm, denser near horizon, lit toward the sun.
    n = fbm(H, W, 6, p["beta"], p["seed"])
    band = smooth(0.05, 0.28, vv) * (1 - smooth(0.46, 0.52, vv))  # sky band only
    cover = np.clip((n - (1 - p["cover"])) / max(1e-3, p["cover"]), 0, 1) * band
    calpha = smooth(0.15, 0.6, cover)
    lit = np.exp(-(sd ** 2) / (0.5 ** 2))
    ccol = p["cd"][None, None, :] * (1 - lit[..., None]) + p["cc"][None, None, :] * lit[..., None]
    img = img * (1 - calpha[..., None]) + ccol * calpha[..., None]

    # horizon haze line + faint grain
    hz = np.exp(-((vv - 0.5) ** 2) / (0.02 ** 2))
    img = img * (1 - 0.5 * hz[..., None]) + p["haze"][None, None, :] * (0.5 * hz[..., None])
    img = np.clip(img + (fbm(H, W, 3, 1.6, p["seed"] + 5) - 0.5)[..., None] * 0.015, 0, 1)
    return Image.fromarray((img * 255).astype("uint8"), "RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    for biome, p in BIOMES.items():
        im = render(p)
        for cid in CHAPTERS[biome]:
            path = os.path.join(OUT, cid + ".png")
            im.save(path)
            print("  ok", os.path.relpath(path, ROOT))
    print("done.")


if __name__ == "__main__":
    main()
