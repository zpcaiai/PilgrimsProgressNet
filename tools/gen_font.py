#!/usr/bin/env python3
"""
gen_font.py — build a compact CJK UI font for Pilgrim's Road.

Subsets Noto Sans CJK SC (SIL OFL 1.1, (c) Google — no Reserved Font Name) down
to the glyphs the game actually needs: full ASCII + Latin-1, common punctuation,
CJK punctuation/fullwidth forms, the complete GB2312 common-Hanzi set (~6.7k, so
arbitrary everyday Chinese chat renders), plus every non-ASCII character found in
the repo's own text. Output drops into res://assets/fonts/, where ThemeManager /
AssetLib.font() pick it up automatically.

Usage: python3 gen_font.py
Requires: fontTools. Source font: system Noto Sans CJK (fonts-noto-cjk).
"""
import os, glob, shutil
from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
FONTS = os.path.join(ROOT, "assets", "fonts")
TTC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
SC_FACE = 2  # 0=JP 1=KR 2=SC 3=TC 4=HK
LICENSE_SRC = "/usr/share/doc/fonts-noto-cjk/copyright"
OUT = os.path.join(FONTS, "NotoSansCJKsc-Subset.otf")


def gb2312_chars():
    out = set()
    for hi in range(0xA1, 0xFA):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def repo_chars():
    out = set()
    pats = ["data/**/*.json", "scripts/**/*.gd", "docs/**/*.md", "*.md",
            "assets/**/*.json"]
    for pat in pats:
        for f in glob.glob(os.path.join(ROOT, pat), recursive=True):
            try:
                txt = open(f, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for ch in txt:
                if ord(ch) > 0x7F:
                    out.add(ch)
    return out


def build_codepoints():
    cps = set(range(0x20, 0x7F))                 # ASCII
    cps |= set(range(0xA0, 0x100))               # Latin-1 supplement
    cps |= set(range(0x2000, 0x2070))            # general punctuation
    cps |= {0x20AC, 0x2122, 0x2026, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D}
    cps |= set(range(0x3000, 0x3040))            # CJK symbols & punctuation
    cps |= set(range(0xFF00, 0xFFF0))            # fullwidth forms
    cps |= set(range(0x2460, 0x2500))            # circled numbers/letters
    for ch in gb2312_chars():
        cps.add(ord(ch))
    for ch in repo_chars():
        cps.add(ord(ch))
    return cps


def main():
    os.makedirs(FONTS, exist_ok=True)
    cps = build_codepoints()
    print(f"target codepoints: {len(cps)}")

    font = TTFont(TTC, fontNumber=SC_FACE)
    opts = Options()
    opts.glyph_names = False
    opts.recalc_timestamp = False
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.layout_features = ["*"]
    opts.notdef_outline = True
    opts.drop_tables = ["DSIG"]
    ss = Subsetter(options=opts)
    ss.populate(unicodes=sorted(cps))
    ss.subset(font)
    font.save(OUT)

    # Verify coverage of a few representative glyphs.
    chk = TTFont(OUT)
    cmap = chk.getBestCmap()
    samples = "天路历程保存私聊会话敬虔加油平安阿们Aa1—…"
    missing = [c for c in samples if ord(c) not in cmap]
    print(f"saved {os.path.relpath(OUT, ROOT)}  "
          f"({os.path.getsize(OUT)//1024} KB, {len(cmap)} glyphs in cmap)")
    print("sample coverage:", "OK" if not missing else f"MISSING {missing}")

    if os.path.exists(LICENSE_SRC):
        shutil.copyfile(LICENSE_SRC, os.path.join(FONTS, "LICENSE-NotoSansCJK.txt"))
        print("copied OFL license -> assets/fonts/LICENSE-NotoSansCJK.txt")


if __name__ == "__main__":
    main()
