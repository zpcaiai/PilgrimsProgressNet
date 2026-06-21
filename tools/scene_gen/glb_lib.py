"""Dependency-free glTF 2.0 / GLB writer for the Pilgrim's Progress scene pipeline.

Pure standard library. Emits binary .glb files that import cleanly into Godot 4
as a tree of Node3D / MeshInstance3D nodes whose names are preserved exactly
(so ImportedSceneBinder.gd can attach gameplay by name prefix). Marker objects
(NPC_/SPAWN_/TRIGGER_/CAM_/VFX_/PATH_/LIGHT_) are emitted as empty nodes.

HIGH-FIDELITY UPGRADE ("3D Max" look, web-safe)
-----------------------------------------------
This was a flat-shaded "triangle soup" greybox writer. It is now a compact
render-grade primitive kit that still fits a browser (Godot gl_compatibility +
auto-LOD):

* Boxes are CHAMFERED (beveled edges) so they catch a specular highlight along
  every edge instead of reading as flat cardboard.  Thin slabs (roads, floors,
  panels) stay flat to save triangles and keep collision flush.
* Cylinders / cones / spheres / tori / lathed profiles carry SMOOTH analytic
  normals at higher tessellation, so curved surfaces read as curved.
* Ground is a gently undulating, tessellated terrain surface (tiny amplitude so
  it stays walkable and props stay flush) instead of a flat slab.
* Materials are real PBR: per-surface metallic / roughness inferred from the
  node name + colour (gold/metal shines, water is glossy, stone/wood/foliage
  read distinctly), plus emissive for glows.

Winding is made bulletproof: convex flat meshes are oriented outward from their
own centroid, and every smooth indexed mesh has its triangle winding aligned to
its analytic normals -- so no face is ever back-culled by accident.

The same module backs both the no-Blender exporter (build_scenes.py) and the
Blender scripts (tools/blender/*), which translate the very same definitions
into bpy with real modifiers (bevel / subdivision / smooth shading).
"""

from __future__ import annotations

import json
import math
import os
import struct

# PBR texture library shipped with the project (albedo, normal) keyed by name.
_TEX_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "assets", "textures", "pbr"))
_TEX = {
    "brick": ("brick_albedo.png", "brick_normal.png"),
    "rooftile": ("rooftile_albedo.png", "rooftile_normal.png"),
    "stone": ("stone_albedo.png", "stone_normal.png"),
    "wood": ("wood_albedo.png", "wood_normal.png"),
    "cobble": ("cobble_albedo.png", "cobble_normal.png"),
}


def tex_paths(name):
    """(albedo_path, normal_path|None) for a named PBR texture, or (None, None)
    if the files are missing (graceful degrade -> solid colour)."""
    pair = _TEX.get(name)
    if not pair:
        return None, None
    alb = os.path.join(_TEX_DIR, pair[0])
    nrm = os.path.join(_TEX_DIR, pair[1]) if pair[1] else None
    if not os.path.exists(alb):
        return None, None
    if nrm and not os.path.exists(nrm):
        nrm = None
    return alb, nrm

# glTF component / target constants
_FLOAT = 5126
_UINT = 5125
_ARRAY_BUFFER = 34962
_ELEMENT_ARRAY_BUFFER = 34963


# ---------------------------------------------------------------------------
# Small vector / quaternion helpers
# ---------------------------------------------------------------------------
def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _normalize(v):
    m = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if m < 1e-9:
        return (0.0, 1.0, 0.0)
    return (v[0] / m, v[1] / m, v[2] / m)


def _face_normal(p0, p1, p2):
    return _normalize(_cross(_sub(p1, p0), _sub(p2, p0)))


def _quat_axis(axis, deg):
    a = math.radians(deg) * 0.5
    s = math.sin(a)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(a))


def _quat_mul(q1, q2):
    x1, y1, z1, w1 = q1
    x2, y2, z2, w2 = q2
    return (
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    )


def euler_to_quat(rx, ry, rz):
    """Euler degrees -> glTF quaternion [x,y,z,w] (applied Z, then Y, then X)."""
    qx = _quat_axis((1.0, 0.0, 0.0), rx)
    qy = _quat_axis((0.0, 1.0, 0.0), ry)
    qz = _quat_axis((0.0, 0.0, 1.0), rz)
    return _quat_mul(_quat_mul(qz, qy), qx)


def _orient_outward(tris):
    """Flip any triangle whose normal points toward the mesh centroid, so a
    convex, roughly-centred mesh always shows its outside. Winding-proof."""
    pts = [p for t in tris for p in t]
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    cz = sum(p[2] for p in pts) / n
    centre = (cx, cy, cz)
    out = []
    for (a, b, c) in tris:
        nrm = _face_normal(a, b, c)
        mid = ((a[0] + b[0] + c[0]) / 3.0, (a[1] + b[1] + c[1]) / 3.0,
               (a[2] + b[2] + c[2]) / 3.0)
        if _dot(nrm, _sub(mid, centre)) < 0.0:
            out.append((a, c, b))
        else:
            out.append((a, b, c))
    return out


# ---------------------------------------------------------------------------
# Deterministic value noise (terrain micro-relief). Stable across runs so the
# generated GLBs are reproducible (important for verify/CI and diffs).
# ---------------------------------------------------------------------------
def _hash01(ix, iz, seed):
    h = (ix * 374761393 + iz * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFF) / float(0xFFFFFF)


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def _value_noise(x, z, seed):
    ix, iz = math.floor(x), math.floor(z)
    fx, fz = x - ix, z - iz
    v00 = _hash01(ix, iz, seed)
    v10 = _hash01(ix + 1, iz, seed)
    v01 = _hash01(ix, iz + 1, seed)
    v11 = _hash01(ix + 1, iz + 1, seed)
    sx, sz = _smooth(fx), _smooth(fz)
    a = v00 + (v10 - v00) * sx
    b = v01 + (v11 - v01) * sx
    return (a + (b - a) * sz) * 2.0 - 1.0  # -> [-1, 1]


