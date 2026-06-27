#!/usr/bin/env python3
"""
Build an articulated, ANIMATED low-poly pilgrim GLB (public/models/pilgrim.glb).

Not skinned (no weights/IBM, so no risk of skin distortion) — instead a node
hierarchy (hips > torso/head/arms/legs) with a baked 'Walk' animation that rotates
the limb pivots and bobs the hips. Plays via drei <useAnimations>. Y-up, faces +Z.

Run:  python3 tools/gen_models/build_character.py
"""
import os
import struct
import numpy as np
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Attributes, Buffer, BufferView, Accessor,
    Material, PbrMetallicRoughness, Animation, AnimationChannel, AnimationSampler,
    ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER, FLOAT, UNSIGNED_SHORT, SCALAR, VEC3, VEC4,
)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "public", "models")
os.makedirs(OUT, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [1.0]


# --- unit cube (24 verts, per-face normals, 36 indices), centered, size 1 ----
def unit_cube():
    p = np.array([
        [-.5, -.5,  .5], [.5, -.5,  .5], [.5,  .5,  .5], [-.5,  .5,  .5],   # +Z
        [.5, -.5, -.5], [-.5, -.5, -.5], [-.5,  .5, -.5], [.5,  .5, -.5],   # -Z
        [-.5, -.5, -.5], [-.5, -.5,  .5], [-.5,  .5,  .5], [-.5,  .5, -.5],  # -X
        [.5, -.5,  .5], [.5, -.5, -.5], [.5,  .5, -.5], [.5,  .5,  .5],      # +X
        [-.5,  .5,  .5], [.5,  .5,  .5], [.5,  .5, -.5], [-.5,  .5, -.5],    # +Y
        [-.5, -.5, -.5], [.5, -.5, -.5], [.5, -.5,  .5], [-.5, -.5,  .5],    # -Y
    ], dtype=np.float32)
    n = np.array([[0, 0, 1]] * 4 + [[0, 0, -1]] * 4 + [[-1, 0, 0]] * 4 +
                 [[1, 0, 0]] * 4 + [[0, 1, 0]] * 4 + [[0, -1, 0]] * 4, dtype=np.float32)
    idx = []
    for f in range(6):
        b = f * 4
        idx += [b, b + 1, b + 2, b, b + 2, b + 3]
    return p, n, np.array(idx, dtype=np.uint16)


def quat_x(angle):
    return [float(np.sin(angle / 2)), 0.0, 0.0, float(np.cos(angle / 2))]


def main():
    pos, nrm, idx = unit_cube()

    # walk-cycle keyframes (loop 1.0s)
    times = np.array([0, 0.25, 0.5, 0.75, 1.0], dtype=np.float32)
    legL = np.array([quat_x(a) for a in (0.5, 0.0, -0.5, 0.0, 0.5)], dtype=np.float32)
    legR = np.array([quat_x(a) for a in (-0.5, 0.0, 0.5, 0.0, -0.5)], dtype=np.float32)
    armL = np.array([quat_x(a) for a in (-0.4, 0.0, 0.4, 0.0, -0.4)], dtype=np.float32)
    armR = np.array([quat_x(a) for a in (0.4, 0.0, -0.4, 0.0, 0.4)], dtype=np.float32)
    hips = np.array([[0, 0.95 + b, 0] for b in (0.0, 0.05, 0.0, 0.05, 0.0)], dtype=np.float32)

    # --- pack one binary blob, build bufferViews + accessors ------------------
    blob = bytearray()
    bviews, accs = [], []

    def add(data, comp_type, acc_type, target=None, want_minmax=False):
        nonlocal blob
        while len(blob) % 4:
            blob += b"\x00"
        off = len(blob)
        raw = data.tobytes()
        blob += raw
        bv = BufferView(buffer=0, byteOffset=off, byteLength=len(raw))
        if target is not None:
            bv.target = target
        bviews.append(bv)
        acc = Accessor(bufferView=len(bviews) - 1, byteOffset=0, componentType=comp_type,
                       count=len(data), type=acc_type)
        if want_minmax:
            acc.min = data.min(axis=0).tolist() if data.ndim > 1 else [float(data.min())]
            acc.max = data.max(axis=0).tolist() if data.ndim > 1 else [float(data.max())]
        accs.append(acc)
        return len(accs) - 1

    a_pos = add(pos, FLOAT, VEC3, ARRAY_BUFFER, want_minmax=True)
    a_nrm = add(nrm, FLOAT, VEC3, ARRAY_BUFFER)
    a_idx = add(idx, UNSIGNED_SHORT, SCALAR, ELEMENT_ARRAY_BUFFER)
    a_time = add(times, FLOAT, SCALAR, want_minmax=True)
    a_legL = add(legL, FLOAT, VEC4)
    a_legR = add(legR, FLOAT, VEC4)
    a_armL = add(armL, FLOAT, VEC4)
    a_armR = add(armR, FLOAT, VEC4)
    a_hips = add(hips, FLOAT, VEC3)

    robe, skin, dark = hexc("#6a6f9a"), hexc("#c89a6a"), hexc("#3a2c22")
    materials = [
        Material(name="robe", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=robe, metallicFactor=0, roughnessFactor=0.9)),
        Material(name="skin", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=skin, metallicFactor=0, roughnessFactor=0.7)),
        Material(name="dark", pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=dark, metallicFactor=0, roughnessFactor=0.85)),
    ]
    # one mesh per material, all sharing the cube accessors
    meshes = [
        Mesh(name=m.name, primitives=[Primitive(attributes=Attributes(POSITION=a_pos, NORMAL=a_nrm), indices=a_idx, material=i)])
        for i, m in enumerate(materials)
    ]
    M_ROBE, M_SKIN, M_DARK = 0, 1, 2

    # --- node graph -----------------------------------------------------------
    nodes = []

    def node(**kw):
        nodes.append(Node(**kw))
        return len(nodes) - 1

    n_torso = node(name="torso", translation=[0, 0.30, 0], scale=[0.52, 0.72, 0.34], mesh=M_ROBE)
    n_head = node(name="head", translation=[0, 0.92, 0], scale=[0.40, 0.42, 0.40], mesh=M_SKIN)
    n_armLmesh = node(name="armL_mesh", translation=[0, -0.34, 0], scale=[0.16, 0.7, 0.16], mesh=M_ROBE)
    n_armRmesh = node(name="armR_mesh", translation=[0, -0.34, 0], scale=[0.16, 0.7, 0.16], mesh=M_ROBE)
    n_legLmesh = node(name="legL_mesh", translation=[0, -0.42, 0], scale=[0.19, 0.86, 0.22], mesh=M_DARK)
    n_legRmesh = node(name="legR_mesh", translation=[0, -0.42, 0], scale=[0.19, 0.86, 0.22], mesh=M_DARK)

    n_armL = node(name="armL", translation=[-0.34, 0.55, 0], children=[n_armLmesh])
    n_armR = node(name="armR", translation=[0.34, 0.55, 0], children=[n_armRmesh])
    n_legL = node(name="legL", translation=[-0.14, 0.0, 0], children=[n_legLmesh])
    n_legR = node(name="legR", translation=[0.14, 0.0, 0], children=[n_legRmesh])

    n_hips = node(name="hips", translation=[0, 0.95, 0],
                  children=[n_torso, n_head, n_armL, n_armR, n_legL, n_legR])
    n_root = node(name="pilgrim", translation=[0, 0, 0], children=[n_hips])

    # --- walk animation -------------------------------------------------------
    samplers = [
        AnimationSampler(input=a_time, output=a_legL, interpolation="LINEAR"),
        AnimationSampler(input=a_time, output=a_legR, interpolation="LINEAR"),
        AnimationSampler(input=a_time, output=a_armL, interpolation="LINEAR"),
        AnimationSampler(input=a_time, output=a_armR, interpolation="LINEAR"),
        AnimationSampler(input=a_time, output=a_hips, interpolation="LINEAR"),
    ]
    channels = [
        AnimationChannel(sampler=0, target={"node": n_legL, "path": "rotation"}),
        AnimationChannel(sampler=1, target={"node": n_legR, "path": "rotation"}),
        AnimationChannel(sampler=2, target={"node": n_armL, "path": "rotation"}),
        AnimationChannel(sampler=3, target={"node": n_armR, "path": "rotation"}),
        AnimationChannel(sampler=4, target={"node": n_hips, "path": "translation"}),
    ]
    anim = Animation(name="Walk", samplers=samplers, channels=channels)

    gltf = GLTF2(
        scene=0, scenes=[Scene(nodes=[n_root])], nodes=nodes, meshes=meshes,
        materials=materials, accessors=accs, bufferViews=bviews,
        buffers=[Buffer(byteLength=len(blob))], animations=[anim],
    )
    gltf.set_binary_blob(bytes(blob))
    path = os.path.join(OUT, "pilgrim.glb")
    gltf.save(path)
    print("wrote", path, f"({os.path.getsize(path)/1024:.1f} KB)")
    return path


if __name__ == "__main__":
    main()
