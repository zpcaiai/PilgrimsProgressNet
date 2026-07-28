"""Generate the chapter GLBs into assets/imported_scenes/ -- no Blender.

    python3 tools/scene_gen/build_scenes.py            # desktop build
    python3 tools/scene_gen/build_scenes.py --web      # lighter web build
    python3 tools/scene_gen/build_scenes.py --no-ao    # skip the AO bake
    python3 tools/scene_gen/build_scenes.py wicket_gate slough_of_despond

Produces res://assets/imported_scenes/<chapter_id>.glb for each chapter, ready
to import in Godot 4. Re-run any time scene_defs.py changes.

TWO TARGETS
-----------
The desktop and web builds now differ in the two places that actually matter
for size:

    desktop   embedded textures 384 px, 12-ray AO bake
    --web     embedded textures 160 px,  8-ray AO bake, written to
              assets/imported_scenes/web/<id>.glb

GlbChapter prefers the web/ variant when running under OS.has_feature("web"),
so the browser build stops paying for desktop-resolution maps while the desktop
build stops being capped at thumbnail resolution (the old hard-coded 160 px).

BAKED AMBIENT OCCLUSION
-----------------------
Every solid mesh gets per-vertex AO written into COLOR_0 (see glb_ao.py). This
is what gives the web build contact shading at all -- its renderer
(gl_compatibility) has no SSAO, while all 16 chapter art profiles ask for it.
Disable with --no-ao or PILGRIM_NO_AO=1 for a fast iteration loop.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "imported_scenes")


def main(argv):
    web = "--web" in argv
    no_ao = "--no-ao" in argv
    verbose = "-v" in argv or "--verbose" in argv
    only = [a for a in argv[1:] if not a.startswith("-")]

    # The texture embed budget must be set BEFORE glb_lib is imported, since
    # EMBED_MAX is read from the environment at module load time.
    os.environ["PILGRIM_EMBED_MAX"] = "160" if web else \
        os.environ.get("PILGRIM_EMBED_MAX", "384")

    from scene_defs import SCENES  # noqa: E402  (after the env var is set)

    out_dir = os.path.join(OUT_DIR, "web") if web else OUT_DIR
    os.makedirs(out_dir, exist_ok=True)

    rays = 8 if web else 12
    total = 0
    started = time.time()
    for cid, fn in SCENES.items():
        if only and cid not in only:
            continue
        t0 = time.time()
        scene = fn()
        path = os.path.join(out_dir, cid + ".glb")
        n = scene.save(path, bake_ao=not no_ao, ao_rays=rays, verbose=verbose)
        total += n
        tris = sum(len(g[2]) for g in scene.glb.mesh_geo) // 3
        print("%-24s %9d bytes  %3d nodes  %7d tris  %5.1fs"
              % (cid, n, len(scene.node_names()), tris, time.time() - t0))
    print("-" * 76)
    print("Wrote GLB scenes (%d bytes) to %s in %.1fs%s"
          % (total, out_dir, time.time() - started,
             "  [web profile]" if web else ""))


if __name__ == "__main__":
    main(sys.argv)
