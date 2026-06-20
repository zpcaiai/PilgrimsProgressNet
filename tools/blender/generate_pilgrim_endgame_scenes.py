"""Generate the Batch 3 (endgame) chapter GLBs from inside Blender.

    blender --background --python tools/blender/generate_pilgrim_endgame_scenes.py

Chapters: Vanity Fair, Doubting Castle, Delectable Mountains, Enchanted Ground,
River of Death, Celestial City. Same shared layout + bpy backend as the other
generators.
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

ENDGAME_IDS = [
    "vanity_fair",
    "doubting_castle",
    "delectable_mountains",
    "enchanted_ground",
    "river_of_death",
    "celestial_city",
]

OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "..",
                                        "assets", "imported_scenes"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating endgame scenes (chapters 11-16) ...")
    for cid in ENDGAME_IDS:
        scene = scene_defs.SCENES[cid]()
        path = os.path.join(OUT_DIR, cid + ".glb")
        n = scene.save(path)
        print("  %-24s %8d bytes (%d named nodes)"
              % (cid, n, len(scene.node_names())))
    print("Done -> %s" % OUT_DIR)


if __name__ == "__main__":
    main()
