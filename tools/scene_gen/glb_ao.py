"""Baked per-vertex ambient occlusion for the Pilgrim's Progress GLB scenes.

WHY THIS EXISTS
---------------
The shipped web build runs Godot's `gl_compatibility` renderer, which has **no
SSAO**. Every chapter's art profile asks for it (`"ssao": true` is the base
default in ChapterArtProfiles.gd) and every chapter silently gets nothing. The
result is the single most recognisable failure of the old look: props sit ON the
ground plane rather than IN the scene, because nothing darkens where surfaces
meet.

Vertex-baked AO fixes that at zero runtime cost and works on every renderer,
including the browser. It is computed once here, at scene-build time, and
written into the GLB as `COLOR_0`. Godot's StandardMaterial3D multiplies albedo
by vertex colour when `vertex_color_use_as_albedo` is on, which the import
pipeline enables (see tools/scene_gen/fix_glb_imports.py).

METHOD
------
A coarse voxel occupancy grid over the whole chapter, then a short hemisphere
ray-march per vertex:

  1. Rasterise every solid triangle's AABB into a uniform grid (default 0.6 m).
     Coarse is fine — we want the *bulk* of walls, cliffs and buildings, not
     watertight geometry.
  2. For each vertex, fire N rays on a cosine-weighted hemisphere around its
     normal and march the grid up to `max_dist`. A ray that hits an occupied
     cell contributes occlusion weighted by 1/(1+distance), so nearby geometry
     matters far more than distant geometry — which is what AO looks like.
  3. Add a separate CONTACT term from height above the ground plane, because
     the grid is too coarse to catch the last few centimetres where a prop
     touches the floor, and that contact shadow is the most valuable pixel in
     the whole effect.

Cost is a few seconds per chapter in pure Python (~30-60k vertices x 12 rays x
~10 steps of dict lookups). That is a build-time cost, paid once.

Everything degrades safely: if anything goes wrong the bake is skipped and the
scene exports exactly as before, just without COLOR_0.
"""

from __future__ import annotations

import math

# Defaults tuned against the 16 chapters (30-90 props each, 60-120 m across).
CELL = 0.6            # voxel size, metres
RAYS = 12             # hemisphere samples per vertex
MAX_DIST = 4.0        # how far AO "sees"; beyond this geometry is ignored
MIN_AO = 0.34         # never darken below this (avoid black crevices)
CONTACT_H = 0.9       # metres above ground where the contact term fades out
CONTACT_STRENGTH = 0.45
SKY_BIAS = 0.25       # upward-facing surfaces keep more light


def _norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / l, v[1] / l, v[2] / l)


def _basis_from_normal(n):
    """Any orthonormal (t, b, n) frame around `n`."""
    if abs(n[1]) < 0.9:
        up = (0.0, 1.0, 0.0)
    else:
        up = (1.0, 0.0, 0.0)
    t = _norm((up[1] * n[2] - up[2] * n[1],
               up[2] * n[0] - up[0] * n[2],
               up[0] * n[1] - up[1] * n[0]))
    b = (n[1] * t[2] - n[2] * t[1],
         n[2] * t[0] - n[0] * t[2],
         n[0] * t[1] - n[1] * t[0])
    return t, b


def _hemisphere_dirs(count):
    """Cosine-ish hemisphere directions in tangent space, deterministic
    (a Fibonacci spiral — no RNG, so builds are reproducible)."""
    dirs = []
    ga = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(count):
        # z in (0, 1]; cosine weighting via sqrt
        z = (i + 0.5) / count
        r = math.sqrt(1.0 - z)
        theta = ga * i
        dirs.append((r * math.cos(theta), r * math.sin(theta), math.sqrt(z)))
    return dirs


class OcclusionGrid:
    """Uniform voxel occupancy over the chapter's solid geometry."""

    def __init__(self, cell=CELL):
        self.cell = cell
        self.cells = set()
        self.min_y = 1e30

    def add_triangle(self, p0, p1, p2):
        c = self.cell
        xs = (p0[0], p1[0], p2[0])
        ys = (p0[1], p1[1], p2[1])
        zs = (p0[2], p1[2], p2[2])
        self.min_y = min(self.min_y, min(ys))
        x0, x1 = int(math.floor(min(xs) / c)), int(math.floor(max(xs) / c))
        y0, y1 = int(math.floor(min(ys) / c)), int(math.floor(max(ys) / c))
        z0, z1 = int(math.floor(min(zs) / c)), int(math.floor(max(zs) / c))
        # Guard against a pathological prop blowing the cell budget.
        if (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) > 20000:
            return
        add = self.cells.add
        for ix in range(x0, x1 + 1):
            for iy in range(y0, y1 + 1):
                for iz in range(z0, z1 + 1):
                    add((ix, iy, iz))

    def occupied(self, x, y, z):
        c = self.cell
        return (int(math.floor(x / c)), int(math.floor(y / c)),
                int(math.floor(z / c))) in self.cells

    def occlusion(self, origin, normal, rays=RAYS, max_dist=MAX_DIST):
        """0 = fully open, 1 = fully enclosed."""
        n = _norm(normal)
        t, b = _basis_from_normal(n)
        # Start just off the surface so we never hit our own cell.
        ox = origin[0] + n[0] * self.cell * 0.9
        oy = origin[1] + n[1] * self.cell * 0.9
        oz = origin[2] + n[2] * self.cell * 0.9
        step = self.cell * 0.85
        steps = max(2, int(max_dist / step))
        hit_weight = 0.0
        total_weight = 0.0
        for (dx, dy, dz) in self._dirs(rays):
            wx = t[0] * dx + b[0] * dy + n[0] * dz
            wy = t[1] * dx + b[1] * dy + n[1] * dz
            wz = t[2] * dx + b[2] * dy + n[2] * dz
            # Rays pointing up see the sky: weight them as less occludable so
            # the tops of things stay bright.
            w = 1.0 - SKY_BIAS * max(0.0, wy)
            total_weight += w
            d = step
            for _ in range(steps):
                if self.occupied(ox + wx * d, oy + wy * d, oz + wz * d):
                    hit_weight += w / (1.0 + d * 0.6)
                    break
                d += step
        if total_weight <= 0.0:
            return 0.0
        return min(1.0, hit_weight / total_weight)

    _dir_cache = {}

    def _dirs(self, rays):
        if rays not in OcclusionGrid._dir_cache:
            OcclusionGrid._dir_cache[rays] = _hemisphere_dirs(rays)
        return OcclusionGrid._dir_cache[rays]


def bake(grid, positions_world, normals_world, ground_y=None,
         rays=RAYS, max_dist=MAX_DIST, min_ao=MIN_AO):
    """Per-vertex AO factors (1.0 = unoccluded) for one mesh."""
    out = []
    gy = grid.min_y if ground_y is None else ground_y
    for i, p in enumerate(positions_world):
        n = normals_world[i] if i < len(normals_world) else (0.0, 1.0, 0.0)
        occ = grid.occlusion(p, n, rays=rays, max_dist=max_dist)
        ao = 1.0 - occ
        # Contact term: the last few centimetres above the floor, where the
        # voxel grid is too coarse but the eye is most sensitive.
        h = p[1] - gy
        if h < CONTACT_H:
            fade = 1.0 - max(0.0, min(1.0, h / CONTACT_H))
            # Only darken surfaces that actually face away from straight up —
            # a floor's own top face should not darken itself.
            facing = 1.0 - max(0.0, min(1.0, n[1]))
            ao -= CONTACT_STRENGTH * fade * (0.35 + 0.65 * facing)
        out.append(max(min_ao, min(1.0, ao)))
    return out
