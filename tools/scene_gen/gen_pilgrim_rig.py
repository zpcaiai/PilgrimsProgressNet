"""Build the skinned pilgrim model: assets/characters/rig/pilgrim.glb

    python3 tools/scene_gen/gen_pilgrim_rig.py
    python3 tools/scene_gen/gen_pilgrim_rig.py --report   # stats, no write

Output: a standard glTF 2.0 skinned character —
    Skeleton3D (26 bones, names per rig_lib.BONES)
    MeshInstance3D "PilgrimBody"  (one primitive per palette slot)
    AnimationPlayer with Idle / Walk / Run / Talk

Godot imports this with no manual scene wiring. `SkinnedFigure.gd` loads it,
re-tints the per-slot materials from `CharacterPalette`, and drives the clips
from the character's own movement — so ONE model serves the whole cast, exactly
as the primitive `HumanoidFigure` did.

WHY ONE PRIMITIVE PER PALETTE SLOT
----------------------------------
A character needs at least skin / robe / hose / hair / accent / eye / boot to
read. Vertex colours would mean one material and no per-character re-tinting;
separate primitives mean 7 surfaces on a single mesh, each with its own
StandardMaterial3D that SkinnedFigure can recolour per character at runtime.
Seven surfaces on one skinned mesh is still one skeleton and one draw call per
material — far cheaper than the 20 separate MeshInstance3Ds it replaces.

REPLACING THIS WITH REAL ART
----------------------------
Drop any rigged .glb over assets/characters/rig/pilgrim.glb. As long as the bone
NAMES match rig_lib.BONES (Hips / Spine / Chest / Neck / Head / UpperArmL ...)
and the clips are named Idle / Walk / Run / Talk, SkinnedFigure.gd needs no
changes. Surfaces are matched by material name (Skin, Robe, Robe2, Hair,
Accent, Eye, Boot) and fall back to leaving unknown materials untouched.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import glb_lib  # noqa: E402
import rig_lib  # noqa: E402

ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "characters", "rig")
OUT_PATH = os.path.join(OUT_DIR, "pilgrim.glb")

# Neutral base colours. SkinnedFigure re-tints them per character at runtime;
# these are only what you see if it does not.
SLOT_MATERIALS = [
    ("Skin",   (0.86, 0.70, 0.58, 1.0), 0.62),
    ("Robe",   (0.55, 0.52, 0.62, 1.0), 0.90),
    ("Robe2",  (0.42, 0.40, 0.48, 1.0), 0.90),
    ("Hair",   (0.28, 0.22, 0.18, 1.0), 0.80),
    ("Accent", (0.70, 0.58, 0.30, 1.0), 0.55),
    ("Eye",    (0.10, 0.09, 0.08, 1.0), 0.30),
    ("Boot",   (0.24, 0.20, 0.18, 1.0), 0.72),
]


def build(sides=10):
    g = glb_lib.GLB()

    # ---- 1. bone nodes -----------------------------------------------------
    locals_ = rig_lib.local_translations()
    children_of = {}
    for i, (name, parent, _pos) in enumerate(rig_lib.BONES):
        if parent is not None:
            children_of.setdefault(rig_lib.BONE_INDEX[parent], []).append(i)

    # Create nodes leaf-first so children indices exist when a parent is made.
    node_of_bone_idx = {}

    def make_bone(bi):
        if bi in node_of_bone_idx:
            return node_of_bone_idx[bi]
        kids = [make_bone(c) for c in children_of.get(bi, [])]
        name = rig_lib.BONES[bi][0]
        n = g.node(name, translation=locals_[bi], children=kids or None)
        node_of_bone_idx[bi] = n
        return n

    for bi in range(len(rig_lib.BONES) - 1, -1, -1):
        make_bone(bi)
    root_bone_node = node_of_bone_idx[0]

    joint_nodes = [node_of_bone_idx[i] for i in range(len(rig_lib.BONES))]
    rest_positions = [b[2] for b in rig_lib.BONES]
    skin_idx = g.skin(joint_nodes, rest_positions, name="PilgrimSkin")

    # ---- 2. geometry + skinning -------------------------------------------
    body = rig_lib.build_body(sides=sides)
    joints, weights = body.skin()

    # Split the single vertex soup into one primitive per palette slot, so each
    # material can be re-tinted independently at runtime.
    prim_meshes = []
    for slot, (mat_name, rgba, rough) in enumerate(SLOT_MATERIALS):
        keep = [i for i, c in enumerate(body.C) if c == slot]
        if not keep:
            continue
        remap = {old: new for new, old in enumerate(keep)}
        P = [body.P[i] for i in keep]
        N = [body.N[i] for i in keep]
        J = [joints[i] for i in keep]
        W = [weights[i] for i in keep]
        I = []
        for k in range(0, len(body.I) - 2, 3):
            a, b, c = body.I[k], body.I[k + 1], body.I[k + 2]
            if a in remap and b in remap and c in remap:
                I.extend([remap[a], remap[b], remap[c]])
        if not I:
            continue
        metallic = 0.0
        m = g.material(rgba, metallic=metallic, roughness=rough)
        # Name the material so SkinnedFigure can find it by slot.
        g.materials[m]["name"] = mat_name
        prim_meshes.append((mat_name, g.skinned_mesh(P, N, J, W, I, m)))

    # glTF puts one mesh per node; merge the per-slot primitives into a single
    # mesh so the whole body is one MeshInstance3D with N surfaces.
    merged = {"primitives": []}
    for _name, mi in prim_meshes:
        merged["primitives"].extend(g.meshes[mi]["primitives"])
    g.meshes.append(merged)
    g.mesh_geo.append(([], [], []))
    g.mesh_solid.append(False)
    body_mesh_idx = len(g.meshes) - 1

    body_node = g.node("PilgrimBody", mesh_idx=body_mesh_idx, skin_idx=skin_idx)

    # The per-slot meshes were only staging for the merge; drop them so the
    # file carries exactly one mesh. (Their accessors are shared by the merged
    # primitives, so nothing in the binary buffer is orphaned.)
    g.meshes = [merged]
    g.mesh_geo = [g.mesh_geo[-1]]
    g.mesh_solid = [False]
    for n in g.nodes:
        if "mesh" in n:
            n["mesh"] = 0

    # ---- 3. animation clips ------------------------------------------------
    node_of_bone = {rig_lib.BONES[i][0]: node_of_bone_idx[i]
                    for i in range(len(rig_lib.BONES))}
    for clip_name, (kind, dur, samples, kw) in rig_lib.CLIPS.items():
        tracks = rig_lib.clip_tracks(kind, dur, samples, node_of_bone, **kw)
        if tracks:
            g.animation(clip_name, tracks)

    # ---- 4. scene root -----------------------------------------------------
    g.node("Pilgrim", children=[root_bone_node, body_node])
    return g, body, prim_meshes


def main(argv):
    report_only = "--report" in argv
    sides = 10
    for a in argv:
        if a.startswith("--sides="):
            sides = int(a.split("=", 1)[1])

    g, body, prims = build(sides=sides)
    tris = len(body.I) // 3
    print("bones      : %d" % len(rig_lib.BONES))
    print("vertices   : %d" % len(body.P))
    print("triangles  : %d" % tris)
    print("surfaces   : %d (%s)" % (len(prims), ", ".join(n for n, _ in prims)))
    print("clips      : %d (%s)" % (len(g.animations),
                                    ", ".join(a["name"] for a in g.animations)))
    # sanity: every weight set must sum to ~1
    joints, weights = body.skin()
    bad = [i for i, w in enumerate(weights) if abs(sum(w) - 1.0) > 1e-3]
    print("weight sums: %s" % ("OK" if not bad else "%d BAD" % len(bad)))
    unused = set(range(len(rig_lib.BONES))) - {j for js in joints for j in js}
    if unused:
        print("unweighted bones: %s"
              % ", ".join(rig_lib.BONES[i][0] for i in sorted(unused)))

    if report_only:
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    data = g.to_glb("Pilgrim")
    with open(OUT_PATH, "wb") as f:
        f.write(data)
    print("-" * 60)
    print("Wrote %s (%d bytes)" % (OUT_PATH, len(data)))
    print("Open the project in Godot once so it imports, then run "
          "tools/scene_gen/fix_glb_imports.py")


if __name__ == "__main__":
    main(sys.argv)
