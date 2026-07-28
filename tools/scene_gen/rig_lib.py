"""Skinned humanoid rig generator — pure Python, no Blender, no engine.

WHY
---
Until now every character in the game was `HumanoidFigure.gd`: ~20 separate
rigid mesh primitives parented into a node hierarchy. That representation has a
hard ceiling. A rigid cylinder cannot deform, so:

  * the shoulder and hip are always a visible seam or an interpenetration,
  * clothing cannot follow the body,
  * there is no place to put a facial expression,
  * and every joint needs its own mesh, so a "crowd" is a draw-call problem.

This module produces the alternative: ONE continuous mesh bound to a 26-bone
skeleton, with baked idle / walk / run / talk clips, exported as a standard
glTF 2.0 skinned model that Godot imports as Skeleton3D + MeshInstance3D +
AnimationPlayer. Nothing here needs Blender; it writes the buffers directly
through glb_lib's skinning support.

DESIGN
------
* SKELETON — rest pose is pure translation (no rest rotations), which keeps the
  inverse bind matrices trivial (a translation by -restPosition) and keeps
  authored animation quaternions readable: "rotate the left thigh -20 deg about
  X" means exactly that.

* GEOMETRY — limbs are swept tubes with per-ring radii, so there are rings of
  vertices AT and AROUND every joint. That is what makes the skin bend smoothly
  instead of creasing.

* SKINNING — each generated vertex ring declares which bones may influence it
  (its `group`). Weights come from inverse distance to the candidate bone
  SEGMENTS, normalised over the best 4. Restricting candidates per part is what
  stops an elbow from grabbing rib vertices, which is the usual failure mode of
  naive distance skinning.

* ANIMATION — clips are sampled from the same closed-form gait maths the
  in-engine animator uses (stride-locked cadence, opposite-phase hips, folding
  knees and elbows, counter-swinging arms, chest twist), so the skinned pilgrim
  and the primitive fallback move alike.

The output is a normal .glb. A human artist can replace it wholesale with a
hand-modelled character as long as the bone NAMES match; SkinnedFigure.gd looks
bones up by name.
"""

from __future__ import annotations

import math

# ---------------------------------------------------------------------------
# Skeleton
# ---------------------------------------------------------------------------
# (name, parent_name_or_None, rest world position) for a 2.0 m tall figure.
# Everything scales linearly from here.
BONES = [
    ("Hips",        None,        (0.000, 0.980, 0.000)),
    ("Spine",       "Hips",      (0.000, 1.200, 0.000)),
    ("Chest",       "Spine",     (0.000, 1.420, 0.000)),
    ("Neck",        "Chest",     (0.000, 1.615, 0.000)),
    ("Head",        "Neck",      (0.000, 1.730, 0.000)),
    ("HeadTop",     "Head",      (0.000, 1.990, 0.000)),
    ("EyeL",        "Head",      (-0.062, 1.845, 0.128)),
    ("EyeR",        "Head",      (0.062, 1.845, 0.128)),
    ("Jaw",         "Head",      (0.000, 1.775, 0.075)),

    ("ShoulderL",   "Chest",     (-0.095, 1.560, 0.000)),
    ("UpperArmL",   "ShoulderL", (-0.250, 1.555, 0.000)),
    ("ForearmL",    "UpperArmL", (-0.250, 1.195, 0.000)),
    ("HandL",       "ForearmL",  (-0.250, 0.860, 0.000)),
    ("HandTipL",    "HandL",     (-0.250, 0.735, 0.000)),

    ("ShoulderR",   "Chest",     (0.095, 1.560, 0.000)),
    ("UpperArmR",   "ShoulderR", (0.250, 1.555, 0.000)),
    ("ForearmR",    "UpperArmR", (0.250, 1.195, 0.000)),
    ("HandR",       "ForearmR",  (0.250, 0.860, 0.000)),
    ("HandTipR",    "HandR",     (0.250, 0.735, 0.000)),

    ("ThighL",      "Hips",      (-0.110, 0.960, 0.000)),
    ("ShinL",       "ThighL",    (-0.110, 0.520, 0.000)),
    ("FootL",       "ShinL",     (-0.110, 0.100, 0.000)),
    ("ToeL",        "FootL",     (-0.110, 0.045, 0.190)),

    ("ThighR",      "Hips",      (0.110, 0.960, 0.000)),
    ("ShinR",       "ThighR",    (0.110, 0.520, 0.000)),
    ("FootR",       "ShinR",     (0.110, 0.100, 0.000)),
    ("ToeR",        "FootR",     (0.110, 0.045, 0.190)),
]