# ---------------------------------------------------------------------------
# Flat / convex primitive geometry -> list of triangles (tuple of three points)
# ---------------------------------------------------------------------------
def box_tris(sx, sy, sz):
    """Sharp-edged box (used for zones / thin slabs where bevel is wasteful)."""
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    c = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
         (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz)]
    quads = [
        (0, 1, 2, 3), (7, 6, 5, 4), (4, 5, 1, 0),
        (6, 7, 3, 2), (5, 6, 2, 1), (7, 4, 0, 3),
    ]
    tris = []
    for a, b, d, e in quads:
        tris.append((c[a], c[b], c[d]))
        tris.append((c[a], c[d], c[e]))
    return tris


def box_tris_bevel(sx, sy, sz, bevel=None):
    """Chamfered box: each of the 6 faces becomes an octagon, the 12 edges
    become little 45-degree quads and the 8 corners become triangles. Flat
    shaded -- the crisp chamfers catch edge highlights (the "not cardboard"
    win). Winding is fixed afterward by _orient_outward."""
    mn = min(sx, sy, sz)
    if bevel is None:
        bevel = max(0.02, min(0.12, 0.05 * mn))
    b = min(bevel, mn * 0.45)
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    ix, iy, iz = hx - b, hy - b, hz - b
    tris = []

    # 6 octagonal faces. For each axis-aligned face, 8 inset corners.
    def face(axis, sign):
        out = []
        if axis == 0:   # +/-X face, plane x = sign*hx
            x = sign * hx
            ring = [(x, sign * iy, hz) if False else None]
            pts = [(x, iy, hz), (x, hy, iz), (x, hy, -iz), (x, iy, -hz),
                   (x, -iy, -hz), (x, -hy, -iz), (x, -hy, iz), (x, -iy, hz)]
        elif axis == 1:  # +/-Y face, plane y = sign*hy
            y = sign * hy
            pts = [(ix, y, hz), (hx, y, iz), (hx, y, -iz), (ix, y, -hz),
                   (-ix, y, -hz), (-hx, y, -iz), (-hx, y, iz), (-ix, y, hz)]
        else:            # +/-Z face, plane z = sign*hz
            z = sign * hz
            pts = [(ix, hy, z), (hx, iy, z), (hx, -iy, z), (ix, -hy, z),
                   (-ix, -hy, z), (-hx, -iy, z), (-hx, iy, z), (-ix, hy, z)]
        for i in range(1, 7):
            out.append((pts[0], pts[i], pts[i + 1]))
        return out

    for axis in (0, 1, 2):
        for sign in (1, -1):
            tris.extend(face(axis, sign))

    # 12 edge chamfer quads + 8 corner triangles, built from corner-pulled verts.
    corners = [(sxg, syg, szg) for sxg in (1, -1)
               for syg in (1, -1) for szg in (1, -1)]

    def cv(sg, axis):
        # corner sg pulled in by b along `axis`
        x = sg[0] * (ix if axis == 0 else hx)
        y = sg[1] * (iy if axis == 1 else hy)
        z = sg[2] * (iz if axis == 2 else hz)
        return (x, y, z)

    # edges: pairs of corners differing in exactly one axis -> chamfer quad
    seen = set()
    for ca in corners:
        for axis in (0, 1, 2):
            cb = list(ca)
            cb[axis] = -ca[axis]
            cb = tuple(cb)
            key = tuple(sorted([ca, cb]))
            if key in seen:
                continue
            seen.add(key)
            other = [a for a in (0, 1, 2) if a != axis]
            v0 = cv(ca, other[0])
            v1 = cv(ca, other[1])
            v2 = cv(cb, other[1])
            v3 = cv(cb, other[0])
            tris.append((v0, v1, v2))
            tris.append((v0, v2, v3))

    for ca in corners:
        tris.append((cv(ca, 0), cv(ca, 1), cv(ca, 2)))

    return _orient_outward(tris)


def box_uv(sx, sy, sz, tile=1.4):
    """Plain (sharp) box with per-face planar UVs tiled by world size -- for
    textured surfaces (brick walls etc.). Returns (positions, normals, uvs,
    indices); winding aligned to the outward normals."""
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    # origin corner, u-axis, v-axis, outward normal, u-extent, v-extent
    faces = [
        ((hx, -hy, -hz), (0, 0, 1), (0, 1, 0), (1, 0, 0), sz, sy),    # +X
        ((-hx, -hy, hz), (0, 0, -1), (0, 1, 0), (-1, 0, 0), sz, sy),  # -X
        ((-hx, hy, -hz), (1, 0, 0), (0, 0, 1), (0, 1, 0), sx, sz),    # +Y
        ((-hx, -hy, hz), (1, 0, 0), (0, 0, -1), (0, -1, 0), sx, sz),  # -Y
        ((hx, -hy, hz), (-1, 0, 0), (0, 1, 0), (0, 0, 1), sx, sy),    # +Z
        ((-hx, -hy, -hz), (1, 0, 0), (0, 1, 0), (0, 0, -1), sx, sy),  # -Z
    ]
    P, N, UV, I = [], [], [], []
    for origin, uax, vax, nrm, wu, wv in faces:
        c0 = origin
        c1 = _add(origin, _scale(uax, wu))
        c2 = _add(c1, _scale(vax, wv))
        c3 = _add(origin, _scale(vax, wv))
        base = len(P)
        for c in (c0, c1, c2, c3):
            P.append(c)
            N.append(nrm)
        for uu, vv in ((0, 0), (wu / tile, 0), (wu / tile, wv / tile), (0, wv / tile)):
            UV.append((uu, vv))
        I.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    return P, N, UV, _align_winding(P, N, I)


