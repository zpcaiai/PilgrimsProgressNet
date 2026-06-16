#!/usr/bin/env python3
"""Import AI-generated art from assets/_incoming/ into the game's asset folders.

Drop files named "<stem>.webp/.png" into assets/_incoming/, then run this.
  - scene stems   -> assets/scenes/<stem>.png            (1280x720)
  - portrait stems-> assets/characters/<stem>.png         (512x640)
  - "<stem>_child"-> same path with the _child suffix     (children's-journey art)

The game's AssetLib.scene_art()/portrait() automatically prefer the _child
variant when the player chose the gentle "Children's Journey", and fall back to
the standard art otherwise — so both versions are referenced correctly.
"""
import os
from PIL import Image

SCENES = {"celestial_city","city_of_destruction","cross_and_tomb","delectable_mountains",
    "doubting_castle","enchanted_ground","hill_difficulty","interpreter_house","palace_beautiful",
    "river_of_death","slough_of_despond","valley_humiliation","valley_shadow_death","vanity_fair",
    "wicket_gate","wilderness_road"}
PORTRAITS = {"pilgrim","evangelist","help","goodwill","hopeful","apollyon","the_interpreter",
    "the_shepherds","watchful","obstinate","pliable","your_family"}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "assets", "_incoming")

def target(stem):
    base = stem[:-6] if stem.endswith("_child") else stem
    suffix = "_child" if stem.endswith("_child") else ""
    if base in SCENES:
        return 1280, 720, os.path.join(ROOT, "assets", "scenes", base + suffix + ".png"), "scene"
    if base in PORTRAITS:
        return 512, 640, os.path.join(ROOT, "assets", "characters", base + suffix + ".png"), "portrait"
    return None

def process(src, tw, th, dst, kind):
    im = Image.open(src).convert("RGBA"); w, h = im.size; tr = tw / th; r = w / h
    if r > tr:
        nw = int(round(h * tr)); x = (w - nw) // 2; im = im.crop((x, 0, x + nw, h))
    else:
        nh = int(round(w / tr)); y = 0 if kind == "portrait" else (h - nh) // 2; im = im.crop((0, y, w, y + nh))
    im = im.resize((tw, th), Image.LANCZOS); im.save(dst)

def main():
    done, skip = [], []
    for f in sorted(os.listdir(INC)):
        if not f.lower().endswith((".webp", ".png", ".jpg", ".jpeg")):
            continue
        stem = os.path.splitext(f)[0]
        t = target(stem)
        if t is None:
            skip.append(f); continue
        process(os.path.join(INC, f), *t); done.append(os.path.relpath(t[2], ROOT))
    print(f"imported {len(done)} file(s):")
    for d in done: print("  ", d)
    if skip: print("skipped (unknown stem):", skip)

if __name__ == "__main__":
    main()