BONE_INDEX = {b[0]: i for i, b in enumerate(BONES)}


def bone_pos(name):
    return BONES[BONE_INDEX[name]][2]


def local_translations():
    """Per-bone local translation (rest position minus the parent's)."""
    out = []
    for name, parent, pos in BONES:
        if parent is None:
            out.append(pos)
        else:
            pp = bone_pos(parent)
            out.append((pos[0] - pp[0], pos[1] - pp[1], pos[2] - pp[2]))
    return out


# Bone chains a vertex group may be influenced by. Restricting candidates per
# body part is what keeps the elbow from grabbing rib vertices.
GROUPS = {
    "torso":  ["Hips", "Spine", "Chest", "Neck"],
    "neck":   ["Chest", "Neck", "Head"],
    "head":   ["Neck", "Head", "HeadTop"],
    "jaw":    ["Head", "Jaw"],
    "eyeL":   ["EyeL"],
    "eyeR":   ["EyeR"],
    "armL":   ["Chest", "ShoulderL", "UpperArmL", "ForearmL", "HandL", "HandTipL"],
    "armR":   ["Chest", "ShoulderR", "UpperArmR", "ForearmR", "HandR", "HandTipR"],
    "legL":   ["Hips", "ThighL", "ShinL", "FootL", "ToeL"],
    "legR":   ["Hips", "ThighR", "ShinR", "FootR", "ToeR"],
    "skirt":  ["Hips", "ThighL", "ThighR", "Spine"],
}


# ---------------------------------------------------------------------------
# Small maths
# ---------------------------------------------------------------------------
def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _len(a):
    return math.sqrt(_dot(a, a))


def _norm(a):
    l = _len(a) or 1.0
    return (a[0] / l, a[1] / l, a[2] / l)


def _point_segment_distance(p, a, b):
    ab = _sub(b, a)
    d2 = _dot(ab, ab)
    if d2 < 1e-9:
        return _len(_sub(p, a))
    t = max(0.0, min(1.0, _dot(_sub(p, a), ab) / d2))
    return _len(_sub(p, _add(a, _mul(ab, t))))


def quat_axis(axis, rad):
    """Quaternion (x, y, z, w) for a rotation of `rad` about a unit axis."""
    h = rad * 0.5
    s = math.sin(h)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(h))


def quat_euler(rx, ry, rz):
    """Quaternion for intrinsic X-then-Y-then-Z radians (matches Godot order)."""
    qx = quat_axis((1.0, 0.0, 0.0), rx)
    qy = quat_axis((0.0, 1.0, 0.0), ry)
    qz = quat_axis((0.0, 0.0, 1.0), rz)
    return quat_mul(quat_mul(qz, qy), qx)


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


