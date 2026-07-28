"""Normalise the Godot .import settings for every generated chapter GLB.

    python3 tools/scene_gen/fix_glb_imports.py            # report + fix
    python3 tools/scene_gen/fix_glb_imports.py --check    # report only

WHY
---
The scene GLBs are code-generated, so their .import files were created by
whatever the editor defaulted to on the day each one was first imported. That
left three things inconsistent across the 16 chapters:

  meshes/generate_lods          -- automatic distance LODs. The generator emits
                                   no LOD data of its own (no MSFT_lod), so this
                                   importer flag is the ONLY source of LODs in
                                   the project. Vanity Fair and the Celestial
                                   City are ~43k triangles each; without LODs
                                   every one of those triangles is submitted at
                                   every distance.
  meshes/create_shadow_meshes   -- a deduplicated position-only copy used for
                                   the shadow pass. Roughly halves shadow-pass
                                   vertex cost, which matters now that the
                                   desktop build runs Forward+ with 4 shadow
                                   splits and up to 6 shadow-casting point
                                   lights.
  meshes/ensure_tangents        -- required for the normal maps the writer now
                                   emits on curved surfaces (the UV work in
                                   glb_lib). Without tangents a normal map is
                                   silently ignored.

Run this after build_scenes.py and re-open the project so Godot re-imports.
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCENE_DIRS = [
    os.path.join(ROOT, "assets", "imported_scenes"),
    os.path.join(ROOT, "assets", "imported_scenes", "web"),
    os.path.join(ROOT, "assets", "characters", "rig"),
]

# key -> desired value (as it appears in the .import file)
WANT = {
    "meshes/generate_lods": "true",
    "meshes/create_shadow_meshes": "true",
    "meshes/ensure_tangents": "true",
    "meshes/light_baking": "1",
    "skins/use_named_skins": "true",
    "animation/import": "true",
    "animation/fps": "30",
    "animation/trimming": "false",
    "animation/remove_immutable_tracks": "true",
    "nodes/apply_root_scale": "true",
    "nodes/root_scale": "1.0",
}


def patch(path, check_only=False):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()

    try:
        params_at = lines.index("[params]")
    except ValueError:
        return None  # not a resource-importer file we understand

    present = {}
    insert_at = len(lines)
    for i in range(params_at + 1, len(lines)):
        line = lines[i].strip()
        if line.startswith("["):          # next section: stop
            insert_at = i
            break
        if not line:                       # blank lines are legal INSIDE [params]
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            present[k.strip()] = (i, v.strip())
            insert_at = i + 1

    changes = []
    additions = []
    for k, v in WANT.items():
        if k in present:
            i, cur = present[k]
            if cur != v:
                changes.append((k, cur, v))
                if not check_only:
                    lines[i] = "%s=%s" % (k, v)
        else:
            changes.append((k, "<missing>", v))
            additions.append("%s=%s" % (k, v))
    if additions and not check_only:
        lines[insert_at:insert_at] = additions

    if changes and not check_only:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    return changes


def main(argv):
    check = "--check" in argv
    total = 0
    touched = 0
    for d in SCENE_DIRS:
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".glb.import"):
                continue
            total += 1
            changes = patch(os.path.join(d, fn), check_only=check)
            if changes is None:
                print("%-40s  [skipped: unrecognised format]" % fn)
                continue
            if changes:
                touched += 1
                print("%-40s  %s" % (fn, ", ".join(
                    "%s %s->%s" % (k, a, b) for k, a, b in changes)))
    print("-" * 72)
    if total == 0:
        print("No .glb.import files found. Run build_scenes.py, then open the "
              "project in Godot once so it generates them, then re-run this.")
    else:
        print("%s %d of %d import files." %
              ("Would patch" if check else "Patched", touched, total))
        if touched and not check:
            print("Re-open the project in Godot so the scenes re-import.")


if __name__ == "__main__":
    main(sys.argv)
