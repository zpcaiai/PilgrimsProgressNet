#!/usr/bin/env python3
"""Generate placeholder application / PWA icons (a themed 'Celestial City gate').

Writes:
    assets/ui/app_icon.png        1024x1024  (master)
    assets/ui/app_icon.ico        multi-size (Windows export icon)
    assets/ui/app_icon.icns       multi-size (macOS export icon)
    assets/ui/pwa_icon_144.png    144x144   (Web PWA)
    assets/ui/pwa_icon_180.png    180x180   (Web PWA / Apple touch)
    assets/ui/pwa_icon_512.png    512x512   (Web PWA)

These are wired into export_presets.cfg. Replace with final art anytime (keep the
same paths). Existing files are overwritten unless --skip-existing.

Usage:
    python3 tools/gen_app_icons.py
    python3 tools/gen_app_icons.py --skip-existing

Requires Pillow (pip install pillow).
"""
import argparse
import math
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is required: pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_DIR = os.path.join(ROOT, "assets", "ui")
B = 1024  # master size


def _lerp(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def master():
    img = Image.new("RGBA", (B, B), (0, 0, 0, 255))
    px = img.load()
    sky_top, sky_mid, sky_bot = (38, 52, 96), (120, 86, 140), (245, 200, 120)
    for y in range(B):
        t = y / B
        c = _lerp(sky_top, sky_mid, t * 2) if t < 0.5 else _lerp(sky_mid, sky_bot, (t - 0.5) * 2)
        for x in range(B):
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(img, "RGBA")
    cx, gate_y = B // 2, int(B * 0.46)
    # light rays from the gate
    for a in range(0, 360, 18):
        r = math.radians(a)
        d.polygon([(cx, gate_y),
                   (cx + math.cos(r) * B, gate_y + math.sin(r) * B - 40),
                   (cx + math.cos(r + 0.09) * B, gate_y + math.sin(r + 0.09) * B - 40)],
                  fill=(255, 245, 210, 22))
    # rising path
    d.polygon([(int(B * 0.40), B), (int(B * 0.60), B),
               (int(B * 0.535), gate_y), (int(B * 0.465), gate_y)], fill=(245, 225, 165, 255))
    # gate: pillars + arch
    gold, glow = (242, 212, 130, 255), (255, 248, 205, 255)
    pw, ph = int(B * 0.085), int(B * 0.30)
    lx, rx = int(B * 0.40), int(B * 0.60)
    d.rectangle([lx - pw // 2, gate_y - ph // 2, lx + pw // 2, gate_y + ph], fill=gold)
    d.rectangle([rx - pw // 2, gate_y - ph // 2, rx + pw // 2, gate_y + ph], fill=gold)
    d.pieslice([lx - pw // 2, gate_y - ph, rx + pw // 2, gate_y + ph // 2], 180, 360, fill=gold)
    d.pieslice([lx + pw // 2, gate_y - ph + 8, rx - pw // 2, gate_y - 6], 180, 360, fill=glow)
    d.rectangle([lx + pw // 2, gate_y - ph // 2, rx - pw // 2, gate_y + ph], fill=glow)
    # small cross on the gable
    d.rectangle([cx - 10, gate_y - ph - 70, cx + 10, gate_y - ph + 10], fill=glow)
    d.rectangle([cx - 38, gate_y - ph - 40, cx + 38, gate_y - ph - 20], fill=glow)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-existing", action="store_true")
    args = ap.parse_args()
    os.makedirs(UI_DIR, exist_ok=True)

    def out(name):
        return os.path.join(UI_DIR, name)

    def want(name):
        return not (args.skip_existing and os.path.exists(out(name)))

    m = master()
    made = 0
    if want("app_icon.png"):
        m.save(out("app_icon.png")); made += 1
    if want("app_icon.ico"):
        m.save(out("app_icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        made += 1
    if want("app_icon.icns"):
        m.resize((512, 512)).save(out("app_icon.icns"), format="ICNS"); made += 1
    for sz in (144, 180, 512):
        nm = "pwa_icon_%d.png" % sz
        if want(nm):
            m.resize((sz, sz)).save(out(nm)); made += 1

    print("generated %d app/PWA icon file(s) into %s" % (made, UI_DIR))


if __name__ == "__main__":
    main()
