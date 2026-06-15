#!/usr/bin/env python3
"""Generate placeholder sticker PNGs for the built-in chat sticker packs.

Reads assets/ui/stickers/manifest.json and draws a simple, recognizable 256x256
RGBA sticker for every <pack>/<name>, writing it to
assets/ui/stickers/<pack>/<name>.png. Known icon names (cross, dove, heart,
key, ...) are drawn as little white symbol glyphs; unknown names fall back to a
monogram. Re-runnable. Replace any with final art using the same name.

Usage:
    python3 tools/gen_sticker_placeholders.py              # generate/overwrite
    python3 tools/gen_sticker_placeholders.py --skip-existing
    python3 tools/gen_sticker_placeholders.py --prune      # also delete PNGs /
                                                            # pack folders not in
                                                            # the manifest

Requires Pillow (pip install pillow).
"""
import argparse
import colorsys
import hashlib
import json
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required: pip install pillow")

SIZE = 256
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STICKER_DIR = os.path.join(ROOT, "assets", "ui", "stickers")
W = (255, 255, 255, 255)
ACCENT = (70, 90, 120, 255)  # set per-sticker for contrast on white glyphs


def _font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
              "/System/Library/Fonts/Supplemental/Arial.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def _hue(name):
    return (int(hashlib.md5(name.encode("utf-8")).hexdigest(), 16) % 360) / 360.0