def pyramid_uv(sx, sz, height, tile=1.2):
    """Pyramid with UVs on its 4 slopes (+ base) so a roof-tile texture tiles
    across the pitched faces. Returns (positions, normals, uvs, indices)."""
    hx, hz = sx / 2.0, sz / 2.0
    apex = (0.0, height / 2.0, 0.0)
    by = -height / 2.0
    b = [(-hx, by, -hz), (hx, by, -hz), (hx, by, hz), (-hx, by, hz)]
    P, N, UV, I = [], [], [], []
    for (p0, p1) in [(b[0], b[1]), (b[1], b[2]), (b[2], b[3]), (b[3], b[0])]:
        nrm = _face_normal(p0, p1, apex)
        edge = math.dist(p0, p1)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        slant = math.dist(apex, mid)
        base = len(P)
        P.append(p0); N.append(nrm); UV.append((0.0, 0.0))
        P.append(p1); N.append(nrm); UV.append((edge / tile, 0.0))
        P.append(apex); N.append(nrm); UV.append((edge / tile / 2.0, slant / tile))
        I.extend([base, base + 1, base + 2])
    base = len(P)
    for c, uv in zip(b, [(0, 0), (sx / tile, 0), (sx / tile, sz / tile), (0, sz / tile)]):
        P.append(c); N.append((0, -1, 0)); UV.append(uv)
    I.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    return P, N, UV, _align_winding(P, N, I)


def plane_tris(sx, sz):
    hx, hz = sx / 2.0, sz / 2.0
    a = (-hx, 0.0, -hz)
    b = (hx, 0.0, -hz)
    d = (hx, 0.0, hz)
    e = (-hx, 0.0, hz)
    return [(a, b, d), (a, d, e)]


def cylinder_tris(radius, height, sides=10):
    """Legacy flat cylinder (kept for compatibility / Blender import)."""
    hy = height / 2.0
    tris = []
    ring = [(radius * math.cos(2 * math.pi * i / sides),
             radius * math.sin(2 * math.pi * i / sides)) for i in range(sides)]
    for i in range(sides):
        x0, z0 = ring[i]
        x1, z1 = ring[(i + 1) % sides]
        bl = (x0, -hy, z0)
        br = (x1, -hy, z1)
        tl = (x0, hy, z0)
        tr = (x1, hy, z1)
        tris.append((bl, br, tr))
        tris.append((bl, tr, tl))
        tris.append(((0, hy, 0), tl, tr))
        tris.append(((0, -hy, 0), br, bl))
    return tris


def cone_tris(radius, height, sides=10):
    hy = height / 2.0
    apex = (0.0, hy, 0.0)
    tris = []
    ring = [(radius * math.cos(2 * math.pi * i / sides), -hy,
             radius * math.sin(2 * math.pi * i / sides)) for i in range(sides)]
    for i in range(sides):
        a = ring[i]
        b = ring[(i + 1) % sides]
        tris.append((a, b, apex))
        tris.append(((0, -hy, 0), b, a))
    return tris


def pyramid_tris(sx, sz, height):
    hx, hz = sx / 2.0, sz / 2.0
    apex = (0.0, height / 2.0, 0.0)
    by = -height / 2.0
    b0 = (-hx, by, -hz)
    b1 = (hx, by, -hz)
    b2 = (hx, by, hz)
    b3 = (-hx, by, hz)
    return [(b0, b1, apex), (b1, b2, apex), (b2, b3, apex), (b3, b0, apex),
            (b0, b2, b1), (b0, b3, b2)]


def wedge_tris(width, run, height):
    """A walkable ramp prism (see original docstring). Convex; _orient_outward
    keeps winding correct."""
    hw = width / 2.0
    bl0 = (-hw, 0.0, 0.0)
    br0 = (hw, 0.0, 0.0)
    blr = (-hw, 0.0, -run)
    brr = (hw, 0.0, -run)
    tlr = (-hw, height, -run)
    trr = (hw, height, -run)
    return [
        (bl0, blr, brr), (bl0, brr, br0),
        (bl0, br0, trr), (bl0, trr, tlr),
        (blr, tlr, trr), (blr, trr, brr),
        (bl0, blr, tlr),
        (br0, trr, brr),
    ]


# ---------------------------------------------------------------------------
# Smooth indexed primitives -> (positions, normals, indices)
# ---------------------------------------------------------------------------
def _align_winding(positions, normals, indices):
    """Flip triangle winding so it agrees with the analytic vertex normals
    (front faces never back-culled), and drop degenerate (zero-area)
    triangles -- e.g. the collapsed quads at sphere/cone poles."""
    out = []
    for i in range(0, len(indices), 3):
        a, b, c = indices[i], indices[i + 1], indices[i + 2]
        cr = _cross(_sub(positions[b], positions[a]),
                    _sub(positions[c], positions[a]))
        if (cr[0] * cr[0] + cr[1] * cr[1] + cr[2] * cr[2]) < 1e-12:
            continue  # degenerate
        an = (normals[a][0] + normals[b][0] + normals[c][0],
              normals[a][1] + normals[b][1] + normals[c][1],
              normals[a][2] + normals[b][2] + normals[c][2])
        if _dot(cr, an) < 0.0:
            out.extend([a, c, b])
        else:
            out.extend([a, b, c])
    return out


