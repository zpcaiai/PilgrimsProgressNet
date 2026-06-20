"""Tiny numpy software rasterizer to preview the Pilgrim's Progress GLBs.

Perspective camera, z-buffer, smooth (interpolated) normals, lambert + a
metallic/roughness-aware spec term + emissive, over a sky gradient. Not the
Godot renderer -- just enough to SEE the geometry/material upgrade.

    python3 glb_preview.py <scene.glb> <out.png> [W H]
"""
import json, struct, math, sys
import numpy as np
from PIL import Image


def load_glb(path):
    raw = open(path, "rb").read()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    gltf = json.loads(raw[20:20 + jlen])
    binoff = 20 + jlen + 8
    binc = raw[binoff:]
    return gltf, binc


def acc(gltf, binc, ai, comp):
    a = gltf["accessors"][ai]; bv = gltf["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0); n = a["count"]
    if comp == 3:
        arr = np.frombuffer(binc, dtype="<f4", count=n * 3, offset=off)
        return arr.reshape(n, 3).astype(np.float64)
    arr = np.frombuffer(binc, dtype="<u4", count=n, offset=off)
    return arr.astype(np.int64)


def quat_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_local(n):
    M = np.eye(4)
    if "rotation" in n:
        M[:3, :3] = quat_mat(n["rotation"])
    if "scale" in n:
        M[:3, :3] = M[:3, :3] @ np.diag(n["scale"])
    if "translation" in n:
        M[:3, 3] = n["translation"]
    return M


def collect(gltf, binc):
    nodes = gltf["nodes"]
    child = set()
    for nd in nodes:
        for c in nd.get("children", []):
            child.add(c)
    roots = [i for i in range(len(nodes)) if i not in child]
    tris_P, tris_N, tris_C, tris_E, tris_MR = [], [], [], [], []

    def walk(i, parent):
        nd = nodes[i]
        M = parent @ node_local(nd)
        if "mesh" in nd:
            prim = gltf["meshes"][nd["mesh"]]["primitives"][0]
            mat = gltf["materials"][prim["material"]]
            pmr = mat.get("pbrMetallicRoughness", {})
            base = pmr.get("baseColorFactor", [0.8, 0.8, 0.8, 1])
            if base[3] < 0.99 or mat.get("alphaMode") == "BLEND":
                pass  # skip transparent zones
            else:
                P = acc(gltf, binc, prim["attributes"]["POSITION"], 3)
                N = acc(gltf, binc, prim["attributes"]["NORMAL"], 3)
                I = acc(gltf, binc, prim["indices"], 1)
                Ph = np.c_[P, np.ones(len(P))] @ M.T
                Pw = Ph[:, :3]
                Nw = N @ M[:3, :3].T
                emis = mat.get("emissiveFactor", [0, 0, 0])
                mr = (pmr.get("metallicFactor", 0.0), pmr.get("roughnessFactor", 0.9))
                for k in range(0, len(I), 3):
                    a, b, c = I[k], I[k + 1], I[k + 2]
                    tris_P.append((Pw[a], Pw[b], Pw[c]))
                    tris_N.append((Nw[a], Nw[b], Nw[c]))
                    tris_C.append(base[:3]); tris_E.append(emis); tris_MR.append(mr)
        for c in nd.get("children", []):
            walk(c, M)

    for r in roots:
        walk(r, np.eye(4))
    return (np.array(tris_P), np.array(tris_N), np.array(tris_C),
            np.array(tris_E), np.array(tris_MR))


def look_at(eye, center, up):
    f = center - eye; f /= np.linalg.norm(f)
    s = np.cross(f, up); s /= np.linalg.norm(s)
    u = np.cross(s, f)
    M = np.eye(4)
    M[0, :3] = s; M[1, :3] = u; M[2, :3] = -f
    M[:3, 3] = [-s @ eye, -u @ eye, f @ eye]
    return M


def render(path, out, W=860, H=560):
    gltf, binc = load_glb(path)
    P, N, C, E, MR = collect(gltf, binc)
    allp = P.reshape(-1, 3)
    mn, mx = allp.min(0), allp.max(0)
    center = (mn + mx) / 2; center[1] = (mn[1] + mx[1]) * 0.42
    rad = np.linalg.norm(mx - mn) * 0.5
    eye = center + np.array([rad * 0.95, rad * 0.95, rad * 1.5])
    V = look_at(eye, center, np.array([0, 1.0, 0]))
    fov = math.radians(38); aspect = W / H
    f = 1.0 / math.tan(fov / 2)
    near, far = 0.1, rad * 8 + 50

    # transform to view then clip/ndc
    Pv = (np.c_[P.reshape(-1, 3), np.ones(len(P) * 3)] @ V.T)[:, :3].reshape(-1, 3, 3)
    # sky gradient background
    img = np.zeros((H, W, 3))
    for y in range(H):
        t = y / H
        img[y, :] = np.array([0.55, 0.68, 0.85]) * (1 - t) + np.array([0.93, 0.9, 0.82]) * t
    zbuf = np.full((H, W), 1e9)

    L = np.array([0.45, 0.8, 0.5]); L = L / np.linalg.norm(L)
    Vdir = np.array([0, 0, 1.0])
    px = f / aspect; py = f

    order = np.argsort(-Pv[:, :, 2].mean(1))  # far first (painter assist for ties)
    for ti in order:
        v = Pv[ti]
        if np.any(v[:, 2] > -near):
            continue
        sx = (px * v[:, 0] / -v[:, 2] * 0.5 + 0.5) * W
        sy = (1 - (py * v[:, 1] / -v[:, 2] * 0.5 + 0.5)) * H
        zc = -v[:, 2]
        minx, maxx = int(max(0, np.floor(sx.min()))), int(min(W - 1, np.ceil(sx.max())))
        miny, maxy = int(max(0, np.floor(sy.min()))), int(min(H - 1, np.ceil(sy.max())))
        if minx > maxx or miny > maxy:
            continue
        x0, y0 = sx[0], sy[0]; x1, y1 = sx[1], sy[1]; x2, y2 = sx[2], sy[2]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        xs = np.arange(minx, maxx + 1); ys = np.arange(miny, maxy + 1)
        gx, gy = np.meshgrid(xs + 0.5, ys + 0.5)
        a = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / den
        b = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / den
        c = 1 - a - b
        inside = (a >= 0) & (b >= 0) & (c >= 0)
        if not inside.any():
            continue
        z = a * zc[0] + b * zc[1] + c * zc[2]
        sub = zbuf[miny:maxy + 1, minx:maxx + 1]
        win = inside & (z < sub)
        if not win.any():
            continue
        nn = (a[..., None] * N[ti][0] + b[..., None] * N[ti][1] + c[..., None] * N[ti][2])
        ln = np.linalg.norm(nn, axis=2, keepdims=True); ln[ln == 0] = 1; nn /= ln
        lam = np.clip((nn * L).sum(2), 0, 1)
        alb = C[ti]; met, rough = MR[ti]
        half = L + Vdir; half /= np.linalg.norm(half)
        spec_ang = np.clip((nn * half).sum(2), 0, 1)
        shin = 8 + (1 - rough) * 120
        spec = ((0.9 if met > 0.5 else 0.25) * (1 - rough)) * spec_ang ** shin
        spec_col = alb if met > 0.5 else np.array([1, 1, 1.0])
        shade = alb * (0.36 + 0.85 * lam)[..., None] + spec[..., None] * spec_col + np.array(E[ti])
        shade = np.clip(shade, 0, 1)
        tgt = img[miny:maxy + 1, minx:maxx + 1]
        tgt[win] = shade[win]
        sub[win] = z[win]
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(out)
    print("wrote", out, "tris=", len(P))


if __name__ == "__main__":
    a = sys.argv
    render(a[1], a[2], int(a[3]) if len(a) > 3 else 860, int(a[4]) if len(a) > 4 else 560)
