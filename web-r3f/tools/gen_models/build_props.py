#!/usr/bin/env python3
"""
Procedurally build STATIC hero-prop GLB models (Doubting Castle, Celestial Gate,
Wicket Gate) and write them to public/models/*.glb.

Real binary glTF assets (low-poly, stylised to match the game) that plug straight
into the <ModelProp src> pipeline. Authored directly in glTF/three coordinates:
Y is up, the gates face +Z. trimesh cylinders/cones are Z-axis, so those are
rotated onto Y; boxes and the (XY-plane) arch tori need no rotation.

Run:  python3 tools/gen_models/build_props.py
"""
import os
import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix
from trimesh.visual.material import PBRMaterial

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "public", "models")
os.makedirs(OUT, exist_ok=True)

RX_POS = rotation_matrix(np.pi / 2.0, [1, 0, 0])   # +Z -> +Y (axis up)
RX_NEG = rotation_matrix(-np.pi / 2.0, [1, 0, 0])  # +Z apex -> +Y (cone up)


def hexc(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def mat(color, metal=0.0, rough=0.9, emissive=None):
    m = PBRMaterial(baseColorFactor=[color[0], color[1], color[2], 1.0],
                    metallicFactor=float(metal), roughnessFactor=float(rough))
    if emissive is not None:
        m.emissiveFactor = list(emissive)
    return m


class Builder:
    def __init__(self):
        self.parts = []

    def _add(self, g, color, metal, rough, emissive):
        g.visual = trimesh.visual.TextureVisuals(material=mat(color, metal, rough, emissive))
        self.parts.append(g)
        return g

    def box(self, size, pos, color, metal=0.0, rough=0.9, emissive=None):
        g = trimesh.creation.box(extents=size)
        g.apply_translation(pos)
        return self._add(g, color, metal, rough, emissive)

    def cyl(self, radius, height, pos, color, sections=16, metal=0.0, rough=0.9, emissive=None):
        g = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
        g.apply_transform(RX_POS)            # axis Z -> Y (vertical)
        g.apply_translation(pos)
        return self._add(g, color, metal, rough, emissive)

    def cone(self, radius, height, pos, color, sections=16, metal=0.0, rough=0.9, emissive=None):
        g = trimesh.creation.cone(radius=radius, height=height, sections=sections)
        g.apply_transform(RX_NEG)            # base at y=pos.y, apex up +Y
        g.apply_translation(pos)
        return self._add(g, color, metal, rough, emissive)

    def arch(self, major, minor, pos, color, metal=0.0, rough=0.9, emissive=None):
        g = trimesh.creation.torus(major_radius=major, minor_radius=minor,
                                   major_sections=24, minor_sections=10)
        g.apply_translation(pos)             # ring in XY plane => vertical arch facing Z
        return self._add(g, color, metal, rough, emissive)

    def sphere(self, radius, pos, color, metal=0.0, rough=0.9, emissive=None):
        g = trimesh.creation.icosphere(subdivisions=1, radius=radius)
        g.apply_translation(pos)
        return self._add(g, color, metal, rough, emissive)

    def export(self, name):
        scene = trimesh.Scene()
        for i, p in enumerate(self.parts):
            scene.add_geometry(p, node_name=f"{name}_{i}", geom_name=f"{name}_{i}")
        path = os.path.join(OUT, f"{name}.glb")
        scene.export(path)
        return path


# ---------------------------------------------------------------------------
def build_doubting_castle():
    b = Builder()
    stone, dark, roofc = hexc("#6b6359"), hexc("#544d45"), hexc("#3a2e3a")
    R, WH = 9.0, 6.0   # half-span of curtain-wall square; wall height
    b.box([2 * R, WH, 1.0], [0, WH / 2, -R], stone)                 # back wall (-Z)
    b.box([1.0, WH, 2 * R], [-R, WH / 2, 0], stone)                 # left wall (-X)
    b.box([1.0, WH, 2 * R], [R, WH / 2, 0], stone)                  # right wall (+X)
    for sx in (-1, 1):                                              # front wall w/ central gap (+Z)
        b.box([6.0, WH, 1.0], [sx * 6.0, WH / 2, R], stone)
    for x in np.linspace(-R + 1, R - 1, 9):                         # crenellations front/back
        b.box([1, 1, 1], [x, WH + 0.5, -R], dark)
        b.box([1, 1, 1], [x, WH + 0.5, R], dark)
    for z in np.linspace(-R + 1, R - 1, 9):                         # crenellations sides
        b.box([1, 1, 1], [-R, WH + 0.5, z], dark)
        b.box([1, 1, 1], [R, WH + 0.5, z], dark)
    for sx in (-1, 1):                                              # corner towers + roofs
        for sz in (-1, 1):
            cx, cz = sx * R, sz * R
            b.cyl(2.0, 9.0, [cx, 4.5, cz], stone, sections=18)
            b.cone(2.4, 3.0, [cx, 9.0, cz], roofc, sections=18)
    b.box([5, 9, 5], [0, 4.5, -R + 2.5], dark)                      # central keep
    b.cone(3.6, 3.4, [0, 9.0, -R + 2.5], roofc, sections=4)
    for sx in (-1, 1):                                              # front gatehouse towers
        b.box([2.2, 7.5, 2.2], [sx * 3.2, 3.75, R], dark)
    b.box([8.6, 1.6, 2.2], [0, 7.2, R], stone)                     # gatehouse lintel
    return b.export("doubting_castle")


def build_celestial_gate():
    b = Builder()
    gold, glow, bright = hexc("#ffe6a0"), hexc("#ffcf6a"), hexc("#fff6d0")
    em = [0.35 * g for g in glow]
    for sx in (-1, 1):
        b.box([1.6, 9, 1.6], [sx * 3.2, 4.5, 0], gold, metal=0.9, rough=0.25, emissive=em)
        b.box([2.2, 0.6, 2.2], [sx * 3.2, 0.3, 0], gold, metal=0.9, rough=0.3)
        b.box([2.2, 0.7, 2.2], [sx * 3.2, 9.2, 0], gold, metal=0.9, rough=0.3)
    b.box([8.4, 1.5, 1.6], [0, 9.9, 0], gold, metal=0.9, rough=0.25, emissive=[0.4 * g for g in glow])
    b.cyl(0.9, 0.7, [0, 11.0, 0], gold, sections=8, metal=0.9, rough=0.25, emissive=[0.5 * g for g in glow])
    b.box([4.6, 7.2, 0.3], [0, 3.8, 0], bright, rough=0.4, emissive=bright)            # radiant doorway
    b.arch(2.4, 0.35, [0, 7.6, 0], gold, metal=0.9, rough=0.3, emissive=[0.3 * g for g in glow])
    return b.export("celestial_gate")


def build_wicket_gate():
    b = Builder()
    stone, wood, iron, lamp = hexc("#8a8478"), hexc("#3c3022"), hexc("#2a2622"), hexc("#fff0b0")
    for sx in (-1, 1):
        x = sx * 1.7
        b.box([1.0, 0.6, 1.0], [x, 0.3, 0], stone)
        b.cyl(0.36, 3.6, [x, 2.3, 0], stone, sections=12)
        b.box([0.9, 0.4, 0.9], [x, 4.2, 0], stone)
        b.cyl(0.16, 0.32, [x, 4.65, 0], lamp, sections=10, emissive=[0.9, 0.7, 0.35])
    b.arch(1.7, 0.32, [0, 4.4, 0], stone)
    b.box([0.5, 0.7, 0.6], [0, 6.1, 0], hexc("#9a9488"))
    b.box([2.5, 3.7, 0.28], [0, 1.9, 0], wood)
    for y in (1.1, 2.7):
        b.box([2.5, 0.18, 0.06], [0, y, 0.16], iron, metal=0.5, rough=0.6)
    for x in (-0.9, -0.3, 0.3, 0.9):
        for y in (1.1, 2.7):
            b.sphere(0.06, [x, y, 0.2], iron, metal=0.6, rough=0.5)
    return b.export("wicket_gate")


def report(path):
    g = trimesh.load(path)
    ext = g.bounds[1] - g.bounds[0]
    nmesh = len(g.geometry) if hasattr(g, "geometry") else 1
    axis = "XYZ"[int(np.argmax(ext))]
    print(f"  {os.path.basename(path):22s} {os.path.getsize(path)/1024:6.1f} KB  meshes={nmesh:2d}  "
          f"extent(XYZ)=({ext[0]:.1f},{ext[1]:.1f},{ext[2]:.1f})  widest={axis}")


if __name__ == "__main__":
    print("Building hero props ->", os.path.abspath(OUT))
    for fn in (build_doubting_castle, build_celestial_gate, build_wicket_gate):
        report(fn())
    print("done.")