def cylinder_mesh(radius, height, sides=24):
    hy = height / 2.0
    P, N, I = [], [], []
    # barrel (smooth radial normals; rim duplicated for top/bottom)
    for i in range(sides + 1):
        ang = 2.0 * math.pi * i / sides
        cx, cz = math.cos(ang), math.sin(ang)
        P.append((radius * cx, -hy, radius * cz)); N.append((cx, 0.0, cz))
        P.append((radius * cx, hy, radius * cz)); N.append((cx, 0.0, cz))
    for i in range(sides):
        b0 = i * 2
        I.extend([b0, b0 + 1, b0 + 3, b0, b0 + 3, b0 + 2])
    # caps (flat, own verts)
    top_c = len(P); P.append((0.0, hy, 0.0)); N.append((0, 1, 0))
    bot_c = len(P); P.append((0.0, -hy, 0.0)); N.append((0, -1, 0))
    top0 = len(P)
    for i in range(sides):
        ang = 2.0 * math.pi * i / sides
        P.append((radius * math.cos(ang), hy, radius * math.sin(ang)))
        N.append((0, 1, 0))
    bot0 = len(P)
    for i in range(sides):
        ang = 2.0 * math.pi * i / sides
        P.append((radius * math.cos(ang), -hy, radius * math.sin(ang)))
        N.append((0, -1, 0))
    for i in range(sides):
        j = (i + 1) % sides
        I.extend([top_c, top0 + i, top0 + j])
        I.extend([bot_c, bot0 + j, bot0 + i])
    return P, N, _align_winding(P, N, I)


def cone_mesh(radius, height, sides=24):
    hy = height / 2.0
    slope = _normalize((height, radius, 0.0))  # |(dy=h over dr=r)| side normal magnitude
    P, N, I = [], [], []
    apex_y = hy
    for i in range(sides + 1):
        ang = 2.0 * math.pi * i / sides
        cx, cz = math.cos(ang), math.sin(ang)
        # side normal: radial component slope[0], up component slope[1]
        nrm = _normalize((cx * slope[0], slope[1], cz * slope[0]))
        P.append((radius * cx, -hy, radius * cz)); N.append(nrm)
        P.append((0.0, apex_y, 0.0)); N.append(nrm)
    for i in range(sides):
        b0 = i * 2
        I.extend([b0, b0 + 2, b0 + 1])
    bot_c = len(P); P.append((0.0, -hy, 0.0)); N.append((0, -1, 0))
    bot0 = len(P)
    for i in range(sides):
        ang = 2.0 * math.pi * i / sides
        P.append((radius * math.cos(ang), -hy, radius * math.sin(ang)))
        N.append((0, -1, 0))
    for i in range(sides):
        j = (i + 1) % sides
        I.extend([bot_c, bot0 + j, bot0 + i])
    return P, N, _align_winding(P, N, I)


def sphere_mesh(radius, segs=24, rings=14):
    P, N, I = [], [], []
    for r in range(rings + 1):
        v = math.pi * r / rings
        y = math.cos(v)
        rad = math.sin(v)
        for s in range(segs + 1):
            u = 2.0 * math.pi * s / segs
            nx, ny, nz = rad * math.cos(u), y, rad * math.sin(u)
            P.append((radius * nx, radius * ny, radius * nz))
            N.append((nx, ny, nz))
    row = segs + 1
    for r in range(rings):
        for s in range(segs):
            a = r * row + s
            b = a + row
            I.extend([a, b, a + 1, a + 1, b, b + 1])
    return P, N, _align_winding(P, N, I)


def torus_mesh(ring_r, tube_r, segs=28, sides=14):
    P, N, I = [], [], []
    for i in range(segs + 1):
        u = 2.0 * math.pi * i / segs
        cu, su = math.cos(u), math.sin(u)
        for j in range(sides + 1):
            v = 2.0 * math.pi * j / sides
            cv, sv = math.cos(v), math.sin(v)
            nx, ny, nz = cu * cv, sv, su * cv
            P.append(((ring_r + tube_r * cv) * cu, tube_r * sv,
                      (ring_r + tube_r * cv) * su))
            N.append(_normalize((nx, ny, nz)))
    row = sides + 1
    for i in range(segs):
        for j in range(sides):
            a = i * row + j
            b = a + row
            I.extend([a, b, a + 1, a + 1, b, b + 1])
    return P, N, _align_winding(P, N, I)


def lathe_mesh(profile, segs=24):
    """Revolve a 2D profile [(radius, y), ...] around +Y -> a solid of
    revolution (columns, balusters, vases, bells, spires). Smooth around the
    sweep; profile-tangent normals."""
    m = len(profile)
    # profile-tangent normals (pointing outward in the r-y plane)
    pn = []
    for k in range(m):
        r0, y0 = profile[max(0, k - 1)]
        r1, y1 = profile[min(m - 1, k + 1)]
        dr, dy = r1 - r0, y1 - y0
        nlen = math.hypot(dr, dy) or 1.0
        # outward normal of profile curve: (dy, -dr) normalized
        pn.append((dy / nlen, -dr / nlen))
    P, N, I = [], [], []
    for i in range(segs + 1):
        ang = 2.0 * math.pi * i / segs
        ca, sa = math.cos(ang), math.sin(ang)
        for k in range(m):
            r, y = profile[k]
            P.append((r * ca, y, r * sa))
            nr, ny = pn[k]
            N.append(_normalize((nr * ca, ny, nr * sa)))
    for i in range(segs):
        for k in range(m - 1):
            a = i * m + k
            b = a + m
            I.extend([a, b, a + 1, a + 1, b, b + 1])
    # end caps if the profile does not close on the axis
    if profile[0][0] > 1e-4:
        c0 = len(P); P.append((0.0, profile[0][1], 0.0)); N.append((0, -1, 0))
        base0 = len(P)
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            P.append((profile[0][0] * math.cos(ang), profile[0][1],
                      profile[0][0] * math.sin(ang)))
            N.append((0, -1, 0))
        for i in range(segs):
            j = (i + 1) % segs
            I.extend([c0, base0 + i, base0 + j])
    if profile[-1][0] > 1e-4:
        c1 = len(P); P.append((0.0, profile[-1][1], 0.0)); N.append((0, 1, 0))
        top0 = len(P)
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            P.append((profile[-1][0] * math.cos(ang), profile[-1][1],
                      profile[-1][0] * math.sin(ang)))
            N.append((0, 1, 0))
        for i in range(segs):
            j = (i + 1) % segs
            I.extend([c1, top0 + j, top0 + i])
    return P, N, _align_winding(P, N, I)