IDENTITY_Q = (0.0, 0.0, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Geometry: swept tubes, spheres and boxes that carry a skinning group
# ---------------------------------------------------------------------------
class SkinMesh:
    """Accumulates positions / normals / groups / indices for one character."""

    def __init__(self, scale=1.0):
        self.scale = scale
        self.P = []
        self.N = []
        self.G = []          # skinning group name, per vertex
        self.C = []          # per-vertex albedo tint slot (a palette key)
        self.I = []

    # -- primitives ---------------------------------------------------------
    def tube(self, path, radii, group, slot, sides=10, cap_start=True,
             cap_end=True, squash=1.0):
        """Sweep a ring along `path` (list of points) with `radii` per point.

        `squash` flattens the tube on Z (used for the torso, which is an ellipse
        in section, not a circle)."""
        assert len(path) == len(radii)
        rings = []
        for i, c in enumerate(path):
            # frame: forward along the path, any two perpendicular axes
            if i == 0:
                fwd = _norm(_sub(path[1], path[0]))
            elif i == len(path) - 1:
                fwd = _norm(_sub(path[-1], path[-2]))
            else:
                fwd = _norm(_sub(path[i + 1], path[i - 1]))
            up = (0.0, 0.0, 1.0) if abs(fwd[2]) < 0.9 else (1.0, 0.0, 0.0)
            right = _norm(_cross(up, fwd))
            up2 = _cross(fwd, right)
            ring = []
            for s in range(sides):
                a = 2.0 * math.pi * s / sides
                ca, sa = math.cos(a), math.sin(a)
                off = _add(_mul(right, ca * radii[i]),
                           _mul(up2, sa * radii[i] * squash))
                p = _add(c, off)
                n = _norm(off) if _len(off) > 1e-6 else fwd
                ring.append(self._vert(p, n, group, slot))
            rings.append(ring)
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            for s in range(sides):
                t = (s + 1) % sides
                self.I.extend([a[s], b[s], a[t], a[t], b[s], b[t]])
        if cap_start:
            self._cap(path[0], rings[0], group, slot,
                      _norm(_sub(path[0], path[1])))
        if cap_end:
            self._cap(path[-1], rings[-1], group, slot,
                      _norm(_sub(path[-1], path[-2])), flip=True)
        return rings

    def _cap(self, centre, ring, group, slot, normal, flip=False):
        c = self._vert(centre, normal, group, slot)
        n = len(ring)
        for s in range(n):
            t = (s + 1) % n
            if flip:
                self.I.extend([c, ring[s], ring[t]])
            else:
                self.I.extend([c, ring[t], ring[s]])

    def sphere(self, centre, radius, group, slot, segs=12, rings=8,
               scale=(1.0, 1.0, 1.0)):
        base = len(self.P)
        for r in range(rings + 1):
            v = math.pi * r / rings
            y, rad = math.cos(v), math.sin(v)
            for s in range(segs + 1):
                u = 2.0 * math.pi * s / segs
                nx, ny, nz = rad * math.cos(u), y, rad * math.sin(u)
                p = (centre[0] + nx * radius * scale[0],
                     centre[1] + ny * radius * scale[1],
                     centre[2] + nz * radius * scale[2])
                self._vert(p, _norm((nx / max(scale[0], 1e-3),
                                     ny / max(scale[1], 1e-3),
                                     nz / max(scale[2], 1e-3))), group, slot)
        row = segs + 1
        for r in range(rings):
            for s in range(segs):
                a = base + r * row + s
                b = a + row
                self.I.extend([a, b, a + 1, a + 1, b, b + 1])

    def box(self, centre, size, group, slot):
        hx, hy, hz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        faces = [
            ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
            ((0, 0, -1), [(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)]),
            ((1, 0, 0), [(hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)]),
            ((-1, 0, 0), [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)]),
            ((0, 1, 0), [(-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)]),
            ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
        ]
        for n, quad in faces:
            ids = [self._vert(_add(centre, q), n, group, slot) for q in quad]
            self.I.extend([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]])

    def _vert(self, p, n, group, slot):
        self.P.append((p[0], p[1], p[2]))
        self.N.append((n[0], n[1], n[2]))
        self.G.append(group)
        self.C.append(slot)
        return len(self.P) - 1

    # -- skinning -----------------------------------------------------------
    def skin(self, falloff=3.0, max_influences=4):
        """Inverse-distance weights against each vertex's candidate bones."""
        segs = {}
        for name, parent, pos in BONES:
            if parent is None:
                segs[name] = (pos, pos)
            else:
                segs[name] = (bone_pos(parent), pos)
        # A bone's "own" segment for skinning is from itself to its first child
        # (falling back to its parent link) — that is the piece of skin it moves.
        children = {}
        for name, parent, pos in BONES:
            if parent:
                children.setdefault(parent, []).append(name)
        own = {}
        for name, parent, pos in BONES:
            kids = children.get(name)
            if kids:
                own[name] = (pos, bone_pos(kids[0]))
            elif parent:
                own[name] = (bone_pos(parent), pos)
            else:
                own[name] = (pos, pos)

        joints, weights = [], []
        for i, p in enumerate(self.P):
            cands = GROUPS.get(self.G[i], ["Hips"])
            scored = []
            for bn in cands:
                a, b = own[bn]
                d = _point_segment_distance(p, a, b)
                scored.append((1.0 / ((d + 0.02) ** falloff), BONE_INDEX[bn]))
            scored.sort(reverse=True)
            scored = scored[:max_influences]
            total = sum(w for w, _ in scored) or 1.0
            js = [0, 0, 0, 0]
            ws = [0.0, 0.0, 0.0, 0.0]
            for k, (w, bi) in enumerate(scored):
                js[k] = bi
                ws[k] = w / total
            joints.append(tuple(js))
            weights.append(tuple(ws))
        return joints, weights


