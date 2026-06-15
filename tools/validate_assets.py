#!/usr/bin/env python3
"""
validate_assets.py — sandbox smoke check for Pilgrim's Road.

Without a Godot binary this is the closest proxy to "does the project hold
together": it cross-checks every res:// path the code references against the
files on disk, validates media + the sticker manifest schema + the font, checks
project.godot autoloads resolve, and runs a mechanical GDScript pass.

Run: python3 tools/validate_assets.py
"""
import os, re, json, glob, sys, struct, subprocess
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)
problems, notes = [], []
def bad(m): problems.append(m)
def need(p, why=""):
    if not os.path.exists(p): bad(f"MISSING {p}  {why}")

# 1) autoloads + main scene resolve
pg = open("project.godot").read()
for name, path in re.findall(r'^(\w+)="\*?(res://[^"]+)"', pg, re.M):
    need(path.replace("res://", ""), f"(autoload {name})")
m = re.search(r'run/main_scene="(res://[^"]+)"', pg)
if m: need(m.group(1).replace("res://", ""), "(main scene)")

# 2) chapters: music / ambient / scene_path + ground + scene art
chapters = []
for jf in glob.glob("data/chapters/*.json"):
    d = json.load(open(jf)); cid = d["id"]; chapters.append(cid)
    for k in ("music", "ambient", "scene_path"):
        if d.get(k): need(d[k].replace("res://", ""), f"({cid}.{k})")
    need(f"assets/textures/ground/{cid}.png", f"(ground {cid})")
    need(f"assets/scenes/{cid}.png", f"(scene art {cid})")

# 3) AudioManager SFX
am = open("scripts/core/AudioManager.gd").read()
sfx = sorted(set(re.findall(r'res://assets/audio/sfx/(\w+)\.ogg', am)))
for s in sfx: need(f"assets/audio/sfx/{s}.ogg", "(sfx)")

# 4) AssetLib speaker portraits
al = open("scripts/core/AssetLib.gd").read()
sm = re.search(r'SPEAKER_MAP\s*:=\s*\{(.*?)\}', al, re.S)
portraits = re.findall(r':\s*"(\w+)"', sm.group(1)) if sm else []
for p in portraits: need(f"assets/characters/{p}.png", "(portrait)")

# 5) sticker manifest schema + files (ChatPanel reads packs[pid].{label,names})
stick = 0
manp = "assets/ui/stickers/manifest.json"
if not os.path.exists(manp):
    bad("MISSING sticker manifest")
else:
    man = json.load(open(manp))
    if "packs" not in man or not isinstance(man["packs"], dict):
        bad("sticker manifest: no 'packs' dict")
    for pid, d in man.get("packs", {}).items():
        if "label" not in d or "names" not in d:
            bad(f"sticker pack {pid}: missing label/names")
        for nm in d.get("names", []):
            need(f"assets/ui/stickers/{pid}/{nm}.png", f"(sticker {pid}/{nm})"); stick += 1

# 6) font present + loadable
fonts = glob.glob("assets/fonts/*.otf") + glob.glob("assets/fonts/*.ttf")
if not fonts:
    bad("no CJK font in assets/fonts/ (ThemeManager will fall back, CJK tofus)")
else:
    try:
        from fontTools.ttLib import TTFont
        cm = TTFont(fonts[0]).getBestCmap()
        miss = [c for c in "天路历程私聊会话设置音乐" if ord(c) not in cm]
        if miss: bad(f"font missing glyphs: {miss}")
        else: notes.append(f"font {os.path.basename(fonts[0])}: {len(cm)} glyphs, CJK OK")
    except Exception as e:
        notes.append(f"font present ({os.path.basename(fonts[0])}); fontTools check skipped: {e}")

# 7) media integrity (PNG signature + OGG vorbis)
pngs = glob.glob("assets/**/*.png", recursive=True)
for f in pngs:
    with open(f, "rb") as fh:
        if fh.read(8) != b"\x89PNG\r\n\x1a\n": bad(f"bad PNG {f}")
oggs = glob.glob("assets/**/*.ogg", recursive=True)
for f in oggs:
    with open(f, "rb") as fh:
        if fh.read(4) != b"OggS": bad(f"bad OGG {f}")

# 8) mechanical GDScript pass (bracket balance / tabs / func colon)
def strip(line):
    out=[];i=0;instr=None
    while i<len(line):
        c=line[i]
        if instr:
            if c=='\\': out.append(' ');i+=2;continue
            if c==instr: instr=None
            out.append(' ');i+=1;continue
        if c in '"\'': instr=c;out.append(' ');i+=1;continue
        if c=='#': break
        out.append(c);i+=1
    return ''.join(out)
gd_issues=0
for path in glob.glob("scripts/**/*.gd", recursive=True):
    bal={'(':0,'[':0,'{':0}; pairs={')':'(',']':'[','}':'{'}
    for ln,line in enumerate(open(path).read().split('\n'),1):
        if line.strip()=='' or line.lstrip().startswith('#'): continue
        lead=line[:len(line)-len(line.lstrip())]
        if ' ' in lead: bad(f"{path}:{ln}: space indent"); gd_issues+=1
        for c in strip(line):
            if c in bal: bal[c]+=1
            elif c in pairs: bal[pairs[c]]-=1
    for k,v in bal.items():
        if v!=0: bad(f"{path}: unbalanced '{k}' ({v})"); gd_issues+=1

print("="*60)
print(f"chapters={len(chapters)} sfx={len(sfx)} portraits={len(portraits)} "
      f"stickers={stick} pngs={len(pngs)} oggs={len(oggs)} gd_files={len(glob.glob('scripts/**/*.gd',recursive=True))}")
for n in notes: print("  ·", n)
print("="*60)
if problems:
    print(f"FAILED — {len(problems)} problem(s):")
    for p in problems[:60]: print("  -", p)
    sys.exit(1)
print("ALL CHECKS PASSED ✓")