def terrain_mesh(sx, sz, amp=0.07, seed=1, cell=3.0, base_y=0.0, skirt=0.5):
    """Gently undulating, tessellated ground surface + flat underside + skirt
    (so it reads solid from any angle). Amplitude is intentionally tiny so the
    pilgrim walks it flush and props placed at y stay seated."""
    nx = max(6, min(30, int(round(sx / cell))))
    nz = max(6, min(30, int(round(sz / cell))))
    hx, hz = sx / 2.0, sz / 2.0
    freq = 0.16

    def h(gx, gz):
        # zero-ish near the border so edges meet the skirt cleanly
        edge = min(1.0, min(gx + hx, hx - gx, gz + hz, hz - gz) / max(cell, 1.0))
        n = _value_noise(gx * freq, gz * freq, seed)
        n += 0.5 * _value_noise(gx * freq * 2.3 + 11, gz * freq * 2.3 - 7, seed)
        return base_y + amp * n * edge

    P, N, I = [], [], []
    row = nx + 1
    for iz in range(nz + 1):
        gz = -hz + sz * iz / nz
        for ix in range(nx + 1):
            gx = -hx + sx * ix / nx
            P.append((gx, h(gx, gz), gz))
            # normal via finite differences
            e = max(cell * 0.5, 0.5)
            dydx = (h(gx + e, gz) - h(gx - e, gz)) / (2 * e)
            dydz = (h(gx, gz + e) - h(gx, gz - e)) / (2 * e)
            N.append(_normalize((-dydx, 1.0, -dydz)))
    for iz in range(nz):
        for ix in range(nx):
            a = iz * row + ix
            b = a + row
            I.extend([a, b, a + 1, a + 1, b, b + 1])
    # flat underside
    by = base_y - skirt
    base_off = len(P)
    for iz in range(nz + 1):
        gz = -hz + sz * iz / nz
        for ix in range(nx + 1):
            gx = -hx + sx * ix / nx
            P.append((gx, by, gz)); N.append((0, -1, 0))
    for iz in range(nz):
        for ix in range(nx):
            a = base_off + iz * row + ix
            b = a + row
            I.extend([a, a + 1, b, a + 1, b + 1, b])
    # skirt around the 4 borders (top edge ring -> bottom edge ring)
    top_edges, bot_edges = [], []

    def ring(off):
        r = []
        for ix in range(nx + 1):
            r.append(off + ix)                       # front (iz=0)
        for iz in range(nz + 1):
            r.append(off + iz * row + nx)            # right
        for ix in range(nx, -1, -1):
            r.append(off + nz * row + ix)            # back
        for iz in range(nz, -1, -1):
            r.append(off + iz * row)                 # left
        return r

    top_edges = ring(0)
    bot_edges = ring(base_off)
    for k in range(len(top_edges) - 1):
        t0, t1 = top_edges[k], top_edges[k + 1]
        b0, b1 = bot_edges[k], bot_edges[k + 1]
        nrm = _face_normal(P[t0], P[t1], P[b0])
        N_dummy = nrm
        I.extend([t0, b0, t1, t1, b0, b1])
    return P, N, _align_winding(P, N, I)


# ---------------------------------------------------------------------------
# PBR material role inference (name + colour -> metallic / roughness)
# ---------------------------------------------------------------------------
def _kw(name, words):
    return any(w in name for w in words)


def infer_pbr(name, color):
    """Return (metallic, roughness) for a surface from its node name + colour.
    Keeps the storybook palette but gives each material family a distinct
    response: metals shine, water is glossy, stone/wood/foliage read apart."""
    n = name or ""
    r, g, b = (color + (0, 0, 0))[:3]
    # water / liquid -> glossy dielectric
    if _kw(n, ("Water", "DeepChannel", "Pool", "Lake")) or n.endswith("WaterPlane"):
        return 0.10, 0.06
    # explicit metals
    if _kw(n, ("Gold", "Sword", "Shield", "Armor", "Bell", "Key", "Halo",
               "Crown", "Lamp", "Brazier", "Chain", "Spear", "Trumpet",
               "Coin", "Sconce")):
        return 0.95, 0.30
    # bright warm colour reads as gilded metal (celestial gold props)
    if r > 0.82 and g > 0.70 and b < 0.64:
        return 0.85, 0.32
    if _kw(n, ("Glow", "Light", "Ray", "Spotlight", "Glitter", "Particle")):
        return 0.0, 0.45
    if _kw(n, ("Stone", "Rock", "Cliff", "Wall", "Castle", "Tomb", "Boulder",
               "Pillar", "Post", "Platform", "Marble", "Pavement", "Bank",
               "Gate", "Arch", "Column", "Summit", "Mountain")):
        return 0.0, 0.62
    if _kw(n, ("Wood", "Plank", "Fence", "Bench", "Door", "Tent", "Broom",
               "Branch", "Table", "Crate", "Barrel", "Sign", "Beam", "Book",
               "Scroll", "Stall", "Banner", "Bed", "Map", "Cottage", "House",
               "Roof")):
        return 0.0, 0.72
    if _kw(n, ("Grass", "Tree", "Bush", "Brush", "Reeds", "Flower", "Pasture",
               "Field", "Meadow", "Hedge", "Leaf", "Canopy", "Foliage",
               "Pollen", "Vine")):
        return 0.0, 0.85
    if _kw(n, ("Ground", "Mud", "Path", "Road", "Floor", "Slope", "Basin",
               "Dust", "Sand", "Dirt", "Terrain")):
        return 0.0, 0.90
    return 0.0, 0.80