# ---------------------------------------------------------------------------
# The pilgrim body
# ---------------------------------------------------------------------------
# Palette slots — SkinnedFigure.gd re-tints these per character at runtime, so
# one mesh serves the whole cast.
SLOT_SKIN = 0
SLOT_ROBE = 1
SLOT_ROBE2 = 2
SLOT_HAIR = 3
SLOT_ACCENT = 4
SLOT_EYE = 5
SLOT_BOOT = 6
SLOT_COUNT = 7


def build_body(sides=10):
    """One continuous character mesh, in rest pose, ready to skin."""
    m = SkinMesh()

    # --- torso: hips -> spine -> chest -> neck base, elliptical section ------
    m.tube(
        [(0.0, 0.94, 0.0), (0.0, 1.10, 0.0), (0.0, 1.26, 0.0),
         (0.0, 1.42, 0.0), (0.0, 1.56, 0.0), (0.0, 1.62, 0.0)],
        [0.205, 0.198, 0.196, 0.212, 0.222, 0.150],
        "torso", SLOT_ROBE, sides=sides + 2, squash=0.72)

    # --- neck ----------------------------------------------------------------
    m.tube([(0.0, 1.60, 0.0), (0.0, 1.73, 0.0)],
           [0.072, 0.078], "neck", SLOT_SKIN, sides=8, cap_start=False)

    # --- head ----------------------------------------------------------------
    m.sphere((0.0, 1.845, 0.005), 0.155, "head", SLOT_SKIN,
             segs=14, rings=10, scale=(0.95, 1.08, 1.0))
    # jaw / chin block gives the profile a chin instead of a ball
    m.box((0.0, 1.762, 0.030), (0.185, 0.095, 0.180), "jaw", SLOT_SKIN)
    # hair cap
    m.sphere((0.0, 1.882, -0.030), 0.163, "head", SLOT_HAIR,
             segs=12, rings=8, scale=(1.0, 0.80, 1.02))
    # eyes (own bones, so a blink can scale them)
    m.sphere(bone_pos("EyeL"), 0.030, "eyeL", SLOT_EYE, segs=8, rings=6,
             scale=(1.0, 0.85, 0.6))
    m.sphere(bone_pos("EyeR"), 0.030, "eyeR", SLOT_EYE, segs=8, rings=6,
             scale=(1.0, 0.85, 0.6))
    # brow ridge + nose: cheap, and they carry most of the facial read
    m.box((-0.062, 1.895, 0.120), (0.085, 0.020, 0.030), "head", SLOT_HAIR)
    m.box((0.062, 1.895, 0.120), (0.085, 0.020, 0.030), "head", SLOT_HAIR)
    m.box((0.0, 1.820, 0.140), (0.030, 0.055, 0.040), "head", SLOT_SKIN)
    m.box((0.0, 1.755, 0.118), (0.070, 0.014, 0.020), "jaw", SLOT_ACCENT)

    # --- arms ----------------------------------------------------------------
    for side, g in ((-1.0, "armL"), (1.0, "armR")):
        sfx = "L" if side < 0 else "R"
        m.tube(
            [bone_pos("Shoulder" + sfx),
             bone_pos("UpperArm" + sfx),
             (side * 0.25, 1.375, 0.0),
             bone_pos("Forearm" + sfx),
             (side * 0.25, 1.030, 0.0),
             bone_pos("Hand" + sfx)],
            [0.098, 0.082, 0.074, 0.068, 0.060, 0.055],
            g, SLOT_ROBE, sides=sides, cap_start=True, cap_end=False)
        m.sphere(bone_pos("Hand" + sfx), 0.070, g, SLOT_SKIN,
                 segs=8, rings=6, scale=(0.85, 1.05, 0.65))
        # thumb
        m.box((side * 0.30, 0.845, 0.010), (0.036, 0.075, 0.036), g, SLOT_SKIN)

    # --- legs ----------------------------------------------------------------
    for side, g in ((-1.0, "legL"), (1.0, "legR")):
        sfx = "L" if side < 0 else "R"
        m.tube(
            [(side * 0.11, 1.00, 0.0),
             bone_pos("Thigh" + sfx),
             (side * 0.11, 0.740, 0.0),
             bone_pos("Shin" + sfx),
             (side * 0.11, 0.310, 0.0),
             bone_pos("Foot" + sfx)],
            [0.128, 0.122, 0.112, 0.098, 0.082, 0.070],
            g, SLOT_ROBE2, sides=sides, cap_start=False, cap_end=False)
        # foot + toe
        m.box((side * 0.11, 0.052, 0.055), (0.135, 0.095, 0.255), g, SLOT_BOOT)
        m.box((side * 0.11, 0.042, 0.190), (0.115, 0.075, 0.090), g, SLOT_BOOT)

    # --- tunic / skirt: skinned to hips + both thighs so it swings -----------
    m.tube(
        [(0.0, 1.16, 0.0), (0.0, 1.02, 0.0), (0.0, 0.88, 0.0), (0.0, 0.74, 0.0)],
        [0.225, 0.252, 0.285, 0.310],
        "skirt", SLOT_ROBE, sides=sides + 4, cap_start=False, cap_end=False)
    # belt
    m.tube([(0.0, 1.055, 0.0), (0.0, 1.005, 0.0)], [0.240, 0.240],
           "torso", SLOT_ACCENT, sides=sides + 4, cap_start=False, cap_end=False)
    return m


