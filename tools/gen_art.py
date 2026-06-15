#!/usr/bin/env python3
"""
gen_art.py — procedural painterly-allegorical art for "Pilgrim's Road".

Generates (all original, public-domain-safe, no external imagery):
  * assets/textures/ground/<chapter>.png   16 seamless tileable ground textures
  * assets/textures/particles/*.png         soft particle sprites
  * assets/scenes/<chapter>.png             16 chapter splash / title-card backdrops
  * assets/characters/<name>.png            12 cast portraits
  * assets/ui/*.png                         title key art + token icons
  * assets/anim/<name>.png                  flipbook sprite sheets (VFX)

Usage: python3 gen_art.py [ground|scenes|portraits|ui|anim|all]
Requires: numpy, Pillow.
"""
import os, sys, math, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
A = os.path.join(ROOT, "assets")
rng = np.random.default_rng(7)

def C(*v):  # 0-255 ints
    return tuple(int(max(0, min(255, x))) for x in v)

def save(img, *parts):
    p = os.path.join(A, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print(f"  ✓ {os.path.relpath(p, A)}  ({os.path.getsize(p)//1024} KB)")

# ---------------------------------------------------------------------------
# Painterly primitives
# ---------------------------------------------------------------------------
def vgrad(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None]
    arr = np.zeros((h, w, 3))
    for i in range(3):
        arr[..., i] = top[i] * (1 - t) + bottom[i] * t
    return Image.fromarray(arr.astype('uint8'), 'RGB').convert('RGBA')

def radial_glow(w, h, cx, cy, r, color, strength=1.0):
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    arr = np.zeros((h, w, 4))
    arr[..., 0] = color[0]; arr[..., 1] = color[1]; arr[..., 2] = color[2]
    arr[..., 3] = (a * 255)
    return Image.fromarray(arr.astype('uint8'), 'RGBA')

def fft_noise(size, beta=2.2, seed=None):
    r = np.random.default_rng(seed) if seed is not None else rng
    white = r.standard_normal((size, size))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1e-6
    F = F / (f ** (beta / 2))
    out = np.fft.ifft2(F).real
    out -= out.min(); out /= (out.max() + 1e-9)
    return out  # seamless (periodic), 0..1

def grain(img, amount=10, seed=1):
    r = np.random.default_rng(seed)
    n = (r.standard_normal((img.height, img.width, 1)) * amount)
    arr = np.asarray(img.convert('RGBA')).astype(float)
    arr[..., :3] += n
    return Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGBA')

def vignette(img, strength=0.55):
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    d = np.sqrt(((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (h / 2)) ** 2)
    v = np.clip(1 - (d - 0.6) * strength, 0, 1)
    arr = np.asarray(img.convert('RGBA')).astype(float)
    arr[..., :3] *= v[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGBA')

def soft_poly(w, h, pts, color, blur=2, alpha=255):
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=C(*color) + (alpha,))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer

def over(base, layer):
    return Image.alpha_composite(base, layer)

# ---------------------------------------------------------------------------
# Palettes per chapter: sky_top, sky_horizon, ground, light-accent
# ---------------------------------------------------------------------------
PAL = {
    "city_of_destruction":  [(50, 45, 70), (150, 90, 80), (70, 60, 65), (230, 120, 70)],
    "wilderness_road":      [(120, 130, 165), (205, 185, 150), (135, 118, 88), (235, 215, 155)],
    "slough_of_despond":    [(66, 74, 70), (112, 112, 96), (58, 54, 44), (120, 130, 105)],
    "wicket_gate":          [(86, 108, 150), (212, 192, 150), (92, 92, 102), (252, 232, 162)],
    "cross_and_tomb":       [(104, 140, 192), (255, 226, 172), (92, 102, 92), (255, 247, 214)],
    "interpreter_house":    [(58, 54, 76), (152, 110, 80), (80, 66, 60), (242, 192, 122)],
    "hill_difficulty":      [(118, 150, 182), (202, 200, 178), (122, 110, 90), (242, 230, 182)],
    "palace_beautiful":     [(128, 160, 202), (250, 220, 172), (110, 120, 110), (255, 236, 184)],
    "valley_humiliation":   [(78, 58, 70), (150, 78, 70), (68, 54, 54), (232, 92, 70)],
    "valley_shadow_death":  [(18, 20, 34), (46, 46, 66), (24, 24, 34), (122, 142, 202)],
    "vanity_fair":          [(92, 60, 112), (222, 140, 182), (110, 80, 100), (255, 202, 92)],
    "doubting_castle":      [(44, 50, 66), (82, 86, 102), (54, 54, 64), (132, 142, 162)],
    "delectable_mountains": [(118, 170, 212), (224, 236, 202), (108, 142, 90), (255, 246, 202)],
    "enchanted_ground":     [(130, 120, 152), (202, 182, 162), (112, 122, 90), (222, 202, 162)],
    "river_of_death":       [(50, 60, 92), (122, 112, 132), (52, 72, 102), (222, 212, 232)],
    "celestial_city":       [(120, 162, 222), (255, 236, 182), (182, 172, 152), (255, 250, 222)],
}
TITLES = list(PAL.keys())

# ---------------------------------------------------------------------------
# GROUND textures (seamless, tileable)
# ---------------------------------------------------------------------------
def ground_texture(name, size=512):
    base = np.array(PAL[name][2], dtype=float)
    accent = np.array(PAL[name][3], dtype=float)
    n1 = fft_noise(size, 2.4, seed=hash(name) % 999)
    n2 = fft_noise(size, 3.2, seed=(hash(name) // 7) % 999)
    n = 0.65 * n1 + 0.35 * n2
    # biome-specific structure
    if "slough" in name or "river" in name:
        n = 0.5 + 0.5 * np.sin(n * 8)  # wet ripples
    elif "delectable" in name or "enchanted" in name:
        n = n ** 1.5  # grass clumps
    elif "doubting" in name or "celestial" in name or "wicket" in name:
        # stone blocks: grid
        gx = (np.arange(size) % 64 < 4).astype(float)
        gy = (np.arange(size) % 64 < 4).astype(float)
        grid = np.maximum(gx[None, :], gy[:, None])
        n = n * 0.7 + grid * 0.3
    shade = (0.6 + 0.5 * n)[..., None]
    arr = base[None, None, :] * shade + accent[None, None, :] * (0.12 * n[..., None])
    img = Image.fromarray(np.clip(arr, 0, 255).astype('uint8'), 'RGB').convert('RGBA')
    img = grain(img, 6, seed=hash(name) % 50)
    return img

# ---------------------------------------------------------------------------
# Scene element drawers
# ---------------------------------------------------------------------------
def hills(w, h, color, base_y, amp, n=6, blur=3, alpha=255, seed=0):
    r = np.random.default_rng(seed)
    pts = [(0, h)]
    xs = np.linspace(0, w, n)
    for i, x in enumerate(xs):
        y = base_y + amp * math.sin(i * 1.3 + r.uniform(0, 3)) - r.uniform(0, amp * 0.4)
        pts.append((x, y))
    pts.append((w, h))
    return soft_poly(w, h, pts, color, blur, alpha)

def mountains(w, h, color, base_y, peak_h, blur=2, seed=0):
    r = np.random.default_rng(seed)
    pts = [(0, h)]
    x = 0
    while x < w:
        pw = r.uniform(w * 0.12, w * 0.26)
        pts.append((x, base_y))
        pts.append((x + pw / 2, base_y - peak_h * r.uniform(0.6, 1.0)))
        x += pw
        pts.append((x, base_y))
    pts.append((w, h))
    return soft_poly(w, h, pts, color, blur)

def cross(w, h, cx, cy, s, color):
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bw = s * 0.16
    d.rectangle([cx - bw / 2, cy - s, cx + bw / 2, cy + s], fill=C(*color) + (255,))
    d.rectangle([cx - s * 0.5, cy - s * 0.55, cx + s * 0.5, cy - s * 0.55 + bw], fill=C(*color) + (255,))
    return layer.filter(ImageFilter.GaussianBlur(1))

def building(w, h, x0, x1, y_top, y_base, color, roof=None):
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([x0, y_top, x1, y_base], fill=C(*color) + (255,))
    if roof == "spire":
        d.polygon([(x0, y_top), (x1, y_top), ((x0 + x1) / 2, y_top - (x1 - x0))], fill=C(*color) + (255,))
    elif roof == "dome":
        d.ellipse([x0, y_top - (x1 - x0) / 2, x1, y_top + (x1 - x0) / 2], fill=C(*color) + (255,))
    return layer.filter(ImageFilter.GaussianBlur(1))

def figure(w, h, x, y, s, color):
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon([(x - s * 0.4, y), (x + s * 0.4, y), (x + s * 0.2, y - s * 1.4), (x - s * 0.2, y - s * 1.4)], fill=C(*color) + (255,))
    d.ellipse([x - s * 0.22, y - s * 1.8, x + s * 0.22, y - s * 1.36], fill=C(*color) + (255,))
    return layer.filter(ImageFilter.GaussianBlur(1.2))

def scene(name, w=1280, h=720):
    top, hor, gnd, acc = [np.array(c, float) for c in PAL[name]]
    img = vgrad(w, h, top, hor)
    horizon = int(h * 0.62)
    # light source glow
    lx, ly = w * 0.5, horizon
    if name in ("cross_and_tomb", "celestial_city", "wicket_gate", "delectable_mountains",
                "palace_beautiful", "river_of_death"):
        lx, ly = w * 0.5, h * 0.34
        img = over(img, radial_glow(w, h, lx, ly, w * 0.6, acc, 0.9))
    elif name in ("valley_shadow_death", "doubting_castle", "valley_humiliation"):
        img = over(img, radial_glow(w, h, lx, h * 0.3, w * 0.35, acc, 0.35))
    else:
        img = over(img, radial_glow(w, h, lx, ly, w * 0.5, acc, 0.5))

    # ground plane
    g = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(g).rectangle([0, horizon, w, h], fill=C(*(gnd * 0.9)) + (255,))
    img = over(img, g.filter(ImageFilter.GaussianBlur(1)))

    far = hor * 0.55 + gnd * 0.45
    mid = gnd * 0.8
    near = gnd * 0.6

    if name == "city_of_destruction":
        for x in range(0, w, 90):
            img = over(img, building(w, h, x, x + 70, horizon - rng.integers(40, 160), horizon, mid))
        img = over(img, figure(w, h, w * 0.5, h * 0.9, 70, C(*(gnd * 0.4))))
    elif name == "wilderness_road":
        img = over(img, hills(w, h, far, horizon, 40, 6, 4, seed=1))
        road = soft_poly(w, h, [(w*0.46, horizon), (w*0.54, horizon), (w*0.75, h), (w*0.25, h)], C(*(acc*0.55)), 6)
        img = over(img, road)
    elif name == "slough_of_despond":
        img = over(img, hills(w, h, far, horizon, 25, 7, 6, seed=2))
        for _ in range(7):
            x = rng.uniform(w*0.2, w*0.8); yy = rng.uniform(horizon+30, h-40)
            img = over(img, soft_poly(w, h, [(x, yy), (x+8, yy), (x+5, yy-50), (x-2, yy-50)], C(*near), 2))
    elif name == "wicket_gate":
        img = over(img, building(w, h, w*0.42, w*0.58, horizon-220, horizon, C(*(gnd*0.5))))
        gate = Image.new('RGBA',(w,h),(0,0,0,0)); ImageDraw.Draw(gate).rectangle([w*0.46, horizon-150, w*0.54, horizon], fill=C(*acc)+(255,))
        img = over(img, gate.filter(ImageFilter.GaussianBlur(5)))
    elif name == "cross_and_tomb":
        img = over(img, hills(w, h, mid, horizon, 60, 5, 5, seed=3))
        img = over(img, cross(w, h, w*0.5, horizon-40, 150, C(*np.minimum(acc+30,255))))
    elif name == "interpreter_house":
        img = over(img, building(w, h, w*0.3, w*0.7, horizon-240, horizon, mid, roof="spire"))
        win = Image.new('RGBA',(w,h),(0,0,0,0)); ImageDraw.Draw(win).rectangle([w*0.46,horizon-120,w*0.54,horizon-40], fill=C(*acc)+(255,))
        img = over(img, win.filter(ImageFilter.GaussianBlur(4)))
    elif name == "hill_difficulty":
        img = over(img, mountains(w, h, mid, horizon+10, 260, 2, seed=4))
        path = soft_poly(w, h, [(w*0.5, horizon-180),(w*0.56, horizon-180),(w*0.7,h),(w*0.4,h)], C(*(acc*0.5)), 5)
        img = over(img, path)
    elif name == "palace_beautiful":
        img = over(img, hills(w, h, mid, horizon, 50, 4, 5, seed=5))
        for i,x in enumerate([w*0.34,w*0.5,w*0.66]):
            img = over(img, building(w, h, x-40, x+40, horizon-200-(i%2)*40, horizon, C(*(gnd*0.7)), roof="dome"))
    elif name == "valley_humiliation":
        img = over(img, mountains(w, h, C(*(gnd*0.5)), horizon, 300, 1, seed=6))
        wing = soft_poly(w, h, [(w*0.5,h*0.3),(w*0.72,h*0.22),(w*0.6,h*0.42),(w*0.5,h*0.5),(w*0.4,h*0.42),(w*0.28,h*0.22)], C(20,8,10), 6)
        img = over(img, wing)
    elif name == "valley_shadow_death":
        img = over(img, mountains(w, h, C(8,8,16), horizon-40, 360, 1, seed=7))
        img = over(img, mountains(w, h, C(4,4,10), horizon+40, 280, 1, seed=8))
        img = over(img, radial_glow(w, h, w*0.5, h*0.78, 90, acc, 0.8))
    elif name == "vanity_fair":
        for i,x in enumerate(range(60, w, 150)):
            col = [(230,90,90),(90,160,230),(240,200,80),(160,110,210)][i%4]
            img = over(img, building(w, h, x, x+110, horizon-rng.integers(80,150), horizon, col))
            ban = Image.new('RGBA',(w,h),(0,0,0,0)); ImageDraw.Draw(ban).polygon([(x,horizon-150),(x+110,horizon-150),(x+55,horizon-110)], fill=C(*col)+(255,))
            img = over(img, ban.filter(ImageFilter.GaussianBlur(1)))
    elif name == "doubting_castle":
        img = over(img, building(w, h, w*0.3, w*0.7, horizon-300, horizon, C(*(gnd*0.6))))
        for x in [w*0.3,w*0.45,w*0.55,w*0.7]:
            img = over(img, building(w, h, x-25, x+25, horizon-360, horizon-280, C(*(gnd*0.55)), roof="spire"))
    elif name == "delectable_mountains":
        img = over(img, mountains(w, h, C(*(far*0.9)), horizon, 260, 2, seed=9))
        img = over(img, mountains(w, h, C(*mid), horizon+40, 180, 2, seed=10))
        img = over(img, radial_glow(w, h, w*0.5, h*0.32, 80, C(255,250,220), 0.9))
    elif name == "enchanted_ground":
        img = over(img, hills(w, h, mid, horizon, 40, 5, 8, seed=11))
        haze = Image.new('RGBA',(w,h), C(*hor)+(70,))
        img = over(img, haze)
    elif name == "river_of_death":
        riv = Image.new('RGBA',(w,h),(0,0,0,0)); ImageDraw.Draw(riv).polygon([(0,horizon),(w,horizon),(w,h),(0,h)], fill=C(*(np.array([60,80,120])))+(255,))
        img = over(img, riv.filter(ImageFilter.GaussianBlur(2)))
        for i in range(6):
            yy = horizon + i*(h-horizon)/6
            sh = Image.new('RGBA',(w,h),(0,0,0,0)); ImageDraw.Draw(sh).line([(0,yy),(w,yy)], fill=C(*acc)+(60,), width=3)
            img = over(img, sh.filter(ImageFilter.GaussianBlur(3)))
        img = over(img, radial_glow(w, h, w*0.5, h*0.28, 70, acc, 0.8))
    elif name == "celestial_city":
        img = over(img, radial_glow(w, h, w*0.5, h*0.32, w*0.5, C(255,250,220), 1.0))
        for i,x in enumerate([w*0.36,w*0.46,w*0.54,w*0.64]):
            img = over(img, building(w, h, x-30, x+30, h*0.3-(i%2)*40, horizon, C(*np.minimum(gnd+60,255)), roof="spire"))
        # rays
        rays = Image.new('RGBA',(w,h),(0,0,0,0)); dr=ImageDraw.Draw(rays)
        for a in np.linspace(0, math.pi, 14):
            dr.line([(w*0.5,h*0.32),(w*0.5+math.cos(a)*w, h*0.32+math.sin(a)*-h)], fill=(255,250,225,30), width=8)
        img = over(img, rays.filter(ImageFilter.GaussianBlur(6)))

    # atmospheric horizon haze (depth)
    haze = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(haze).rectangle([0, horizon - 45, w, horizon + 35],
                                   fill=C(*np.minimum(hor + 12, 255)) + (75,))
    img = over(img, haze.filter(ImageFilter.GaussianBlur(30)))
    # soft bloom: blur the bright areas and add them back as glow
    rgb = np.asarray(img.convert('RGB')).astype(float)
    bright = np.clip(rgb - 150, 0, 255).astype('uint8')
    bloom = np.asarray(Image.fromarray(bright).filter(ImageFilter.GaussianBlur(16))).astype(float)
    rgb = np.clip(rgb + bloom * 0.55, 0, 255).astype('uint8')
    img = Image.fromarray(rgb, 'RGB').convert('RGBA')
    img = vignette(img, 0.5)
    img = grain(img, 5, seed=hash(name)%99)
    return img

# ---------------------------------------------------------------------------
# PORTRAITS
# ---------------------------------------------------------------------------
CHARS = {
    "pilgrim":        dict(robe=(150,110,70), trim=(110,150,90), skin=(225,190,160), halo=0.3, emblem="staff", burden=True, mood=(70,80,70), hair=(95,72,52), beard=True),
    "evangelist":     dict(robe=(235,228,200), trim=(220,180,90), skin=(228,196,166), halo=0.9, emblem="scroll", point=True, mood=(150,150,120), hair=(228,224,214), beard=True),
    "help":           dict(robe=(120,130,150), trim=(150,110,70), skin=(220,185,150), halo=0.2, emblem="rope", mood=(80,90,100), hair=(82,72,62)),
    "goodwill":       dict(robe=(110,150,110), trim=(220,200,120), skin=(226,192,162), halo=0.5, emblem="key", mood=(90,120,90), hair=(140,118,84), beard=True),
    "hopeful":        dict(robe=(120,170,210), trim=(230,230,180), skin=(230,198,168), halo=0.5, emblem="staff", mood=(110,150,190), hair=(142,110,74)),
    "apollyon":       dict(robe=(60,20,26), trim=(200,60,40), skin=(82,42,42), halo=0.0, emblem="wings", mood=(40,16,18), dark=True),
    "the_interpreter":dict(robe=(70,80,140), trim=(220,200,120), skin=(224,190,160), halo=0.6, emblem="lamp", mood=(70,70,110), hair=(206,206,214), beard=True),
    "the_shepherds":  dict(robe=(120,130,90), trim=(160,140,90), skin=(224,190,160), halo=0.3, emblem="group", mood=(100,120,80), hair=(110,95,75), beard=True),
    "watchful":       dict(robe=(120,128,140), trim=(200,205,215), skin=(222,188,158), halo=0.2, emblem="shield", mood=(90,100,120), hair=(168,172,184)),
    "obstinate":      dict(robe=(110,100,95), trim=(80,72,68), skin=(216,182,150), halo=0.0, emblem="none", mood=(80,72,70), hair=(112,102,94), beard=True),
    "pliable":        dict(robe=(190,180,110), trim=(150,160,110), skin=(224,190,160), halo=0.0, emblem="none", mood=(120,118,90), hair=(176,156,96)),
    "your_family":    dict(robe=(160,120,110), trim=(200,170,140), skin=(226,192,162), halo=0.25, emblem="family", mood=(120,90,90), hair=(120,95,75)),
}

def draw_one_figure(img, cx, base_y, s, ch):
    w, h = img.size
    robe = np.array(ch["robe"], float); trim = np.array(ch["trim"], float)
    skin = np.array(ch["skin"], float)
    hy = base_y - s * 2.12
    # robe — bell skirt (darker base) + lit upper, for painterly depth
    img = over(img, soft_poly(w, h, [(cx - s*0.62, base_y), (cx + s*0.62, base_y),
              (cx + s*0.30, base_y - s*1.55), (cx - s*0.30, base_y - s*1.55)], robe * 0.78, 3))
    img = over(img, soft_poly(w, h, [(cx - s*0.40, base_y - s*0.45), (cx + s*0.40, base_y - s*0.45),
              (cx + s*0.30, base_y - s*1.55), (cx - s*0.30, base_y - s*1.55)], robe, 2))
    # shoulder mantle + collar
    img = over(img, soft_poly(w, h, [(cx - s*0.50, base_y - s*1.40), (cx + s*0.50, base_y - s*1.40),
              (cx + s*0.32, base_y - s*1.74), (cx - s*0.32, base_y - s*1.74)], trim, 2))
    # center trim stripe
    img = over(img, soft_poly(w, h, [(cx - s*0.06, base_y - s*1.5), (cx + s*0.06, base_y - s*1.5),
              (cx + s*0.10, base_y), (cx - s*0.10, base_y)], trim * 0.88, 1))
    # neck
    img = over(img, soft_poly(w, h, [(cx - s*0.11, base_y - s*1.66), (cx + s*0.11, base_y - s*1.66),
              (cx + s*0.11, base_y - s*1.92), (cx - s*0.11, base_y - s*1.92)], skin * 0.88, 1))
    # head
    head = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(head).ellipse([cx - s*0.29, hy - s*0.35, cx + s*0.29, hy + s*0.35], fill=C(*skin) + (255,))
    img = over(img, head.filter(ImageFilter.GaussianBlur(1)))
    # hair cap
    if ch.get("hair") is not None and not ch.get("dark"):
        hc = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(hc).pieslice([cx - s*0.32, hy - s*0.42, cx + s*0.32, hy + s*0.26],
                                    180, 360, fill=C(*np.array(ch["hair"], float)) + (255,))
        img = over(img, hc.filter(ImageFilter.GaussianBlur(1.2)))
    # soft facial highlight (light from upper-left)
    img = over(img, radial_glow(w, h, cx - s*0.10, hy - s*0.10, s*0.40,
                                np.minimum(skin + 38, 255), 0.30))
    # eyes + brow
    fa = Image.new('RGBA', (w, h), (0, 0, 0, 0)); df = ImageDraw.Draw(fa)
    eye = C(*(np.array(ch["mood"], float) * 0.32))
    df.ellipse([cx - s*0.15, hy - s*0.01, cx - s*0.06, hy + s*0.07], fill=eye + (235,))
    df.ellipse([cx + s*0.06, hy - s*0.01, cx + s*0.15, hy + s*0.07], fill=eye + (235,))
    bw = max(1, int(s * 0.02))
    df.line([(cx - s*0.17, hy - s*0.06), (cx - s*0.04, hy - s*0.04)], fill=(55, 42, 38, 170), width=bw)
    df.line([(cx + s*0.04, hy - s*0.04), (cx + s*0.17, hy - s*0.06)], fill=(55, 42, 38, 170), width=bw)
    img = over(img, fa)
    # beard
    if ch.get("beard"):
        bd = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        col = np.array(ch.get("hair", (210, 210, 210)), float)
        ImageDraw.Draw(bd).polygon([(cx - s*0.21, hy + s*0.06), (cx + s*0.21, hy + s*0.06),
                  (cx + s*0.11, hy + s*0.46), (cx - s*0.11, hy + s*0.46)], fill=C(*col) + (235,))
        img = over(img, bd.filter(ImageFilter.GaussianBlur(1.6)))
    # Apollyon: horns + smouldering eyes + dark brow
    if ch.get("dark"):
        hn = Image.new('RGBA', (w, h), (0, 0, 0, 0)); dn = ImageDraw.Draw(hn)
        dn.polygon([(cx - s*0.27, hy - s*0.28), (cx - s*0.15, hy - s*0.33), (cx - s*0.30, hy - s*0.66)], fill=(28, 12, 12, 255))
        dn.polygon([(cx + s*0.27, hy - s*0.28), (cx + s*0.15, hy - s*0.33), (cx + s*0.30, hy - s*0.66)], fill=(28, 12, 12, 255))
        img = over(img, hn.filter(ImageFilter.GaussianBlur(1)))
        img = over(img, radial_glow(w, h, cx - s*0.10, hy + s*0.02, s*0.13, (255, 120, 40), 1.0))
        img = over(img, radial_glow(w, h, cx + s*0.10, hy + s*0.02, s*0.13, (255, 120, 40), 1.0))
    # rim light down one edge
    img = over(img, radial_glow(w, h, cx + s*0.5, hy + s*0.2, s*0.8, (255, 245, 210), 0.16))
    return img

def portrait(name, w=512, h=640):
    ch = CHARS[name]
    mood = np.array(ch["mood"], float)
    img = vgrad(w, h, mood*0.5, mood*0.9)
    # backdrop glow
    img = over(img, radial_glow(w, h, w*0.5, h*0.42, w*0.6, np.minimum(mood+80,255), 0.5))
    s = h * 0.27
    cx, base_y = w*0.5, h*0.92

    if ch.get("halo", 0) > 0:
        img = over(img, radial_glow(w, h, cx, h*0.32, s*1.1, (255, 245, 210), ch["halo"]))
    if ch["emblem"] == "wings":
        img = over(img, soft_poly(w, h, [(cx,h*0.3),(w*0.92,h*0.2),(w*0.7,h*0.5),(cx,h*0.55)], (40,14,16), 4))
        img = over(img, soft_poly(w, h, [(cx,h*0.3),(w*0.08,h*0.2),(w*0.3,h*0.5),(cx,h*0.55)], (40,14,16), 4))

    if ch["emblem"] == "group":
        for i, off in enumerate([-0.22, 0.0, 0.22]):
            img = draw_one_figure(img, cx + off*w, base_y - (i==1)*h*0.03, s*0.82, ch)
    elif ch["emblem"] == "family":
        for off, sc in [(-0.18, 0.8), (0.0, 1.0), (0.2, 0.6)]:
            img = draw_one_figure(img, cx + off*w, base_y, s*sc, ch)
    else:
        img = draw_one_figure(img, cx, base_y, s, ch)

    # emblems
    em = Image.new('RGBA', (w, h), (0, 0, 0, 0)); de = ImageDraw.Draw(em)
    if ch["emblem"] == "staff":
        de.line([(cx + s*0.5, base_y), (cx + s*0.5, base_y - s*2.1)], fill=C(120, 90, 60) + (255,), width=8)
    elif ch["emblem"] == "scroll":
        de.rectangle([cx + s*0.3, base_y - s*1.2, cx + s*0.62, base_y - s*0.7], fill=(235, 225, 195, 255))
    elif ch["emblem"] == "key":
        de.ellipse([cx + s*0.42, base_y - s*1.2, cx + s*0.62, base_y - s], fill=(0,0,0,0), outline=C(*ch["trim"])+(255,), width=6)
        de.line([(cx+s*0.52, base_y-s),(cx+s*0.52, base_y-s*0.6)], fill=C(*ch["trim"])+(255,), width=6)
    elif ch["emblem"] == "lamp":
        de.ellipse([cx + s*0.36, base_y - s*1.3, cx + s*0.64, base_y - s*1.0], fill=(255, 220, 150, 255))
    elif ch["emblem"] == "shield":
        de.polygon([(cx + s*0.3, base_y - s*1.3), (cx + s*0.66, base_y - s*1.3),
                    (cx + s*0.48, base_y - s*0.7)], fill=C(*ch["trim"]) + (255,))
    elif ch["emblem"] == "rope":
        de.arc([cx + s*0.3, base_y - s*1.2, cx + s*0.66, base_y - s*0.8], 0, 360, fill=C(150,120,80)+(255,), width=6)
    em = em.filter(ImageFilter.GaussianBlur(0.8))
    img = over(img, em)

    if ch.get("burden"):
        bd = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(bd).ellipse([cx - s*0.7, base_y - s*1.5, cx - s*0.2, base_y - s], fill=C(70, 55, 45) + (255,))
        img = over(img, bd.filter(ImageFilter.GaussianBlur(2)))

    img = vignette(img, 0.6)
    img = grain(img, 5, seed=hash(name) % 99)
    return img

# ---------------------------------------------------------------------------
# UI: title key art + token icons + particles
# ---------------------------------------------------------------------------
def title_key_art(w=1280, h=720):
    img = vgrad(w, h, (28, 30, 54), (120, 90, 80))
    img = over(img, radial_glow(w, h, w*0.5, h*0.3, w*0.55, (255, 235, 180), 0.9))
    img = over(img, mountains(w, h, C(40, 38, 56), int(h*0.66), 280, 2, seed=21))
    img = over(img, cross(w, h, w*0.5, h*0.62, 130, C(255, 245, 215)))
    # lone pilgrim
    img = over(img, figure(w, h, w*0.5, h*0.94, 64, C(30, 26, 30)))
    rays = Image.new('RGBA', (w, h), (0, 0, 0, 0)); dr = ImageDraw.Draw(rays)
    for a in np.linspace(0, math.pi, 12):
        dr.line([(w*0.5, h*0.3), (w*0.5 + math.cos(a)*w, h*0.3 - math.sin(a)*h)], fill=(255, 240, 200, 26), width=10)
    img = over(img, rays.filter(ImageFilter.GaussianBlur(8)))
    return vignette(grain(img, 5), 0.5)

def icon(name, w=128, h=128):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    img = over(img, radial_glow(w, h, w/2, h/2, w*0.5, (255, 240, 200), 0.5))
    d = ImageDraw.Draw(img)
    if name == "scroll":
        d.rounded_rectangle([28, 30, 100, 98], 8, fill=(235, 222, 188, 255))
        for y in (48, 62, 76):
            d.line([(40, y), (88, y)], fill=(120, 100, 70, 255), width=3)
    elif name == "seal":
        d.ellipse([30, 30, 98, 98], fill=(200, 70, 70, 255))
        d.ellipse([46, 46, 82, 82], outline=(255, 230, 200, 255), width=4)
    elif name == "garment":
        d.polygon([(64, 24), (92, 44), (84, 104), (44, 104), (36, 44)], fill=(235, 235, 220, 255))
    elif name == "key":
        d.ellipse([34, 40, 70, 76], outline=(230, 200, 110, 255), width=8)
        d.line([(60, 70), (96, 100)], fill=(230, 200, 110, 255), width=8)
        d.line([(88, 92), (98, 82)], fill=(230, 200, 110, 255), width=8)
    elif name == "burden":
        d.ellipse([30, 40, 98, 104], fill=(80, 62, 50, 255))
        d.line([(40, 56), (88, 56)], fill=(50, 38, 30, 255), width=5)
    return img

def particle(name, size=128):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c = size / 2
    if name == "soft":
        img = radial_glow(size, size, c, c, c, (255, 255, 255), 1.0)
    elif name == "mote":
        img = radial_glow(size, size, c, c, c*0.7, (255, 245, 210), 1.0)
    elif name == "spark":
        d = ImageDraw.Draw(img)
        d.line([(c, 8), (c, size-8)], fill=(255, 240, 200, 255), width=4)
        d.line([(8, c), (size-8, c)], fill=(255, 240, 200, 255), width=4)
        img = img.filter(ImageFilter.GaussianBlur(3))
        img = over(radial_glow(size, size, c, c, c*0.5, (255, 250, 220), 0.9), img)
    elif name == "dust":
        d = ImageDraw.Draw(img)
        for _ in range(12):
            x, y = rng.uniform(0, size, 2)
            d.ellipse([x-3, y-3, x+3, y+3], fill=(230, 220, 200, 120))
        img = img.filter(ImageFilter.GaussianBlur(2))
    return img

# ---------------------------------------------------------------------------
# ANIMATION sprite sheets (horizontal flipbooks)
# ---------------------------------------------------------------------------
def sheet(frames):
    fw, fh = frames[0].size
    s = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * fw, 0))
    return s

def anim_grace_glory(fr=8, sz=256):
    out = []
    for i in range(fr):
        t = i / (fr - 1)
        img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
        r = sz * (0.15 + 0.45 * t)
        a = (1 - abs(t - 0.4) * 1.4)
        img = over(img, radial_glow(sz, sz, sz/2, sz/2, r, (255, 248, 220), max(0.05, a)))
        rays = Image.new('RGBA', (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(rays)
        for k, ang in enumerate(np.linspace(0, 2*math.pi, 12, endpoint=False)):
            ang += t * 0.6
            x2 = sz/2 + math.cos(ang) * r * 1.5
            y2 = sz/2 + math.sin(ang) * r * 1.5
            d.line([(sz/2, sz/2), (x2, y2)], fill=(255, 245, 215, int(120*max(0,a))), width=4)
        out.append(over(img, rays.filter(ImageFilter.GaussianBlur(3))))
    return sheet(out)

def anim_flame(fr=8, sz=128):
    out = []
    for i in range(fr):
        img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
        sway = math.sin(i / fr * 2 * math.pi) * sz * 0.06
        tip = sz*0.15 + math.sin(i/fr*2*math.pi)*sz*0.05
        d.polygon([(sz/2 - sz*0.12, sz*0.85), (sz/2 + sz*0.12, sz*0.85),
                   (sz/2 + sway, tip)], fill=(255, 160, 60, 255))
        d.polygon([(sz/2 - sz*0.06, sz*0.85), (sz/2 + sz*0.06, sz*0.85),
                   (sz/2 + sway*0.6, tip + sz*0.18)], fill=(255, 235, 160, 255))
        img = img.filter(ImageFilter.GaussianBlur(2))
        img = over(radial_glow(sz, sz, sz/2, sz*0.6, sz*0.4, (255, 180, 90), 0.5), img)
        out.append(img)
    return sheet(out)

def anim_water(fr=8, sz=256):
    out = []
    for i in range(fr):
        ph = i / fr * 2 * math.pi
        yy, xx = np.mgrid[0:sz, 0:sz]
        wv = (np.sin(xx/22 + ph) + np.sin(yy/30 - ph) + np.sin((xx+yy)/26 + ph))
        wv = (wv - wv.min()) / (np.ptp(wv) + 1e-9)
        arr = np.zeros((sz, sz, 4))
        arr[..., 0] = 120 + wv*80; arr[..., 1] = 160 + wv*70; arr[..., 2] = 200 + wv*55
        arr[..., 3] = 120 + wv*90
        out.append(Image.fromarray(arr.astype('uint8'), 'RGBA'))
    return sheet(out)

def anim_rays(fr=8, sz=256):
    out = []
    for i in range(fr):
        img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
        rot = i / fr * (2*math.pi/12)
        for ang in np.linspace(0, 2*math.pi, 12, endpoint=False):
            ang += rot
            x2 = sz/2 + math.cos(ang)*sz; y2 = sz/2 + math.sin(ang)*sz
            d.line([(sz/2, sz/2), (x2, y2)], fill=(255, 250, 220, 40), width=10)
        img = img.filter(ImageFilter.GaussianBlur(5))
        img = over(img, radial_glow(sz, sz, sz/2, sz/2, sz*0.3, (255, 250, 225), 0.7))
        out.append(img)
    return sheet(out)

def anim_dust(fr=8, sz=128):
    pts = rng.uniform(0, sz, (16, 2))
    out = []
    for i in range(fr):
        img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
        for j, (x, y) in enumerate(pts):
            yy = (y - i * 2 - j) % sz
            d.ellipse([x-2, yy-2, x+2, yy+2], fill=(235, 225, 200, 150))
        out.append(img.filter(ImageFilter.GaussianBlur(1.5)))
    return sheet(out)

# ---------------------------------------------------------------------------
# Chat sticker packs (assets/ui/stickers/<pack>/<name>.png + manifest.json)
# ---------------------------------------------------------------------------
STICKER_FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"

PILGRIM_STICKERS = [
    ("cross", (150, 64, 64)), ("lantern", (180, 140, 60)), ("scroll", (150, 130, 80)),
    ("key", (180, 150, 70)), ("crown", (170, 140, 60)), ("dove", (90, 130, 175)),
    ("candle", (180, 120, 70)), ("shield", (90, 120, 155)), ("footprints", (120, 110, 92)),
    ("mountain", (90, 145, 120)), ("gate", (120, 122, 152)), ("heart", (172, 90, 112)),
]
EMOTE_STICKERS = [
    ("amen", "阿们", (122, 92, 152)), ("pray", "祷告", (88, 112, 162)),
    ("peace", "平安", (88, 152, 122)), ("joy", "喜乐", (200, 160, 72)),
    ("courage", "加油", (192, 100, 80)), ("together", "同行", (110, 142, 110)),
    ("watch", "警醒", (152, 112, 70)), ("hope", "盼望", (120, 150, 182)),
]


def _badge(size, color, alpha=235, radius=30):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([6, 6, size - 6, size - 6], radius, fill=C(*color) + (alpha,))
    hl = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle([6, 6, size - 6, size // 2], radius, fill=(255, 255, 255, 38))
    return over(img, hl.filter(ImageFilter.GaussianBlur(6)))


def _draw_symbol(d, name, s, W=(250, 248, 240, 255)):
    c = 64
    if name == "cross":
        d.rectangle([c - 7, 28, c + 7, 100], fill=W); d.rectangle([40, 50, 88, 62], fill=W)
    elif name == "lantern":
        d.rounded_rectangle([46, 40, 82, 92], 8, fill=W); d.rectangle([56, 30, 72, 40], fill=W)
    elif name == "scroll":
        d.rounded_rectangle([38, 36, 90, 96], 8, fill=W)
        for y in (52, 66, 80): d.line([(48, y), (80, y)], fill=(150, 120, 80, 255), width=3)
    elif name == "key":
        d.ellipse([40, 38, 72, 70], outline=W, width=8); d.line([(60, 66), (92, 98)], fill=W, width=8); d.line([(86, 92), (96, 82)], fill=W, width=8)
    elif name == "crown":
        d.polygon([(36, 86), (40, 48), (54, 70), (64, 42), (74, 70), (88, 48), (92, 86)], fill=W)
    elif name == "dove":
        d.ellipse([44, 52, 92, 76], fill=W); d.polygon([(44, 64), (24, 50), (40, 70)], fill=W); d.polygon([(70, 56), (84, 36), (80, 60)], fill=W)
    elif name == "candle":
        d.rectangle([54, 52, 74, 100], fill=W); d.ellipse([58, 30, 70, 54], fill=(255, 220, 150, 255))
    elif name == "shield":
        d.polygon([(40, 36), (88, 36), (84, 76), (64, 98), (44, 76)], fill=W)
    elif name == "footprints":
        d.ellipse([40, 44, 60, 76], fill=W); d.ellipse([70, 56, 90, 88], fill=W)
    elif name == "mountain":
        d.polygon([(28, 94), (60, 40), (92, 94)], fill=W); d.polygon([(50, 56), (60, 40), (70, 56)], fill=(120, 160, 200, 255))
    elif name == "gate":
        d.rounded_rectangle([40, 44, 88, 98], 4, fill=W); d.pieslice([40, 24, 88, 72], 180, 360, fill=W); d.rectangle([58, 60, 70, 98], fill=(90, 92, 120, 255))
    elif name == "heart":
        d.ellipse([40, 42, 66, 68], fill=W); d.ellipse([62, 42, 88, 68], fill=W); d.polygon([(43, 60), (85, 60), (64, 96)], fill=W)


def sticker_symbol(name, color, size=128):
    img = _badge(size, color)
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    _draw_symbol(ImageDraw.Draw(layer), name, size)
    return over(img, layer.filter(ImageFilter.GaussianBlur(0.6)))


def sticker_word(word, color, size=128):
    img = _badge(size, color)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype(STICKER_FONT, 50, index=2)
    except OSError:
        font = ImageFont.load_default()
    bbox = d.textbbox((0, 0), word, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, 2)]:
        d.text((x + ox, y + oy), word, font=font, fill=(40, 30, 30, 220))
    d.text((x, y), word, font=font, fill=(255, 250, 240, 255))
    return img


# Display labels for known packs; unknown packs fall back to the folder name.
STICKER_LABELS = {"pilgrim": "天路", "faces": "表情", "emote": "心情"}


def gen_stickers():
    # Generate the built-in emblem set into the 'pilgrim' pack (additive — does
    # not clash with any caption-style stickers already there).
    for nm, col in PILGRIM_STICKERS:
        save(sticker_symbol(nm, col), "ui", "stickers", "pilgrim", nm + ".png")
    rebuild_sticker_manifest()


def rebuild_sticker_manifest():
    # Build manifest.json by scanning every pack folder on disk, so packs added
    # by hand (or by other tools) are always included and never dropped.
    sdir = os.path.join(A, "ui", "stickers")
    packs = {}
    for pid in sorted(os.listdir(sdir)):
        pdir = os.path.join(sdir, pid)
        if not os.path.isdir(pdir):
            continue
        names = sorted(os.path.splitext(f)[0] for f in os.listdir(pdir)
                       if f.lower().endswith(".png"))
        if names:
            packs[pid] = {"label": STICKER_LABELS.get(pid, pid), "names": names}
    json.dump({"packs": packs}, open(os.path.join(sdir, "manifest.json"), "w"),
              ensure_ascii=False, indent=2)
    print(f"  ✓ ui/stickers/manifest.json  (packs: {list(packs.keys())})")


# ---------------------------------------------------------------------------
def main():
    g = sys.argv[1] if len(sys.argv) > 1 else "all"
    if g in ("ground", "all"):
        print("[ground]")
        for n in TITLES:
            save(ground_texture(n), "textures", "ground", n + ".png")
        for p in ("soft", "mote", "spark", "dust"):
            save(particle(p), "textures", "particles", p + ".png")
    if g in ("scenes", "all"):
        print("[scenes]")
        for n in TITLES:
            save(scene(n), "scenes", n + ".png")
    if g in ("portraits", "all"):
        print("[portraits]")
        for n in CHARS:
            save(portrait(n), "characters", n + ".png")
    if g in ("ui", "all"):
        print("[ui]")
        save(title_key_art(), "ui", "title_key_art.png")
        for n in ("scroll", "seal", "garment", "key", "burden"):
            save(icon(n), "ui", "icon_" + n + ".png")
    if g in ("stickers", "all"):
        print("[stickers]")
        gen_stickers()
    if g in ("anim", "all"):
        print("[anim]")
        save(anim_grace_glory(), "anim", "grace_glory.png")
        save(anim_flame(), "anim", "flame.png")
        save(anim_water(), "anim", "water_shimmer.png")
        save(anim_rays(), "anim", "celestial_rays.png")
        save(anim_dust(), "anim", "dust_motes.png")
    print("done.")

if __name__ == "__main__":
    main()