# ---------------------------------------------------------------------------
# GLB document builder
# ---------------------------------------------------------------------------
class GLB:
    def __init__(self):
        self.nodes = []
        self.meshes = []
        self.materials = []
        self.accessors = []
        self.buffer_views = []
        self.images = []
        self.textures = []
        self.samplers = []
        self.bin = bytearray()
        self._mat_cache = {}
        self._tex_cache = {}

    def _align(self):
        while len(self.bin) % 4 != 0:
            self.bin.append(0)

    def _add_view(self, data: bytes, target=None) -> int:
        self._align()
        offset = len(self.bin)
        self.bin.extend(data)
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            bv["target"] = target
        self.buffer_views.append(bv)
        return len(self.buffer_views) - 1

    def _acc_vec3(self, pts) -> int:
        data = bytearray()
        mn = [1e30, 1e30, 1e30]
        mx = [-1e30, -1e30, -1e30]
        for p in pts:
            for k in range(3):
                mn[k] = min(mn[k], p[k])
                mx[k] = max(mx[k], p[k])
            data.extend(struct.pack("<3f", p[0], p[1], p[2]))
        view = self._add_view(bytes(data), _ARRAY_BUFFER)
        self.accessors.append({
            "bufferView": view, "componentType": _FLOAT, "count": len(pts),
            "type": "VEC3", "min": mn, "max": mx,
        })
        return len(self.accessors) - 1

    def _acc_indices(self, idx) -> int:
        data = bytearray()
        for i in idx:
            data.extend(struct.pack("<I", i))
        view = self._add_view(bytes(data), _ELEMENT_ARRAY_BUFFER)
        self.accessors.append({
            "bufferView": view, "componentType": _UINT,
            "count": len(idx), "type": "SCALAR",
        })
        return len(self.accessors) - 1

    def _acc_vec2(self, uvs) -> int:
        data = bytearray()
        for (u, v) in uvs:
            data.extend(struct.pack("<2f", u, v))
        view = self._add_view(bytes(data), _ARRAY_BUFFER)
        self.accessors.append({
            "bufferView": view, "componentType": _FLOAT,
            "count": len(uvs), "type": "VEC2",
        })
        return len(self.accessors) - 1

    # -- textures (embedded PNG) --
    def texture(self, png_path) -> int:
        """Embed a PNG into the GLB and return its texture index (cached)."""
        if png_path in self._tex_cache:
            return self._tex_cache[png_path]
        with open(png_path, "rb") as f:
            data = f.read()
        view = self._add_view(data)  # image data: no buffer target
        img_idx = len(self.images)
        self.images.append({"bufferView": view, "mimeType": "image/png"})
        if not self.samplers:
            self.samplers.append({"wrapS": 10497, "wrapT": 10497,
                                  "magFilter": 9729, "minFilter": 9987})
        tex_idx = len(self.textures)
        self.textures.append({"source": img_idx, "sampler": 0})
        self._tex_cache[png_path] = tex_idx
        return tex_idx

    # -- materials --
    def material(self, rgba, emissive=(0.0, 0.0, 0.0), blend=False,
                 double_sided=False, metallic=0.0, roughness=0.95,
                 base_tex=None, normal_tex=None) -> int:
        key = (tuple(round(c, 4) for c in rgba),
               tuple(round(c, 4) for c in emissive), blend, double_sided,
               round(metallic, 3), round(roughness, 3), base_tex, normal_tex)
        if key in self._mat_cache:
            return self._mat_cache[key]
        pbr = {
            "baseColorFactor": [rgba[0], rgba[1], rgba[2],
                                rgba[3] if len(rgba) > 3 else 1.0],
            "metallicFactor": metallic,
            "roughnessFactor": roughness,
        }
        if base_tex is not None:
            pbr["baseColorTexture"] = {"index": base_tex}
        mat = {
            "pbrMetallicRoughness": pbr,
            "emissiveFactor": [emissive[0], emissive[1], emissive[2]],
        }
        if normal_tex is not None:
            mat["normalTexture"] = {"index": normal_tex}
        if blend:
            mat["alphaMode"] = "BLEND"
        if double_sided:
            mat["doubleSided"] = True
        self.materials.append(mat)
        idx = len(self.materials) - 1
        self._mat_cache[key] = idx
        return idx

    # -- meshes --
    def mesh(self, tris, material_idx) -> int:
        """Flat-shaded triangle soup (per-face normals)."""
        positions, normals, indices = [], [], []
        for (p0, p1, p2) in tris:
            n = _face_normal(p0, p1, p2)
            base = len(positions)
            positions.extend([p0, p1, p2])
            normals.extend([n, n, n])
            indices.extend([base, base + 1, base + 2])
        return self._emit(positions, normals, indices, material_idx)

    def mesh_indexed(self, positions, normals, indices, material_idx) -> int:
        """Smooth indexed mesh (shared verts, supplied normals)."""
        return self._emit(positions, normals, indices, material_idx)

    def mesh_uv(self, positions, normals, uvs, indices, material_idx) -> int:
        """Indexed mesh carrying texture coordinates (TEXCOORD_0)."""
        return self._emit(positions, normals, indices, material_idx, uvs=uvs)

    def _emit(self, positions, normals, indices, material_idx, uvs=None) -> int:
        attrs = {"POSITION": self._acc_vec3(positions),
                 "NORMAL": self._acc_vec3(normals)}
        if uvs is not None:
            attrs["TEXCOORD_0"] = self._acc_vec2(uvs)
        idx_acc = self._acc_indices(indices)
        self.meshes.append({
            "primitives": [{
                "attributes": attrs,
                "indices": idx_acc,
                "material": material_idx,
            }]
        })
        return len(self.meshes) - 1

    # -- nodes --
    def node(self, name, translation=(0, 0, 0), rotation_deg=(0, 0, 0),
             scale=(1, 1, 1), mesh_idx=None, children=None) -> int:
        n = {"name": name}
        if translation != (0, 0, 0):
            n["translation"] = [float(translation[0]), float(translation[1]),
                                float(translation[2])]
        if rotation_deg != (0, 0, 0):
            q = euler_to_quat(*rotation_deg)
            n["rotation"] = [q[0], q[1], q[2], q[3]]
        if scale != (1, 1, 1):
            n["scale"] = [float(scale[0]), float(scale[1]), float(scale[2])]
        if mesh_idx is not None:
            n["mesh"] = mesh_idx
        if children:
            n["children"] = list(children)
        self.nodes.append(n)
        return len(self.nodes) - 1

    # -- serialize --
    def to_glb(self, scene_name="Scene") -> bytes:
        roots = [i for i, n in enumerate(self.nodes)
                 if not any(i in m.get("children", []) for m in self.nodes)]
        gltf = {
            "asset": {"version": "2.0",
                      "generator": "pilgrim-glb-lib (high-fidelity, dependency-free)"},
            "scene": 0,
            "scenes": [{"name": scene_name, "nodes": roots}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "accessors": self.accessors,
            "bufferViews": self.buffer_views,
            "buffers": [{"byteLength": len(self.bin)}],
        }
        if self.images:
            gltf["images"] = self.images
            gltf["textures"] = self.textures
            gltf["samplers"] = self.samplers
        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_bytes) % 4 != 0:
            json_bytes += b" "
        bin_chunk = bytes(self.bin)
        while len(bin_chunk) % 4 != 0:
            bin_chunk += b"\x00"
        total = 12 + 8 + len(json_bytes) + 8 + len(bin_chunk)
        out = bytearray()
        out.extend(struct.pack("<III", 0x46546C67, 2, total))
        out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        out.extend(json_bytes)
        out.extend(struct.pack("<II", len(bin_chunk), 0x004E4942))
        out.extend(bin_chunk)
        return bytes(out)