# ---------------------------------------------------------------------------
# Animation clips
# ---------------------------------------------------------------------------
# The gait maths mirrors scripts/render/HumanoidAnimator.gd so the skinned
# pilgrim and the primitive fallback read as the same character.

def _sample_walk(phase, amp, lean, arm_amp=None):
    """Bone rotations (radians about X unless noted) for one gait phase."""
    sw = math.sin(phase)
    arm = arm_amp if arm_amp is not None else amp * 1.08
    out = {}
    out["Hips"] = (0.0, -sw * 0.06 * amp, 0.0)
    out["Spine"] = (lean * 0.35, sw * 0.05 * amp, 0.0)
    out["Chest"] = (lean * 0.25, sw * 0.10 * amp, 0.0)
    out["Neck"] = (-lean * 0.30, 0.0, 0.0)
    out["Head"] = (-lean * 0.30, sw * 0.03 * amp, 0.0)

    out["ThighL"] = (sw * 0.52 * amp, 0.0, 0.0)
    out["ThighR"] = (-sw * 0.52 * amp, 0.0, 0.0)
    out["ShinL"] = (-0.06 - max(0.0, sw) * 0.92 * amp, 0.0, 0.0)
    out["ShinR"] = (-0.06 - max(0.0, -sw) * 0.92 * amp, 0.0, 0.0)
    out["FootL"] = (-sw * 0.40 * amp + max(0.0, sw) * 0.28 * amp, 0.0, 0.0)
    out["FootR"] = (sw * 0.40 * amp + max(0.0, -sw) * 0.28 * amp, 0.0, 0.0)

    out["UpperArmL"] = (-sw * 0.56 * arm, 0.0, 0.06)
    out["UpperArmR"] = (sw * 0.56 * arm, 0.0, -0.06)
    out["ForearmL"] = (-0.14 - max(0.0, -sw) * 0.62 * arm, 0.0, 0.0)
    out["ForearmR"] = (-0.14 - max(0.0, sw) * 0.62 * arm, 0.0, 0.0)
    out["ShoulderL"] = (0.0, 0.0, -sw * 0.05 * arm)
    out["ShoulderR"] = (0.0, 0.0, -sw * 0.05 * arm)
    return out


