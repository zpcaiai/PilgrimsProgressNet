"""Blender (bpy) backend for the shared scene definitions -- high-fidelity path.

``BlenderScene`` has the SAME public API as ``glb_lib.Scene`` (box / ground /
cylinder / cone / sphere / torus / lathe / pyramid / ramp / composite / zone /
marker / save / node_names). The chapter builders in
``tools/scene_gen/scene_defs.py`` only call that API, so
``scene_defs.Scene = BlenderScene`` lets the very same layout code drive Blender.

Geometry is generated from the SAME ``glb_lib`` primitive functions used by the
dependency-free writer, so a prop here is the prop emitted by the no-Blender
path -- object-for-object. On top of that, the Blender path adds true render
quality:

* Principled BSDF materials with inferred metallic / roughness (gold shines,
  water is glossy, stone/wood/foliage read apart) + emissive glows, and a faint
  procedural bump so flat colour reads as a surface.
* Smooth shading on curved meshes (cylinder / cone / sphere / torus / lathe /
  terrain); crisp flat shading on chamfered boxes.
* Optional HIGH-RES bake mode (set env ``PILGRIM_HIFI=1``) that adds a Bevel +
  Subdivision-Surface + micro-displacement pass and bakes it on export -- a
  proper high-poly "3D Max" source for hero renders. Default off keeps the
  exported GLB web-light and identical in silhouette to the lightweight build.

Run:

    blender --background --python tools/blender/export_all_glb.py
    PILGRIM_HIFI=1 blender --background --python tools/blender/export_all_glb.py
"""

import math
import os
import sys

import bpy  # provided by Blender's bundled Python

_HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (_HERE, os.path.join(_HERE, "..", "scene_gen")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from glb_lib import (  # noqa: E402
    box_tris, box_tris_bevel, pyramid_tris, plane_tris, wedge_tris,
    cylinder_mesh, cone_mesh, sphere_mesh, torus_mesh, lathe_mesh,
    terrain_mesh, infer_pbr, _orient_outward,
)

HIFI = os.environ.get("PILGRIM_HIFI", "") not in ("", "0", "false", "False")
BEVEL_MIN_DIM = 0.30


def _clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.node_groups):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def _set_input(bsdf, names, value):
    for nm in names:
        if nm in bsdf.inputs:
            bsdf.inputs[nm].default_value = value
            return True
    return False


def _material(name, rgba, emissive=(0, 0, 0), metallic=0.0, roughness=0.8,
              blend=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is not None:
        r, g, b = rgba[0], rgba[1], rgba[2]
        a = rgba[3] if len(rgba) > 3 else 1.0
        _set_input(bsdf, ("Base Color",), (r, g, b, a))
        _set_input(bsdf, ("Metallic",), metallic)
        _set_input(bsdf, ("Roughness",), roughness)
        # gentle dielectric specular unless metal
        _set_input(bsdf, ("Specular IOR Level", "Specular"),
                   0.5 if metallic > 0.5 else 0.3)
        if any(emissive):
            _set_input(bsdf, ("Emission Color", "Emission"),
                       (emissive[0], emissive[1], emissive[2], 1.0))
            _set_input(bsdf, ("Emission Strength",), 1.2)
        if blend:
            _set_input(bsdf, ("Alpha",), a)
            mat.blend_method = "BLEND"
        # faint procedural bump so a flat colour reads as a real surface
        if not blend and HIFI:
            tex = nt.nodes.new("ShaderNodeTexNoise")
            tex.inputs["Scale"].default_value = 12.0
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.05
            nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
            if "Normal" in bsdf.inputs:
                nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _shade(obj, smooth):
    me = obj.data
    for poly in me.polygons:
        poly.use_smooth = smooth
    if smooth and hasattr(me, "use_auto_smooth"):
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(40)


def _hifi(obj, organic):
    if not HIFI:
        return
    if organic:
        m = obj.modifiers.new("subsurf", "SUBSURF")
        m.levels = 1
        m.render_levels = 2
    else:
        m = obj.modifiers.new("bevel", "BEVEL")
        m.width = 0.015
        m.segments = 2
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(40)


def _mesh_from_tris(name, tris, mat, smooth=False, organic=False):
    verts, faces = [], []
    for (p0, p1, p2) in tris:
        base = len(verts)
        verts.extend([p0, p1, p2])
        faces.append((base, base + 1, base + 2))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    _shade(obj, smooth)
    _hifi(obj, organic)
    return obj


def _mesh_from_indexed(name, P, N, I, mat, organic=True):
    faces = [(I[i], I[i + 1], I[i + 2]) for i in range(0, len(I), 3)]
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata([tuple(p) for p in P], [], faces)
    me.update()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    _shade(obj, True)
    _hifi(obj, organic)
    return obj


def _empty(name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _set_transform(obj, pos=(0, 0, 0), rot=(0, 0, 0)):
    obj.location = (pos[0], pos[1], pos[2])
    obj.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]),
                          math.radians(rot[2]))