# ---------------------------------------------------------------------------
# High-level scene builder consumed by scene_defs.py
# ---------------------------------------------------------------------------
class Scene:
    """Convenience layer: named props, composite props, zones and markers.

    All Y values are world-space centres (1 unit = 1 metre). Visible props use
    baked geometry (scale stays 1). Zones (COL_/TRIGGER_) are sized transparent
    boxes the binder reads for collision extents. Markers are empty nodes.

    Visible primitives auto-upgrade: boxes chamfer, round shapes smooth, and
    every surface gets PBR metallic/roughness inferred from its name + colour
    (override per call with metallic=/roughness=).
    """

    BEVEL_MIN_DIM = 0.30   # thinner than this -> stay flat (roads/floors/panels)

    def __init__(self, name):
        self.name = name
        self.glb = GLB()

    # --- material helper ---
    def _mat(self, name, color, emissive=None, metallic=None, roughness=None,
             blend=False, double_sided=False, tex=None):
        m, r = infer_pbr(name, color)
        if metallic is not None:
            m = metallic
        if roughness is not None:
            r = roughness
        base_tex = normal_tex = None
        if tex:
            alb, nrm = tex_paths(tex)
            if alb:
                base_tex = self.glb.texture(alb)
                if nrm:
                    normal_tex = self.glb.texture(nrm)
        return self.glb.material(color, emissive or (0, 0, 0), blend=blend,
                                 double_sided=double_sided, metallic=m,
                                 roughness=r, base_tex=base_tex,
                                 normal_tex=normal_tex)

    # --- visible primitives ---
    def box(self, name, size, color, pos=(0, 0, 0), rot=(0, 0, 0),
            emissive=None, metallic=None, roughness=None, bevel=True,
            tex=None, tile=1.4):
        mat = self._mat(name, color, emissive, metallic, roughness, tex=tex)
        if tex:
            P, N, UV, I = box_uv(*size, tile=tile)
            mesh = self.glb.mesh_uv(P, N, UV, I, mat)
        else:
            if bevel and min(size) >= self.BEVEL_MIN_DIM:
                tris = box_tris_bevel(*size)
            else:
                tris = box_tris(*size)
            mesh = self.glb.mesh(tris, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def ground(self, name, size, color, pos=(0, 0, 0), flat=False):
        # size = (x, z); undulating terrain whose mean top sits at pos.y
        mat = self._mat(name, color)
        if flat:
            mesh = self.glb.mesh(box_tris(size[0], 0.5, size[1]), mat)
            return self.glb.node(name, translation=(pos[0], pos[1] - 0.25, pos[2]),
                                 mesh_idx=mesh)
        seed = (abs(hash(name)) % 9973) + 1
        P, N, I = terrain_mesh(size[0], size[1], amp=0.07, seed=seed,
                               base_y=0.0, skirt=0.6)
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=(pos[0], pos[1], pos[2]),
                             mesh_idx=mesh)

    def cylinder(self, name, radius, height, color, pos=(0, 0, 0),
                 rot=(0, 0, 0), sides=24, emissive=None, metallic=None,
                 roughness=None):
        mat = self._mat(name, color, emissive, metallic, roughness)
        P, N, I = cylinder_mesh(radius, height, max(8, sides))
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def cone(self, name, radius, height, color, pos=(0, 0, 0), rot=(0, 0, 0),
             sides=24, emissive=None, metallic=None, roughness=None):
        mat = self._mat(name, color, emissive, metallic, roughness)
        P, N, I = cone_mesh(radius, height, max(8, sides))
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def sphere(self, name, radius, color, pos=(0, 0, 0), rot=(0, 0, 0),
               segs=24, rings=14, emissive=None, metallic=None, roughness=None):
        mat = self._mat(name, color, emissive, metallic, roughness)
        P, N, I = sphere_mesh(radius, segs, rings)
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def torus(self, name, ring_r, tube_r, color, pos=(0, 0, 0), rot=(0, 0, 0),
              segs=28, sides=14, emissive=None, metallic=None, roughness=None):
        mat = self._mat(name, color, emissive, metallic, roughness)
        P, N, I = torus_mesh(ring_r, tube_r, segs, sides)
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def lathe(self, name, profile, color, pos=(0, 0, 0), rot=(0, 0, 0),
              segs=24, emissive=None, metallic=None, roughness=None):
        mat = self._mat(name, color, emissive, metallic, roughness)
        P, N, I = lathe_mesh(profile, segs)
        mesh = self.glb.mesh_indexed(P, N, I, mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def pyramid(self, name, size, height, color, pos=(0, 0, 0), rot=(0, 0, 0),
                metallic=None, roughness=None, emissive=None, tex=None, tile=1.2):
        mat = self._mat(name, color, emissive, metallic, roughness, tex=tex)
        if tex:
            P, N, UV, I = pyramid_uv(size[0], size[1], height, tile=tile)
            mesh = self.glb.mesh_uv(P, N, UV, I, mat)
        else:
            mesh = self.glb.mesh(_orient_outward(pyramid_tris(size[0], size[1], height)), mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def ramp(self, name, width, run, height, color, pos=(0, 0, 0), rot=(0, 0, 0)):
        """Walkable ramp (see original notes). Kept flat-shaded for crisp tread."""
        mat = self._mat(name, color)
        mesh = self.glb.mesh(_orient_outward(wedge_tris(width, run, height)), mat)
        return self.glb.node(name, translation=pos, rotation_deg=rot, mesh_idx=mesh)

    def _part_mesh(self, parent_name, p):
        kind = p.get("kind", "box")
        col = p["color"]
        emis = p.get("emissive")
        tex = p.get("tex")
        mat = self._mat(parent_name, col, emis, p.get("metallic"),
                        p.get("roughness"), tex=tex)
        if kind == "box":
            size = p["size"]
            if tex:
                P, N, UV, I = box_uv(*size, tile=p.get("tile", 1.4))
                return self.glb.mesh_uv(P, N, UV, I, mat)
            if min(size) >= self.BEVEL_MIN_DIM and p.get("bevel", True):
                return self.glb.mesh(box_tris_bevel(*size), mat)
            return self.glb.mesh(box_tris(*size), mat)
        if kind == "cylinder":
            P, N, I = cylinder_mesh(p["radius"], p["height"], p.get("sides", 24))
            return self.glb.mesh_indexed(P, N, I, mat)
        if kind == "cone":
            _cs = p.get("sides", 24 if p["radius"] >= 0.3 else 10)
            P, N, I = cone_mesh(p["radius"], p["height"], _cs)
            return self.glb.mesh_indexed(P, N, I, mat)
        if kind == "sphere":
            # small decorative spheres get a cheaper tessellation (size budget)
            _r = p["radius"]
            _sg = p.get("segs", 22 if _r >= 0.35 else 10)
            _rg = p.get("rings", 12 if _r >= 0.35 else 6)
            P, N, I = sphere_mesh(_r, _sg, _rg)
            return self.glb.mesh_indexed(P, N, I, mat)
        if kind == "torus":
            P, N, I = torus_mesh(p["ring_r"], p["tube_r"], p.get("segs", 26),
                                 p.get("sides", 12))
            return self.glb.mesh_indexed(P, N, I, mat)
        if kind == "lathe":
            P, N, I = lathe_mesh(p["profile"], p.get("segs", 22))
            return self.glb.mesh_indexed(P, N, I, mat)
        if kind == "pyramid":
            if tex:
                P, N, UV, I = pyramid_uv(p["size"][0], p["size"][1], p["height"],
                                         tile=p.get("tile", 1.2))
                return self.glb.mesh_uv(P, N, UV, I, mat)
            return self.glb.mesh(_orient_outward(
                pyramid_tris(p["size"][0], p["size"][1], p["height"])), mat)
        if kind == "plane":
            return self.glb.mesh(plane_tris(*p["size"]), mat)
        return self.glb.mesh(box_tris(*p.get("size", (1, 1, 1))), mat)

    def composite(self, name, parts, pos=(0, 0, 0), rot=(0, 0, 0)):
        """A named parent empty grouping several child mesh primitives. Each
        part dict: {kind, size/radius/height/profile..., color, pos, rot,
        emissive, metallic, roughness}. Parent carries the gameplay name;
        children are reserved 'VIS_' visuals."""
        child_ids = []
        for p in parts:
            mesh = self._part_mesh(name, p)
            child_ids.append(self.glb.node("VIS_" + name,
                                           translation=p.get("pos", (0, 0, 0)),
                                           rotation_deg=p.get("rot", (0, 0, 0)),
                                           mesh_idx=mesh))
        return self.glb.node(name, translation=pos, rotation_deg=rot,
                             children=child_ids)

    # --- zones (collision / trigger volumes) -- kept as EXACT plain boxes so
    #     ImportedSceneBinder reads the intended AABB extents. ---
    def zone(self, name, size, pos=(0, 0, 0), color=(0.6, 0.3, 0.3, 0.22)):
        m = self.glb.material(color, blend=True, double_sided=True,
                              metallic=0.0, roughness=1.0)
        mesh = self.glb.mesh(box_tris(*size), m)
        return self.glb.node(name, translation=pos, mesh_idx=mesh)

    # --- markers (empty nodes) ---
    def marker(self, name, pos=(0, 0, 0), rot=(0, 0, 0)):
        return self.glb.node(name, translation=pos, rotation_deg=rot)

    # --- output ---
    def save(self, path):
        data = self.glb.to_glb(self.name)
        with open(path, "wb") as f:
            f.write(data)
        return len(data)

    def node_names(self):
        return [n["name"] for n in self.glb.nodes
                if not n["name"].startswith("VIS_")]