def _sample_idle(t):
    """Breathing + weight shift + a slow head drift."""
    breathe = math.sin(t * 1.9)
    sway = math.sin(t * 0.62)
    out = {
        "Hips": (0.0, sway * 0.030, sway * 0.020),
        "Spine": (breathe * 0.012, 0.0, -sway * 0.014),
        "Chest": (breathe * 0.020, sway * 0.020, 0.0),
        "Neck": (-breathe * 0.014, 0.0, 0.0),
        "Head": (math.sin(t * 0.41) * 0.045, math.sin(t * 0.33) * 0.130, sway * 0.020),
        "UpperArmL": (0.05 + breathe * 0.012, 0.0, 0.075),
        "UpperArmR": (0.05 + breathe * 0.012, 0.0, -0.075),
        "ForearmL": (-0.18, 0.0, 0.0),
        "ForearmR": (-0.18, 0.0, 0.0),
        "ThighL": (0.0, 0.0, -sway * 0.012),
        "ThighR": (0.0, 0.0, -sway * 0.012),
        "ShinL": (-0.05, 0.0, 0.0),
        "ShinR": (-0.05, 0.0, 0.0),
    }
    return out


def _sample_talk(t):
    """Standing conversation: gesturing hands, an emphatic head, jaw motion."""
    a = math.sin(t * 2.4)
    b = math.sin(t * 1.7 + 1.1)
    out = _sample_idle(t * 0.7)
    out["UpperArmL"] = (-0.45 - a * 0.22, 0.10, 0.30)
    out["UpperArmR"] = (-0.38 + b * 0.20, -0.10, -0.26)
    out["ForearmL"] = (-1.05 - a * 0.28, 0.0, 0.0)
    out["ForearmR"] = (-0.95 - b * 0.24, 0.0, 0.0)
    out["Head"] = (a * 0.07, b * 0.10, a * 0.03)
    out["Jaw"] = (max(0.0, math.sin(t * 9.0)) * 0.16, 0.0, 0.0)
    return out


def _sample_swim(t):
    """Front crawl: body pitched into the water, alternating overhead reach,
    flutter kick, head lifting for air on every other stroke."""
    sw = math.sin(t)
    out = {
        "Hips": (0.55, 0.0, sw * 0.10),
        "Spine": (0.16, sw * 0.12, 0.0),
        "Chest": (0.10, -sw * 0.16, 0.0),
        "Neck": (-0.45, 0.0, 0.0),
        "Head": (-0.35 + max(0.0, sw) * 0.30, sw * 0.32, 0.0),
        "UpperArmL": (-0.90 + sw * 1.55, 0.10, 0.10),
        "UpperArmR": (-0.90 - sw * 1.55, -0.10, -0.10),
        "ForearmL": (-0.35 - max(0.0, sw) * 0.55, 0.0, 0.0),
        "ForearmR": (-0.35 - max(0.0, -sw) * 0.55, 0.0, 0.0),
        "ThighL": (sw * 0.30, 0.0, 0.0),
        "ThighR": (-sw * 0.30, 0.0, 0.0),
        "ShinL": (-0.18 - max(0.0, sw) * 0.20, 0.0, 0.0),
        "ShinR": (-0.18 - max(0.0, -sw) * 0.20, 0.0, 0.0),
        "FootL": (0.30, 0.0, 0.0),
        "FootR": (0.30, 0.0, 0.0),
    }
    return out