def _pbr(name, color, metallic, roughness):
    m, r = infer_pbr(name, color)
    if metallic is not None:
        m = metallic
    if roughness is not None:
        r = roughness
    return m, r


class BlenderScene:
    """Drop-in replacement for glb_lib.Scene that builds bpy objects."""

    def __init__(self, name):
        self.name = name
        self._names = []
        _clear_scene()

    # --- visible primitives ---
    def box(self, name, size, color, pos=(0, 0, 0), rot=(0, 0, 0),
            emissive=None, metallic=None, roughness=None, bevel=True):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        if bevel and min(size) >= BEVEL_MIN_DIM:
            tris = box_tris_bevel(*size)
        else:
            tris = box_tris(*size)
        obj = _mesh_from_tris(name, tris, mat, smooth=False, organic=False)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def ground(self, name, size, color, pos=(0, 0, 0), flat=False):
        m, r = _pbr(name, color, None, None)
        mat = _material(name, color, (0, 0, 0), m, r)
        if flat:
            obj = _mesh_from_tris(name, box_tris(size[0], 0.5, size[1]), mat)
            _set_transform(obj, (pos[0], pos[1] - 0.25, pos[2]))
        else:
            seed = (abs(hash(name)) % 9973) + 1
            P, N, I = terrain_mesh(size[0], size[1], amp=0.07, seed=seed,
                                   base_y=0.0, skirt=0.6)
            obj = _mesh_from_indexed(name, P, N, I, mat, organic=False)
            _set_transform(obj, (pos[0], pos[1], pos[2]))
        self._names.append(name)
        return obj

    def cylinder(self, name, radius, height, color, pos=(0, 0, 0), rot=(0, 0, 0),
                 sides=24, emissive=None, metallic=None, roughness=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        P, N, I = cylinder_mesh(radius, height, max(8, sides))
        obj = _mesh_from_indexed(name, P, N, I, mat, organic=False)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def cone(self, name, radius, height, color, pos=(0, 0, 0), rot=(0, 0, 0),
             sides=24, emissive=None, metallic=None, roughness=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        P, N, I = cone_mesh(radius, height, max(8, sides))
        obj = _mesh_from_indexed(name, P, N, I, mat, organic=False)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def sphere(self, name, radius, color, pos=(0, 0, 0), rot=(0, 0, 0),
               segs=24, rings=14, emissive=None, metallic=None, roughness=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        P, N, I = sphere_mesh(radius, segs, rings)
        obj = _mesh_from_indexed(name, P, N, I, mat, organic=True)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def torus(self, name, ring_r, tube_r, color, pos=(0, 0, 0), rot=(0, 0, 0),
              segs=28, sides=14, emissive=None, metallic=None, roughness=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        P, N, I = torus_mesh(ring_r, tube_r, segs, sides)
        obj = _mesh_from_indexed(name, P, N, I, mat, organic=True)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def lathe(self, name, profile, color, pos=(0, 0, 0), rot=(0, 0, 0),
              segs=24, emissive=None, metallic=None, roughness=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        P, N, I = lathe_mesh(profile, segs)
        obj = _mesh_from_indexed(name, P, N, I, mat, organic=True)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def pyramid(self, name, size, height, color, pos=(0, 0, 0), rot=(0, 0, 0),
                metallic=None, roughness=None, emissive=None):
        m, r = _pbr(name, color, metallic, roughness)
        mat = _material(name, color, emissive or (0, 0, 0), m, r)
        obj = _mesh_from_tris(name, _orient_outward(
            pyramid_tris(size[0], size[1], height)), mat)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def ramp(self, name, width, run, height, color, pos=(0, 0, 0), rot=(0, 0, 0)):
        m, r = _pbr(name, color, None, None)
        mat = _material(name, color, (0, 0, 0), m, r)
        obj = _mesh_from_tris(name, _orient_outward(
            wedge_tris(width, run, height)), mat)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    def composite(self, name, parts, pos=(0, 0, 0), rot=(0, 0, 0)):
        parent = _empty(name)
        _set_transform(parent, pos, rot)
        for p in parts:
            kind = p.get("kind", "box")
            col = p["color"]
            m, r = _pbr(name, col, p.get("metallic"), p.get("roughness"))
            mat = _material("VIS_" + name, col, p.get("emissive") or (0, 0, 0),
                            m, r)
            organic = kind in ("sphere", "torus", "lathe", "cylinder", "cone")
            if kind == "box":
                size = p["size"]
                if min(size) >= BEVEL_MIN_DIM and p.get("bevel", True):
                    child = _mesh_from_tris("VIS_" + name, box_tris_bevel(*size),
                                            mat, organic=False)
                else:
                    child = _mesh_from_tris("VIS_" + name, box_tris(*size), mat)
            elif kind == "cylinder":
                P, N, I = cylinder_mesh(p["radius"], p["height"], p.get("sides", 24))
                child = _mesh_from_indexed("VIS_" + name, P, N, I, mat, organic=False)
            elif kind == "cone":
                P, N, I = cone_mesh(p["radius"], p["height"], p.get("sides", 24))
                child = _mesh_from_indexed("VIS_" + name, P, N, I, mat, organic=False)
            elif kind == "sphere":
                P, N, I = sphere_mesh(p["radius"], p.get("segs", 22), p.get("rings", 12))
                child = _mesh_from_indexed("VIS_" + name, P, N, I, mat)
            elif kind == "torus":
                P, N, I = torus_mesh(p["ring_r"], p["tube_r"], p.get("segs", 26),
                                     p.get("sides", 12))
                child = _mesh_from_indexed("VIS_" + name, P, N, I, mat)
            elif kind == "lathe":
                P, N, I = lathe_mesh(p["profile"], p.get("segs", 22))
                child = _mesh_from_indexed("VIS_" + name, P, N, I, mat)
            elif kind == "pyramid":
                child = _mesh_from_tris("VIS_" + name, _orient_outward(
                    pyramid_tris(p["size"][0], p["size"][1], p["height"])), mat)
            elif kind == "plane":
                child = _mesh_from_tris("VIS_" + name, plane_tris(*p["size"]), mat)
            else:
                child = _mesh_from_tris("VIS_" + name, box_tris(*p.get("size", (1, 1, 1))), mat)
            _set_transform(child, p.get("pos", (0, 0, 0)), p.get("rot", (0, 0, 0)))
            child.parent = parent
        self._names.append(name)
        return parent

    # --- zones (transparent collision/trigger volumes; exact plain boxes) ---
    def zone(self, name, size, pos=(0, 0, 0), color=(0.6, 0.3, 0.3, 0.22)):
        mat = _material(name, color, (0, 0, 0), 0.0, 1.0, blend=True)
        obj = _mesh_from_tris(name, box_tris(*size), mat)
        _set_transform(obj, pos)
        self._names.append(name)
        return obj

    # --- markers (empties) ---
    def marker(self, name, pos=(0, 0, 0), rot=(0, 0, 0)):
        obj = _empty(name)
        _set_transform(obj, pos, rot)
        self._names.append(name)
        return obj

    # --- output ---
    def save(self, path):
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            export_apply=True,
            export_yup=True,
        )
        return os.path.getsize(path) if os.path.exists(path) else 0

    def node_names(self):
        return list(self._names)
