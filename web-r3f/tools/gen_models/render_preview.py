#!/usr/bin/env python3
"""
Headless preview of the generated GLB models (no GPU needed): loads each GLB, flat-
shades its triangles with a painter's-algorithm rasteriser in matplotlib, and writes
a montage PNG. Purely for sanity-checking shape/orientation/colour.

Run:  python3 tools/gen_models/render_preview.py <out.png>
"""
import sys
import os
import numpy as np
import trimesh
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

MODELS = ["doubting_castle", "celestial_gate", "wicket_gate", "pilgrim"]
HERE = os.path.dirname(__file__)
MDIR = os.path.join(HERE, "..", "..", "public", "models")


def rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def colorof(g):
    try:
        bc = np.array(g.visual.material.baseColorFactor, dtype=float)[:3]
        if bc.max() > 1.001:        # trimesh returns 0..255 — normalise
            bc = bc / 255.0
        return bc
    except Exception:
        return np.array([0.6, 0.6, 0.6])


def gather(path):
    """Return list of (tris[N,3,3], rgb), expanding EVERY instance node with its world transform."""
    scene = trimesh.load(path)
    out = []
    if not hasattr(scene, "graph"):
        out.append((scene.vertices[scene.faces], colorof(scene)))
        return out
    for node_name in scene.graph.nodes_geometry:
        T, geom_name = scene.graph[node_name]
        g = scene.geometry[geom_name]
        v = trimesh.transformations.transform_points(g.vertices, T)
        out.append((v[g.faces], colorof(g)))
    return out


def render(ax, path, title):
    parts = gather(path)
    R = rot_y(np.radians(28)) @ rot_x(np.radians(-18))   # front-right, slightly above
    light = np.array([0.4, 0.8, 0.5]); light = light / np.linalg.norm(light)
    polys, facecolors, depths = [], [], []
    for tris, rgb in parts:
        for tri in tris:
            p = tri @ R.T
            n = np.cross(p[1] - p[0], p[2] - p[0])
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            shade = 0.35 + 0.65 * max(0.0, float(n @ light))
            polys.append(p[:, :2])
            facecolors.append(np.clip(rgb * shade, 0, 1))
            depths.append(p[:, 2].mean())
    order = np.argsort(depths)  # painter's: far first
    pc = PolyCollection([polys[i] for i in order],
                        facecolors=[facecolors[i] for i in order],
                        edgecolors=(0, 0, 0, 0.12), linewidths=0.2)
    ax.add_collection(pc)
    allp = np.vstack(polys)
    ax.set_xlim(allp[:, 0].min() - 1, allp[:, 0].max() + 1)
    ax.set_ylim(allp[:, 1].min() - 1, allp[:, 1].max() + 1)
    ax.set_aspect("equal"); ax.axis("off")
    ax.set_title(title, fontsize=11)


def main(out):
    fig, axes = plt.subplots(2, 2, figsize=(11, 11), facecolor="#15171c")
    for ax, name in zip(axes.ravel(), MODELS):
        ax.set_facecolor("#15171c")
        render(ax, os.path.join(MDIR, f"{name}.glb"), name)
    fig.tight_layout()
    fig.savefig(out, dpi=110, facecolor="#15171c")
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "preview.png")
