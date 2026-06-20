"""Generate the Batch 2 (vertical-slice) chapter GLBs from inside Blender.

    blender --background --python tools/blender/generate_pilgrim_vslice_scenes.py

Chapters: Interpreter's House, Hill Difficulty, Palace Beautiful, Valley of
Humiliation, Valley of the Shadow of Death. Same shared layout + bpy backend as
the MVP generator.
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (_HERE, os.path.join(_HERE, "..", "scene_gen")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import scene_defs  # noqa: E402
from blender_scene import BlenderScene  # noqa: E402

scene_defs.Scene = BlenderScene

VSLICE_IDS = [
    "interpreter_house",
    "hill_difficulty",
    "palace_beautiful",
    "valley_humiliation",
    "valley_shadow_death",
]

OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "..",
                                        "assets", "imported_scenes"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating vertical-slice scenes (chapters 6-10) ...")
    for cid in VSLICE_IDS:
        scene = scene_defs.SCENES[cid]()
        path = os.path.join(OUT_DIR, cid + ".glb")
        n = scene.save(path)
        print("  %-24s %8d bytes (%d named nodes)"
              % (cid, n, len(scene.node_names())))
    print("Done -> %s" % OUT_DIR)


if __name__ == "__main__":
    main()
