"""Generate the Batch 1 (MVP) chapter GLBs from inside Blender.

    blender --background --python tools/blender/generate_pilgrim_mvp_scenes.py

Chapters: City of Destruction, Wilderness Road, Slough of Despond, Wicket Gate,
Cross and Tomb. Layout comes from tools/scene_gen/scene_defs.py; geometry is
built with bpy via blender_scene.BlenderScene.
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

MVP_IDS = [
    "city_of_destruction",
    "wilderness_road",
    "slough_of_despond",
    "wicket_gate",
    "cross_and_tomb",
]

OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "..",
                                        "assets", "imported_scenes"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating MVP scenes (chapters 1-5) ...")
    for cid in MVP_IDS:
        scene = scene_defs.SCENES[cid]()
        path = os.path.join(OUT_DIR, cid + ".glb")
        n = scene.save(path)
        print("  %-24s %8d bytes (%d named nodes)"
              % (cid, n, len(scene.node_names())))
    print("Done -> %s" % OUT_DIR)


if __name__ == "__main__":
    main()
