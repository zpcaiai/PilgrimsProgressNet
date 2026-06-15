#!/usr/bin/env python3
"""One entry point to (re)generate every placeholder asset bundle, in order:
sticker packs, UI glyphs + default avatar, app/PWA icons, and silent/tone SFX.

Usage:
    python3 tools/gen_all_assets.py                  # sensible defaults
    python3 tools/gen_all_assets.py --skip-existing  # never clobber existing files
    python3 tools/gen_all_assets.py --force          # overwrite everything
    python3 tools/gen_all_assets.py --check          # report missing assets, write nothing

Notes:
  - Real audio is NEVER overwritten by the SFX step (only genuine gaps / tracked
    placeholders).
  - Each step is independent; one failing does not stop the others.
  - --check exits 1 if anything is missing (handy for CI), 0 if complete.
  - Requires Pillow (pip install pillow) for the image steps.
"""
import argparse
import glob
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

STEPS = [
    ("stickers",        "gen_sticker_placeholders.py"),
    ("UI + avatar",     "gen_ui_placeholders.py"),
    ("app / PWA icons", "gen_app_icons.py"),
    ("tone SFX",        "gen_silent_sfx.py"),
]

ICON_FILES = ["app_icon.png", "app_icon.ico", "app_icon.icns",
              "pwa_icon_144.png", "pwa_icon_180.png", "pwa_icon_512.png"]


def args_for(script, force, skip):
    if script == "gen_sticker_placeholders.py":
        return ["--skip-existing"] if skip else []
    if script == "gen_ui_placeholders.py":
        return ["--force"] if force else []
    if script == "gen_app_icons.py":
        return ["--skip-existing"] if skip else []
    if script == "gen_silent_sfx.py":
        return ["--force"] if force else []
    return []


def _load(modname):
    spec = importlib.util.spec_from_file_location(modname, os.path.join(HERE, modname + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def do_check():
    """Report which expected placeholder assets are missing (writes nothing)."""
    ui = _load("gen_ui_placeholders")
    stk = _load("gen_sticker_placeholders")
    sfx = _load("gen_silent_sfx")
    cats = {}  # category -> [missing names]
    total = 0

    # stickers (from manifest)
    miss = []
    mpath = os.path.join(stk.STICKER_DIR, "manifest.json")
    manifest = json.load(open(mpath, encoding="utf-8")) if os.path.exists(mpath) else {"packs": {}}
    for pack, info in manifest.get("packs", {}).items():
        for nm in info.get("names", []):
            total += 1
            if not os.path.exists(os.path.join(stk.STICKER_DIR, pack, str(nm) + ".png")):
                miss.append("%s/%s" % (pack, nm))
    cats["stickers"] = miss

    # UI glyphs + default avatar
    miss = []
    for nm in list(ui.GLYPHS.keys()) + ["avatar_default"]:
        total += 1
        if not os.path.exists(os.path.join(ui.UI_DIR, nm + ".png")):
            miss.append(nm)
    cats["ui glyphs"] = miss

    # app / PWA icons
    miss = []
    for nm in ICON_FILES:
        total += 1
        if not os.path.exists(os.path.join(ui.UI_DIR, nm)):
            miss.append(nm)
    cats["app/PWA icons"] = miss

    # SFX (referenced from AudioManager)
    miss = []
    for nm in sfx.referenced():
        total += 1
        if not os.path.exists(os.path.join(sfx.SFX_DIR, nm + ".ogg")):
            miss.append(nm)
    cats["SFX"] = miss

    missing_total = sum(len(v) for v in cats.values())
    print("Asset check  (%d expected, %d missing)\n" % (total, missing_total))
    for cat, miss in cats.items():
        mark = "OK" if not miss else "MISSING %d" % len(miss)
        print("  [%s] %s" % (mark, cat))
        for nm in miss:
            print("        - %s" % nm)

    # font is optional — informational only
    fonts = glob.glob(os.path.join(ui.ROOT, "assets", "fonts", "*.ttf")) + \
        glob.glob(os.path.join(ui.ROOT, "assets", "fonts", "*.otf"))
    print("\n  [%s] CJK font in assets/fonts/  (%s)" % (
        "OK" if fonts else "ABSENT",
        os.path.basename(fonts[0]) if fonts else "none — chat will tofu until you add one"))

    print("\n%s" % ("All placeholder assets present." if missing_total == 0
                     else "Run `python3 tools/gen_all_assets.py` to fill the gaps."))
    return missing_total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="overwrite everything")
    ap.add_argument("--skip-existing", action="store_true", help="never clobber existing files")
    ap.add_argument("--check", action="store_true", help="report missing assets, write nothing")
    a = ap.parse_args()

    if a.check:
        sys.exit(1 if do_check() else 0)

    failures = 0
    for label, script in STEPS:
        print("\n=== %s  (%s) ===" % (label, script))
        path = os.path.join(HERE, script)
        if not os.path.exists(path):
            print("  missing:", script)
            failures += 1
            continue
        r = subprocess.run([sys.executable, path] + args_for(script, a.force, a.skip_existing))
        if r.returncode != 0:
            print("  ! step failed:", script)
            failures += 1

    print("\nAll asset steps finished%s." % ("" if failures == 0 else " with %d failure(s)" % failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
