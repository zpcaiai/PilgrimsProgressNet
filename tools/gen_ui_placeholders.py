#!/usr/bin/env python3
"""Generate placeholder UI assets: a default avatar + a set of chat/social UI
glyph icons. Same spirit as gen_sticker_placeholders.py — quick, replaceable
stand-ins so nothing renders blank.

Writes:
    assets/ui/avatar_default.png      (256x256 circular pilgrim silhouette)
    assets/ui/<glyph>.png             (96x96 white glyph on a soft rounded chip)

Existing files are NOT overwritten unless --force, so your real icons
(icon_seal.png, title_key_art.png, ...) are safe.

Usage:
    python3 tools/gen_ui_placeholders.py
    python3 tools/gen_ui_placeholders.py --force

Requires Pillow (pip install pillow).
"""
import argparse
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required: pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_DIR = os.path.join(ROOT, "assets", "ui")
W = (255, 255, 255, 255)


def _font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def avatar_default():
    s = 256
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # disc with a soft vertical gradient (neutral slate)
    top, bot = (118, 132, 158), (78, 90, 116)
    grad = Image.new("RGB", (1, s))
    for y in range(s):
        t = y / s
        grad.putpixel((0, y), tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    grad = grad.resize((s, s))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([4, 4, s - 4, s - 4], fill=255)
    img.paste(grad, (0, 0), mask)
    # silhouette: head + shoulders, slightly lighter
    sil = (208, 216, 230, 255)
    d.ellipse([100, 64, 156, 120], fill=sil)            # head
    d.pieslice([66, 140, 190, 250], 180, 360, fill=sil)  # shoulders
    d.ellipse([4, 4, s - 4, s - 4], outline=(255, 255, 255, 210), width=6)
    return img


def _chip():
    s = 96
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([6, 6, s - 6, s - 6], radius=22,
                                          fill=(0, 0, 0, 70))
    return img


def g_send(d):
    d.polygon([(24, 70), (74, 48), (30, 48)], fill=W)
    d.polygon([(24, 70), (74, 48), (44, 74)], fill=(225, 225, 225, 255))

def g_image(d):
    d.rounded_rectangle([22, 26, 74, 70], radius=8, outline=W, width=5)
    d.ellipse([30, 34, 42, 46], fill=W)
    d.polygon([(26, 66), (44, 46), (60, 66)], fill=W)
    d.polygon([(48, 66), (62, 50), (72, 66)], fill=(230, 230, 230, 255))

def g_at(d):
    f = _font(58)
    d.text((28, 14), "@", font=f, fill=W)

def g_bell(d):
    d.pieslice([28, 22, 68, 70], 180, 360, fill=W)
    d.rectangle([28, 46, 68, 64], fill=W)
    d.rectangle([24, 62, 72, 70], fill=W)
    d.ellipse([42, 70, 54, 82], fill=W)

def g_close(d):
    d.line([30, 30, 66, 66], fill=W, width=9); d.line([66, 30, 30, 66], fill=W, width=9)

def g_search(d):
    d.ellipse([24, 24, 60, 60], outline=W, width=8)
    d.line([56, 56, 74, 74], fill=W, width=9)

def g_pin(d):
    d.ellipse([34, 22, 62, 50], fill=W)
    d.polygon([(48, 74), (38, 44), (58, 44)], fill=W)

def g_recall(d):
    d.arc([26, 26, 70, 70], 60, 330, fill=W, width=8)
    d.polygon([(26, 30), (44, 30), (32, 48)], fill=W)


def g_emoji(d):
    d.ellipse([22, 22, 74, 74], fill=(255, 224, 130, 255), outline=W, width=4)
    d.ellipse([36, 40, 45, 51], fill=(60, 50, 30, 255))
    d.ellipse([51, 40, 60, 51], fill=(60, 50, 30, 255))
    d.arc([34, 40, 62, 64], 20, 160, fill=(60, 50, 30, 255), width=5)


GLYPHS = {"send": g_send, "image": g_image, "at": g_at, "bell": g_bell,
          "close": g_close, "search": g_search, "pin": g_pin, "recall": g_recall, "emoji": g_emoji}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="overwrite existing files")
    args = ap.parse_args()
    os.makedirs(UI_DIR, exist_ok=True)
    made = 0

    out = os.path.join(UI_DIR, "avatar_default.png")
    if args.force or not os.path.exists(out):
        avatar_default().save(out); made += 1; print("wrote ui/avatar_default.png")

    for name, fn in GLYPHS.items():
        out = os.path.join(UI_DIR, name + ".png")
        if not args.force and os.path.exists(out):
            print("skip existing ui/%s.png" % name); continue
        chip = _chip()
        fn(ImageDraw.Draw(chip))
        chip.save(out); made += 1; print("wrote ui/%s.png" % name)

    print("generated %d UI placeholders into %s" % (made, UI_DIR))


if __name__ == "__main__":
    main()