def _sample_struggle(t):
    """Labouring in the Slough: wide uncontrolled sweeps, uneven knee drive,
    torso roll. Deliberately less composed than the swim."""
    sw = math.sin(t)
    churn = math.cos(t * 0.82)
    out = {
        "Hips": (0.22, churn * 0.10, sw * 0.14),
        "Spine": (0.20, -sw * 0.14, churn * 0.08),
        "Chest": (0.14, sw * 0.20, 0.0),
        "Neck": (-0.22, 0.0, 0.0),
        "Head": (-0.18, churn * 0.18, 0.0),
        "UpperArmL": (-0.72 + sw * 1.15, 0.30 + churn * 0.40, 0.30),
        "UpperArmR": (-0.72 - sw * 1.15, -0.30 + churn * 0.40, -0.30),
        "ForearmL": (-0.50 - max(0.0, churn) * 0.55, 0.0, 0.0),
        "ForearmR": (-0.50 - max(0.0, -churn) * 0.55, 0.0, 0.0),
        "ThighL": (0.20 + sw * 0.42, 0.0, 0.0),
        "ThighR": (0.20 - sw * 0.42, 0.0, 0.0),
        "ShinL": (-0.30 - max(0.0, -sw) * 0.55, 0.0, 0.0),
        "ShinR": (-0.30 - max(0.0, sw) * 0.55, 0.0, 0.0),
    }
    return out


CLIPS = {
    # name: (sampler, cycle_seconds, sample_count, kwargs)
    "Idle":      ("idle", 4.8, 24, {}),
    "Walk":      ("walk", 1.0, 20, {"amp": 0.85, "lean": 0.08}),
    "Run":       ("walk", 0.62, 20, {"amp": 1.18, "lean": 0.20, "arm_amp": 1.35}),
    "Talk":      ("talk", 3.6, 30, {}),
    "Swim":      ("swim", 1.6, 18, {}),
    "Struggle":  ("struggle", 1.3, 18, {}),
}


def clip_tracks(kind, duration, samples, node_of_bone, **kw):
    """[{node, path, times, values}] for one looping clip."""
    per_bone = {}
    for i in range(samples + 1):
        f = i / float(samples)
        t = f * duration
        if kind == "walk":
            rot = _sample_walk(f * 2.0 * math.pi, kw.get("amp", 1.0),
                               kw.get("lean", 0.08), kw.get("arm_amp"))
        elif kind == "run":
            rot = _sample_walk(f * 2.0 * math.pi, kw.get("amp", 1.2),
                               kw.get("lean", 0.2), kw.get("arm_amp"))
        elif kind == "talk":
            rot = _sample_talk(f * 2.0 * math.pi)
        elif kind == "swim":
            rot = _sample_swim(f * 2.0 * math.pi)
        elif kind == "struggle":
            rot = _sample_struggle(f * 2.0 * math.pi)
        else:
            rot = _sample_idle(f * 2.0 * math.pi)
        for bone, (rx, ry, rz) in rot.items():
            per_bone.setdefault(bone, {"times": [], "values": []})
            per_bone[bone]["times"].append(t)
            per_bone[bone]["values"].append(quat_euler(rx, ry, rz))
    tracks = []
    for bone, data in per_bone.items():
        if bone not in node_of_bone:
            continue
        tracks.append({"node": node_of_bone[bone], "path": "rotation",
                       "times": data["times"], "values": data["values"]})
    return tracks
