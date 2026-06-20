"""Generate all ten chapter GLBs into assets/imported_scenes/ -- no Blender.

    python3 tools/scene_gen/build_scenes.py

Produces res://assets/imported_scenes/<chapter_id>.glb for each chapter, ready
to import in Godot 4. Re-run any time scene_defs.py changes.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene_defs import SCENES  # noqa: E402

OUT_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "assets", "imported_scenes"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for cid, fn in SCENES.items():
        scene = fn()
        path = os.path.join(OUT_DIR, cid + ".glb")
        n = scene.save(path)
        total += n
        print("%-24s %8d bytes  %3d named nodes -> %s"
              % (cid, n, len(scene.node_names()), os.path.basename(path)))
    print("-" * 60)
    print("Wrote %d GLB scenes (%d bytes) to %s" % (len(SCENES), total, OUT_DIR))


if __name__ == "__main__":
    main()
