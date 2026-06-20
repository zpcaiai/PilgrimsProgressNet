"""Export ALL ten chapter scenes to GLB from inside Blender.

    blender --background --python tools/blender/export_all_glb.py

Writes res://assets/imported_scenes/<chapter_id>.glb for every chapter, using
the shared layout definitions in tools/scene_gen/scene_defs.py via the bpy
backend (blender_scene.BlenderScene). Output matches the dependency-free
tools/scene_gen/build_scenes.py object-for-object.
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (_HERE, os.path.join(_HERE, "..", "scene_gen")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import scene_defs  # noqa: E402
from blender_scene import BlenderScene  # noqa: E402

# Route every builder through Blender instead of the GLB writer.
scene_defs.Scene = BlenderScene

OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "..",
                                        "assets", "imported_scenes"))


def export(ids):
    os.makedirs(OUT_DIR, exist_ok=True)
    for cid in ids:
        scene = scene_defs.SCENES[cid]()
        path = os.path.join(OUT_DIR, cid + ".glb")
        n = scene.save(path)
        print("  exported %-24s %8d bytes" % (cid, n))


if __name__ == "__main__":
    print("Exporting all chapter GLBs via Blender ...")
    export(list(scene_defs.SCENES.keys()))
    print("Done -> %s" % OUT_DIR)