def _rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def _bg(hue):
    top, bot = _rgb(hue, 0.55, 0.95), _rgb(hue, 0.65, 0.68)
    pad, rad = 12, 44
    grad = Image.new("RGB", (1, SIZE))
    for y in range(SIZE):
        t = y / SIZE
        grad.putpixel((0, y), tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    grad = grad.resize((SIZE, SIZE))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([pad, pad, SIZE - pad, SIZE - pad], radius=rad, fill=255)
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    base.paste(grad, (0, 0), mask)
    ImageDraw.Draw(base).rounded_rectangle([pad, pad, SIZE - pad, SIZE - pad], radius=rad,
                                           outline=(255, 255, 255, 230), width=6)
    return base


def _label(draw, name):
    f = _font(28)
    txt = name.replace("_", " ")
    while draw.textlength(txt, font=f) > SIZE - 36 and f.size > 13:
        f = _font(f.size - 2)
    x = (SIZE - draw.textlength(txt, font=f)) / 2
    y = SIZE - 48
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        draw.text((x + dx, y + dy), txt, font=f, fill=(0, 0, 0, 160))
    draw.text((x, y), txt, font=f, fill=(255, 255, 255, 255))


# --- symbol glyphs (drawn white on the coloured background) -----------------
def s_cross(d):
    d.rectangle([118, 40, 138, 188], fill=W); d.rectangle([84, 84, 172, 104], fill=W)

def s_heart(d):
    d.ellipse([72, 60, 124, 112], fill=W); d.ellipse([116, 60, 168, 112], fill=W)
    d.polygon([(78, 96), (162, 96), (120, 168)], fill=W)

def s_key(d):
    d.ellipse([82, 60, 142, 120], outline=W, width=16)
    d.rectangle([104, 112, 118, 184], fill=W)
    d.rectangle([118, 160, 140, 174], fill=W); d.rectangle([118, 136, 134, 150], fill=W)

def s_crown(d):
    d.polygon([(74, 164), (74, 100), (102, 134), (128, 86), (154, 134), (182, 100), (182, 164)], fill=W)
    d.rectangle([74, 162, 182, 184], fill=W)

def s_lantern(d):
    d.arc([108, 36, 148, 80], 180, 360, fill=W, width=8)
    d.rectangle([92, 64, 164, 78], fill=W)
    d.rounded_rectangle([98, 76, 158, 168], radius=12, fill=W)
    d.ellipse([114, 98, 142, 142], fill=(255, 205, 110, 255))
    d.rectangle([92, 166, 164, 182], fill=W)

def s_scroll(d):
    d.rounded_rectangle([86, 88, 170, 156], radius=8, fill=W)
    d.ellipse([74, 82, 100, 162], fill=(232, 232, 232, 255))
    d.ellipse([156, 82, 182, 162], fill=(232, 232, 232, 255))

def s_dove(d):
    d.ellipse([92, 100, 166, 148], fill=W)
    d.ellipse([150, 88, 182, 120], fill=W)
    d.polygon([(108, 116), (150, 64), (150, 126)], fill=(235, 235, 235, 255))
    d.polygon([(94, 116), (66, 104), (76, 140)], fill=W)
    d.polygon([(180, 100), (198, 106), (180, 114)], fill=(255, 200, 80, 255))

def s_candle(d):
    d.rectangle([116, 92, 140, 186], fill=W)
    d.polygon([(128, 46), (144, 82), (128, 98), (112, 82)], fill=(255, 175, 65, 255))
    d.polygon([(128, 62), (135, 82), (128, 94), (121, 82)], fill=(255, 230, 150, 255))

def s_shield(d):
    d.polygon([(128, 42), (186, 68), (186, 118), (128, 192), (70, 118), (70, 68)], fill=W)
    d.rectangle([121, 74, 135, 158], fill=ACCENT); d.rectangle([98, 96, 158, 110], fill=ACCENT)

def s_footprints(d):
    for ox, oy in ((104, 150), (146, 100)):
        d.ellipse([ox - 20, oy - 12, ox + 20, oy + 30], fill=W)
        for k in range(-2, 3):
            d.ellipse([ox + k * 9 - 4, oy - 30, ox + k * 9 + 4, oy - 20], fill=W)

def s_mountain(d):
    d.polygon([(54, 178), (114, 80), (174, 178)], fill=W)
    d.polygon([(118, 178), (166, 104), (214, 178)], fill=(236, 236, 236, 255))
    d.polygon([(100, 102), (114, 80), (128, 102)], fill=ACCENT)

def s_gate(d):
    d.pieslice([76, 56, 180, 160], 180, 360, fill=W)
    d.rectangle([76, 108, 100, 188], fill=W); d.rectangle([156, 108, 180, 188], fill=W)

def s_pray(d):
    d.polygon([(128, 56), (106, 150), (128, 172)], fill=W)
    d.polygon([(128, 56), (150, 150), (128, 172)], fill=(234, 234, 234, 255))
    d.rectangle([110, 168, 146, 192], fill=W)

def s_peace(d):
    d.ellipse([76, 64, 180, 168], outline=W, width=10)
    d.line([128, 64, 128, 168], fill=W, width=10)
    d.line([128, 116, 90, 152], fill=W, width=10); d.line([128, 116, 166, 152], fill=W, width=10)

def s_joy(d):
    d.ellipse([100, 90, 156, 146], fill=W)
    cx, cy = 128, 118
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([cx + math.cos(r) * 40, cy + math.sin(r) * 40,
                cx + math.cos(r) * 58, cy + math.sin(r) * 58], fill=W, width=8)

def s_courage(d):
    d.ellipse([102, 104, 154, 166], fill=(255, 150, 60, 255))
    d.polygon([(128, 48), (154, 120), (102, 120)], fill=(255, 150, 60, 255))
    d.ellipse([114, 122, 142, 158], fill=(255, 222, 140, 255))

def s_together(d):
    d.ellipse([70, 82, 138, 150], outline=W, width=12)
    d.ellipse([118, 82, 186, 150], outline=W, width=12)

def s_watch(d):
    d.ellipse([70, 84, 186, 152], outline=W, width=10)
    d.ellipse([106, 92, 150, 136], fill=W)
    d.ellipse([116, 102, 140, 126], fill=ACCENT)
    d.ellipse([123, 109, 133, 119], fill=(30, 30, 30, 255))

def s_hope(d):  # anchor
    d.ellipse([116, 48, 140, 72], outline=W, width=8)
    d.rectangle([122, 66, 134, 168], fill=W)
    d.rectangle([96, 84, 160, 96], fill=W)
    d.arc([82, 104, 174, 198], 10, 170, fill=W, width=12)


SYMBOLS = {
    "cross": s_cross, "heart": s_heart, "key": s_key, "crown": s_crown,
    "lantern": s_lantern, "scroll": s_scroll, "dove": s_dove, "candle": s_candle,
    "shield": s_shield, "footprints": s_footprints, "mountain": s_mountain,
    "gate": s_gate, "pray": s_pray, "amen": s_pray, "peace": s_peace,
    "joy": s_joy, "courage": s_courage, "together": s_together, "watch": s_watch,
    "hope": s_hope,
}


FACE_EXPR = {
    "smile": ("normal", "smile"), "laugh": ("happy", "open"),
    "cry": ("sad", "frown"), "fear": ("wide", "small"),
    "hope": ("soft", "smile"), "tired": ("half", "flat"),
    "grateful": ("closed", "smile"), "think": ("look", "flat"),
}


def _face(d, name):
    cx, cy = 128, 108
    d.ellipse([cx - 60, cy - 60, cx + 60, cy + 60], fill=(255, 244, 210, 255),
              outline=(70, 50, 30, 255), width=5)
    eyes, mouth = FACE_EXPR.get(name, ("normal", "smile"))
    ey, ex, er = cy - 14, 26, 9
    ink = (50, 35, 25, 255)
    if eyes in ("closed", "half"):
        for sx in (-1, 1):
            d.arc([cx + sx * ex - er, ey - er, cx + sx * ex + er, ey + er], 200, 340, fill=ink, width=4)
    else:
        big = er + (3 if eyes == "wide" else 0)
        for sx in (-1, 1):
            d.ellipse([cx + sx * ex - big, ey - big, cx + sx * ex + big, ey + big], fill=ink)
        if eyes == "look":
            for sx in (-1, 1):
                d.ellipse([cx + sx * ex - 3, ey - 6, cx + sx * ex + 3, ey], fill=(255, 255, 255, 255))
    my = cy + 30
    if mouth == "smile":
        d.arc([cx - 30, my - 26, cx + 30, my + 14], 20, 160, fill=ink, width=6)
    elif mouth == "frown":
        d.arc([cx - 30, my - 4, cx + 30, my + 36], 200, 340, fill=ink, width=6)
        d.ellipse([cx - 40, my - 6, cx - 32, my + 10], fill=(120, 190, 240, 255))
    elif mouth == "open":
        d.ellipse([cx - 20, my - 12, cx + 20, my + 22], fill=ink)
    elif mouth == "small":
        d.ellipse([cx - 8, my, cx + 8, my + 14], fill=ink)
    else:
        d.line([cx - 22, my + 6, cx + 22, my + 6], fill=ink, width=6)


def _monogram(d, name):
    f = _font(120)
    ch = name[0].upper() if name else "?"
    x = (SIZE - d.textlength(ch, font=f)) / 2
    d.text((x, 36), ch, font=f, fill=W)


def make(name, pack):
    global ACCENT
    hue = _hue(pack + "/" + name)
    ACCENT = _rgb(hue, 0.62, 0.5)
    base = _bg(hue)
    sym = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(sym)
    if pack == "faces":
        _face(d, name)
    else:
        (SYMBOLS.get(name) or (lambda dd: _monogram(dd, name)))(d)
    # uniform soft drop-shadow from the glyph's alpha
    alpha = sym.split()[3].point(lambda v: int(v * 0.45))
    shadow = Image.composite(Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255)),
                             Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), alpha)
    base.alpha_composite(shadow, (3, 4))
    base.alpha_composite(sym)
    _label(ImageDraw.Draw(base), name)
    return base


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--prune", action="store_true",
                    help="delete PNGs / pack folders not present in the manifest")
    args = ap.parse_args()

    manifest = json.load(open(os.path.join(STICKER_DIR, "manifest.json"), encoding="utf-8"))
    packs = manifest.get("packs", {})
    made = 0
    for pack, info in packs.items():
        pdir = os.path.join(STICKER_DIR, pack)
        os.makedirs(pdir, exist_ok=True)
        names = [str(n) for n in info.get("names", [])]
        for name in names:
            out = os.path.join(pdir, name + ".png")
            if args.skip_existing and os.path.exists(out):
                continue
            make(name, pack).save(out)
            made += 1
        if args.prune and os.path.isdir(pdir):
            for f in os.listdir(pdir):
                if f.endswith(".png") and f[:-4] not in names:
                    os.remove(os.path.join(pdir, f)); print("pruned", pack + "/" + f)

    if args.prune:
        for d in os.listdir(STICKER_DIR):
            full = os.path.join(STICKER_DIR, d)
            if os.path.isdir(full) and d not in packs:
                for f in os.listdir(full):
                    if f.endswith(".png"):
                        os.remove(os.path.join(full, f))
                if not os.listdir(full):
                    os.rmdir(full)
                print("pruned pack folder", d)

    print("generated %d sticker placeholders into %s" % (made, STICKER_DIR))


if __name__ == "__main__":
    main()
