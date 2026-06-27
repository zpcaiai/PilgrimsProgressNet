"""Scene definitions for all ten Pilgrim's Progress chapters (Batch 1 + Batch 2).

Each builder places EVERY named object from its chapter's "Technical Objects"
list so ImportedSceneBinder.gd finds a node for every prefix it expects. World
convention: 1 unit = 1 metre, forward / goal direction is -Z, the pilgrim spawns
toward +Z. Geometry is intentional greybox -- the in-engine painterly/PBR pass
(ChapterArtProfiles + PainterlyPostFX) supplies the final look. Prefix legend
lives in docs/SCENE_NAMING_CONVENTIONS.md.

This module is pure data: it imports only glb_lib (stdlib) so it can be consumed
by build_scenes.py (no Blender) and by the Blender scripts alike.
"""

from __future__ import annotations

from glb_lib import Scene


# ---------------------------------------------------------------------------
# Shared dressing helpers
# ---------------------------------------------------------------------------
def _road(s, name, length, z_center, width=6.0, color=(0.30, 0.26, 0.22),
          tex=None, tile=1.4):
    s.box(name, (width, 0.12, length), color, (0, 0.06, z_center),
          tex=tex, tile=tile, bevel=False)


def _wall(s, name, size, pos, color=(0.46, 0.42, 0.38)):
    s.box(name, size, color, pos)


def _cottage(s, name, pos, size=(5, 3.2, 5), wall=(0.5, 0.43, 0.4),
             roof=(0.33, 0.23, 0.17), lit=True, brick=True):
    w, h, d = size
    win = (0.96, 0.86, 0.56) if lit else (0.16, 0.17, 0.21)   # warm vs dead-cold
    win_emis = (0.4, 0.34, 0.18) if lit else (0.0, 0.0, 0.0)
    # Brick masonry walls (textured) — every house in the city is brick.
    wall_part = {"kind": "box", "size": size,
                 "color": (0.84, 0.76, 0.72) if brick else wall, "pos": (0, h / 2, 0)}
    if brick:
        wall_part["tex"] = "brick"
        wall_part["tile"] = 1.3
    s.composite(name, [
        wall_part,
        {"kind": "pyramid", "size": (w + 0.5, d + 0.5), "height": 1.7,
         "color": (0.82, 0.6, 0.5), "pos": (0, h + 0.85, 0),
         "tex": "rooftile", "tile": 0.9},
        # plank door + two windows on the +Z face
        {"kind": "box", "size": (1.0, 1.9, 0.18), "color": (0.28, 0.2, 0.14),
         "pos": (0, 0.95, d / 2 + 0.03)},
        {"kind": "box", "size": (0.8, 0.8, 0.14), "color": win,
         "pos": (-w / 2 + 0.95, h * 0.62, d / 2 + 0.03), "emissive": win_emis},
        {"kind": "box", "size": (0.8, 0.8, 0.14), "color": win,
         "pos": (w / 2 - 0.95, h * 0.62, d / 2 + 0.03), "emissive": win_emis},
        # brick chimney
        {"kind": "box", "size": (0.6, 1.7, 0.6), "color": (0.3, 0.25, 0.22),
         "pos": (w / 2 - 0.8, h + 1.25, -d / 4)},
    ], pos=pos)


def _post(s, name, pos, height=6.0, color=(0.4, 0.38, 0.35)):
    s.box(name, (1.2, height, 1.2), color, (pos[0], height / 2, pos[2]))


def _sign(s, name, pos, color=(0.55, 0.45, 0.3)):
    s.composite(name, [
        {"kind": "box", "size": (0.2, 2.0, 0.2), "color": (0.3, 0.24, 0.18),
         "pos": (0, 1.0, 0)},
        {"kind": "box", "size": (1.8, 0.9, 0.12), "color": color,
         "pos": (0, 1.9, 0)},
        {"kind": "sphere", "radius": 0.16, "color": (0.28, 0.22, 0.16),
         "pos": (0, 2.06, 0)},
    ], pos=pos)


# Seven chapel visual variants (art bible / Batch 7 Skill 49). Each tunes the
# wall, roof-tile, steeple cap and the styling of the cross atop the steeple, so
# the chapel-cross language stays unified but shifts with the soul's journey:
# ruined (desolation), gate (entering), calvary (forgiveness), pilgrim (en-route
# restoration), trial (witness/martyrdom), river (faith facing death), celestial
# (ultimate worship). The node is still named PROP_Chapel so the binder attaches
# the Worship interactable.
_CHAPEL_KINDS = {
    "pilgrim":   {"wall": (0.84, 0.80, 0.74), "tile": (0.78, 0.50, 0.42), "roof": (0.50, 0.28, 0.24),
                  "cross": (0.96, 0.90, 0.60), "cross_emis": (0.55, 0.50, 0.25), "cross_scale": 1.0},
    "ruined":    {"wall": (0.50, 0.48, 0.44), "tile": (0.42, 0.34, 0.30), "roof": (0.32, 0.28, 0.26),
                  "cross": (0.80, 0.78, 0.62), "cross_emis": (0.34, 0.32, 0.20), "cross_scale": 0.95},
    "gate":      {"wall": (0.82, 0.80, 0.76), "tile": (0.70, 0.46, 0.36), "roof": (0.46, 0.30, 0.26),
                  "cross": (1.00, 0.94, 0.66), "cross_emis": (0.72, 0.62, 0.32), "cross_scale": 1.0},
    "calvary":   {"wall": (0.86, 0.82, 0.72), "tile": (0.74, 0.50, 0.40), "roof": (0.50, 0.30, 0.24),
                  "cross": (1.00, 0.96, 0.74), "cross_emis": (0.85, 0.78, 0.45), "cross_scale": 1.35},
    "trial":     {"wall": (0.66, 0.64, 0.60), "tile": (0.50, 0.42, 0.40), "roof": (0.40, 0.30, 0.28),
                  "cross": (0.90, 0.86, 0.66), "cross_emis": (0.45, 0.40, 0.22), "cross_scale": 1.0},
    "river":     {"wall": (0.80, 0.82, 0.84), "tile": (0.50, 0.50, 0.56), "roof": (0.40, 0.34, 0.40),
                  "cross": (0.86, 0.92, 1.00), "cross_emis": (0.45, 0.55, 0.75), "cross_scale": 1.1},
    "celestial": {"wall": (0.95, 0.90, 0.72), "tile": (0.95, 0.78, 0.30), "roof": (0.95, 0.78, 0.30),
                  "cross": (1.00, 0.98, 0.84), "cross_emis": (0.95, 0.85, 0.55), "cross_scale": 1.3},
}


def _chapel(s, name, pos, rot=(0, 0, 0), wall=None, roof=None, brick=True, kind="pilgrim"):
    """A small wayside chapel: nave + pitched roof + steeple crowned with a
    cross, a glowing rose window and warm-lit side windows. Bound to a
    'Worship' interactable by ImportedSceneBinder (PROP_Chapel).

    `kind` selects one of the seven _CHAPEL_KINDS visual variants; an explicit
    `wall`/`roof` still overrides the kind's defaults."""
    k = _CHAPEL_KINDS.get(kind, _CHAPEL_KINDS["pilgrim"])
    if wall is None:
        wall = k["wall"]
    if roof is None:
        roof = k["roof"]
    tile = k["tile"]
    cc = k["cross"]; ce = k["cross_emis"]; cs = k["cross_scale"]
    nave = {"kind": "box", "size": (5, 4, 7), "color": wall, "pos": (0, 2, 0)}
    tower = {"kind": "box", "size": (2.2, 7.5, 2.2), "color": wall, "pos": (0, 3.75, 4.3)}
    if brick:
        nave["tex"] = "brick"; nave["tile"] = 1.4
        tower["tex"] = "brick"; tower["tile"] = 1.3
    s.composite(name, [
        nave,
        {"kind": "box", "size": (5.4, 0.5, 7.4), "color": tile,
         "pos": (0, 4.05, 0), "tex": "rooftile", "tile": 1.0},
        {"kind": "pyramid", "size": (5.7, 7.7), "height": 2.2, "color": tile,
         "pos": (0, 5.2, 0), "tex": "rooftile", "tile": 1.0},
        tower,
        {"kind": "cone", "radius": 1.5, "height": 3.0, "color": roof, "pos": (0, 9.0, 4.3)},
        # cross atop the steeple (styled by chapel kind)
        {"kind": "box", "size": (0.18, 1.5 * cs, 0.18), "color": cc,
         "pos": (0, 11.0, 4.3), "emissive": ce},
        {"kind": "box", "size": (0.8 * cs, 0.18, 0.18), "color": cc,
         "pos": (0, 11.05, 4.3), "emissive": ce},
        # arched door
        {"kind": "box", "size": (1.3, 2.3, 0.25), "color": (0.3, 0.22, 0.16), "pos": (0, 1.15, 5.55)},
        # glowing rose window
        {"kind": "torus", "ring_r": 0.62, "tube_r": 0.12, "color": (0.72, 0.62, 0.42),
         "pos": (0, 3.0, 5.5), "rot": (90, 0, 0)},
        {"kind": "sphere", "radius": 0.5, "color": (1.0, 0.9, 0.6),
         "pos": (0, 3.0, 5.45), "emissive": (0.78, 0.64, 0.32)},
        # warm lit side windows
        {"kind": "box", "size": (0.2, 1.6, 1.1), "color": (1.0, 0.88, 0.6),
         "pos": (2.55, 2.2, -0.5), "emissive": (0.55, 0.45, 0.22)},
        {"kind": "box", "size": (0.2, 1.6, 1.1), "color": (1.0, 0.88, 0.6),
         "pos": (-2.55, 2.2, -0.5), "emissive": (0.55, 0.45, 0.22)},
    ], pos=pos, rot=rot)


# ---------------------------------------------------------------------------
# Industrial-grade landscape dressing helpers (reusable across every chapter).
#
# Decorative names embed ImportedSceneBinder skip-tokens (Foliage / Bush / Grass
# / Reeds / Flower / Ridge / Cairn / Hedge) so scatter never walls the pilgrim
# in; rocks/boulders ("Rock"/"Boulder") stay solid so the pilgrim walks around
# them. All decor is deliberately low-poly (few segments) for a web-safe budget.
# ---------------------------------------------------------------------------
def _shade(c, f):
    return (min(1.0, c[0] * f), min(1.0, c[1] * f), min(1.0, c[2] * f))


def _tree(s, name, pos, h=4.5, leaf=(0.24, 0.42, 0.24), trunk=(0.33, 0.24, 0.15)):
    """Round broadleaf tree. Name should contain 'Foliage' (kept non-solid)."""
    cr = h * 0.34
    s.composite(name, [
        {"kind": "cylinder", "radius": max(0.16, h * 0.045), "height": h * 0.62,
         "color": trunk, "pos": (0, h * 0.31, 0), "sides": 6},
        {"kind": "sphere", "radius": cr, "color": leaf, "pos": (0, h * 0.74, 0),
         "segs": 10, "rings": 6},
        {"kind": "sphere", "radius": cr * 0.74, "color": _shade(leaf, 1.1),
         "pos": (cr * 0.62, h * 0.94, cr * 0.2), "segs": 9, "rings": 5},
        {"kind": "sphere", "radius": cr * 0.66, "color": _shade(leaf, 0.9),
         "pos": (-cr * 0.55, h * 0.86, -cr * 0.3), "segs": 9, "rings": 5},
    ], pos=pos)


def _pine(s, name, pos, h=6.0, leaf=(0.17, 0.33, 0.23), trunk=(0.28, 0.21, 0.14)):
    """Conifer of stacked cones. Name should contain 'Foliage' (non-solid)."""
    s.composite(name, [
        {"kind": "cylinder", "radius": 0.16, "height": h * 0.3, "color": trunk,
         "pos": (0, h * 0.15, 0), "sides": 6},
        {"kind": "cone", "radius": h * 0.26, "height": h * 0.42, "color": leaf,
         "pos": (0, h * 0.42, 0), "sides": 8},
        {"kind": "cone", "radius": h * 0.2, "height": h * 0.34, "color": _shade(leaf, 1.1),
         "pos": (0, h * 0.64, 0), "sides": 8},
        {"kind": "cone", "radius": h * 0.13, "height": h * 0.28, "color": _shade(leaf, 1.2),
         "pos": (0, h * 0.84, 0), "sides": 7},
    ], pos=pos)


def _bush(s, name, pos, r=0.8, col=(0.3, 0.42, 0.26)):
    """Shrub. Name should contain 'Bush' (non-solid)."""
    s.composite(name, [
        {"kind": "sphere", "radius": r, "color": col, "pos": (0, r * 0.7, 0),
         "segs": 9, "rings": 5},
        {"kind": "sphere", "radius": r * 0.72, "color": _shade(col, 1.12),
         "pos": (r * 0.55, r * 0.92, r * 0.2), "segs": 8, "rings": 5},
    ], pos=pos)


def _rock(s, name, pos, sz=1.2, col=(0.5, 0.47, 0.42)):
    """Solid rock/boulder cluster (name contains 'Rock'/'Boulder' -> solid)."""
    s.composite(name, [
        {"kind": "sphere", "radius": sz * 0.6, "color": col, "pos": (0, sz * 0.4, 0),
         "segs": 8, "rings": 5},
        {"kind": "box", "size": (sz, sz * 0.7, sz * 0.9), "color": _shade(col, 0.92),
         "pos": (sz * 0.4, sz * 0.34, -sz * 0.2)},
    ], pos=pos)


def _grass(s, name, pos, col=(0.5, 0.55, 0.32)):
    """Grass tuft fan. Name should contain 'Grass'/'Tuft' (non-solid)."""
    s.composite(name, [
        {"kind": "cone", "radius": 0.12, "height": 0.6, "color": col,
         "pos": (dx * 0.16, 0.3, dz * 0.16), "sides": 5}
        for dx, dz in ((-1, 0), (0, 0), (1, 0), (0, 1), (0, -1))], pos=pos)


def _reedclump(s, name, pos, col=(0.4, 0.45, 0.32), h=1.6):
    """Reed/cattail clump. Name should contain 'Reeds' (non-solid)."""
    s.composite(name, [
        {"kind": "cylinder", "radius": 0.05, "height": h + (i % 3) * 0.2, "color": col,
         "pos": (((i % 5) - 2) * 0.18, (h + (i % 3) * 0.2) / 2, ((i // 5) - 1) * 0.2),
         "sides": 4}
        for i in range(10)], pos=pos)


def _flower(s, name, pos, petal=(0.9, 0.6, 0.7), emis=None):
    """Single bloom. Name should contain 'Flower' (non-solid)."""
    s.composite(name, [
        {"kind": "cylinder", "radius": 0.04, "height": 0.5, "color": (0.4, 0.5, 0.3),
         "pos": (0, 0.25, 0), "sides": 4},
        {"kind": "sphere", "radius": 0.16, "color": petal, "pos": (0, 0.56, 0),
         "segs": 8, "rings": 5, "emissive": emis}], pos=pos)


def _ridge(s, name, pos, peaks, col=(0.32, 0.33, 0.4)):
    """Distant mountain/ridge silhouette: a row of wide pyramids. Non-solid
    (name should contain 'Ridge'). `peaks` = list of (x, width, height)."""
    s.composite(name, [
        {"kind": "pyramid", "size": (w, w), "height": hgt, "color": col, "pos": (px, 0, 0)}
        for (px, w, hgt) in peaks], pos=pos)


def _lantern(s, name, pos, col=(1.0, 0.86, 0.5)):
    """Lamp post (solid pole + glowing head)."""
    s.composite(name, [
        {"kind": "cylinder", "radius": 0.1, "height": 2.6, "color": (0.26, 0.24, 0.2),
         "pos": (0, 1.3, 0), "sides": 6},
        {"kind": "box", "size": (0.42, 0.5, 0.42), "color": col, "pos": (0, 2.75, 0),
         "emissive": (col[0] * 0.65, col[1] * 0.5, col[2] * 0.28)}], pos=pos)


# ===========================================================================
# Low-poly population & life helpers (living worlds: people, shops, goods,
# flora, fauna, feast, and the throne). Deterministic (name-seeded LCG, no
# imports) so every rebuild is identical. People/crowd names carry the binder
# "Crowd" skip-token so the player walks among them (non-solid); flora/fauna use
# their own skip-tokens (Flower/Grass/Foliage/Crow/Sheep).
# ===========================================================================
_ROBES = [(0.42, 0.36, 0.42), (0.5, 0.34, 0.3), (0.34, 0.4, 0.5), (0.55, 0.5, 0.34),
          (0.4, 0.44, 0.4), (0.6, 0.4, 0.46), (0.46, 0.42, 0.5), (0.5, 0.46, 0.4)]
_SKIN = [(0.74, 0.6, 0.5), (0.6, 0.46, 0.36), (0.82, 0.68, 0.56), (0.5, 0.38, 0.3)]


class _Rng:
    """Tiny deterministic LCG seeded from a string — reproducible scatter."""
    def __init__(self, name):
        v = 2166136261
        for c in str(name):
            v = ((v ^ ord(c)) * 16777619) & 0xffffffff
        self.s = v or 1

    def f(self):
        self.s = (1103515245 * self.s + 12345) & 0x7fffffff
        return self.s / 0x7fffffff

    def rng(self, a, b):
        return a + (b - a) * self.f()

    def pick(self, seq):
        return seq[int(self.f() * len(seq)) % len(seq)]


def _person_parts(x, z, robe, skin, h=1.5, arm=False):
    """Composite parts for one low-poly figure standing at local (x, z)."""
    parts = [
        {"kind": "cylinder", "radius": 0.34, "height": h, "color": robe, "pos": (x, h * 0.5, z), "sides": 7},
        {"kind": "sphere", "radius": 0.25, "color": skin, "pos": (x, h + 0.16, z)},
        {"kind": "box", "size": (0.5, 0.32, 0.5), "color": robe, "pos": (x, h * 0.78, z)},  # shoulders
    ]
    if arm:
        parts.append({"kind": "cylinder", "radius": 0.08, "height": 0.7, "color": robe,
                      "pos": (x + 0.32, h * 0.86, z), "rot": (0, 0, 38)})
    return parts


def _crowd(s, name, pos, rows=3, cols=4, spacing=1.25, robes=None, hands_raised=False):
    """A dense crowd of low-poly figures (rows×cols). Name should contain
    'Crowd' so it stays non-solid (the player moves through the throng)."""
    rng = _Rng(name)
    robes = robes or _ROBES
    parts = []
    for i in range(rows):
        for j in range(cols):
            x = (j - (cols - 1) / 2.0) * spacing + rng.rng(-0.22, 0.22)
            z = (i - (rows - 1) / 2.0) * spacing + rng.rng(-0.22, 0.22)
            parts += _person_parts(x, z, rng.pick(robes), rng.pick(_SKIN),
                                   h=rng.rng(1.3, 1.7), arm=(hands_raised and rng.f() > 0.4))
    s.composite(name, parts, pos=pos)


def _market_goods(s, name, pos, palette=None):
    """A heap of bright wares on a stall counter (crates, fruit, bolts of cloth,
    trinkets). Small + elevated, off the walkable path."""
    rng = _Rng(name)
    pal = palette or [(0.9, 0.3, 0.2), (0.95, 0.78, 0.2), (0.3, 0.6, 0.8), (0.7, 0.2, 0.6),
                      (0.4, 0.7, 0.3), (0.95, 0.5, 0.15)]
    parts = []
    for k in range(7):
        kind = "sphere" if rng.f() > 0.5 else "box"
        c = rng.pick(pal)
        x = rng.rng(-1.1, 1.1); z = rng.rng(-0.6, 0.6); r = rng.rng(0.16, 0.3)
        if kind == "sphere":
            parts.append({"kind": "sphere", "radius": r, "color": c, "pos": (x, 0.05 + r, z)})
        else:
            parts.append({"kind": "box", "size": (r * 1.6, r * 1.6, r * 1.6), "color": c, "pos": (x, 0.05 + r, z), "tex": "cloth"})
    s.composite(name, parts, pos=pos)


def _shop(s, name, pos, awning=(0.8, 0.2, 0.25), rot=(0, 0, 0)):
    """A merchant booth: timber counter + back stall + striped awning + wares +
    a shopkeeper. Solid frame; placed off the central street."""
    s.composite(name, [
        {"kind": "box", "size": (3.4, 1.0, 1.2), "color": (0.45, 0.32, 0.2), "pos": (0, 0.5, 1.0), "tex": "wood", "tile": 0.8},
        {"kind": "box", "size": (3.6, 2.6, 0.3), "color": (0.4, 0.3, 0.2), "pos": (0, 1.3, -1.4), "tex": "wood"},
        {"kind": "box", "size": (0.2, 2.4, 0.2), "color": (0.34, 0.26, 0.18), "pos": (-1.7, 1.2, 0.9), "tex": "wood"},
        {"kind": "box", "size": (0.2, 2.4, 0.2), "color": (0.34, 0.26, 0.18), "pos": (1.7, 1.2, 0.9), "tex": "wood"},
        {"kind": "box", "size": (4.0, 0.16, 2.6), "color": awning, "pos": (0, 2.5, 0.0), "rot": (12, 0, 0)},
    ], pos=pos, rot=rot)
    _market_goods(s, name + "_Goods", (pos[0], 1.05, pos[2] + 1.0))
    rng = _Rng(name)
    s.composite(name + "_Keeper_Crowd", _person_parts(0, 0, rng.pick(_ROBES), rng.pick(_SKIN), h=1.6, arm=True),
                pos=(pos[0], 0, pos[2] - 0.6))


def _flora(s, name, pos, kind="flower", n=6):
    """A small cluster of flowers / grass tufts / ferns (non-solid via the
    Flower/Grass/Foliage skip-tokens — embed one in `name`)."""
    rng = _Rng(name)
    cols = {"flower": [(0.92, 0.6, 0.72), (0.95, 0.85, 0.4), (0.7, 0.6, 0.95), (0.95, 0.5, 0.4)],
            "grass": [(0.42, 0.56, 0.28), (0.36, 0.5, 0.24)],
            "fern": [(0.28, 0.46, 0.26), (0.32, 0.5, 0.3)]}.get(kind, [(0.5, 0.7, 0.4)])
    parts = []
    for k in range(n):
        x = rng.rng(-0.8, 0.8); z = rng.rng(-0.8, 0.8); hh = rng.rng(0.3, 0.7)
        parts.append({"kind": "cylinder", "radius": 0.04, "height": hh, "color": (0.34, 0.46, 0.26), "pos": (x, hh / 2, z), "sides": 4})
        if kind == "flower":
            parts.append({"kind": "sphere", "radius": 0.12, "color": rng.pick(cols), "pos": (x, hh, z)})
        else:
            parts.append({"kind": "cone", "radius": 0.12, "height": 0.4, "color": rng.pick(cols), "pos": (x, hh, z)})
    s.composite(name, parts, pos=pos)


def _fauna(s, name, pos, kind="bird"):
    """A single small creature. Use skip-token names: Crow (birds), Sheep, or
    Foliage (small critters) so they never wall the player."""
    if kind == "sheep":
        s.composite(name, [
            {"kind": "sphere", "radius": 0.5, "color": (0.86, 0.84, 0.8), "pos": (0, 0.7, 0)},
            {"kind": "sphere", "radius": 0.22, "color": (0.25, 0.22, 0.2), "pos": (0, 0.85, 0.5)},
            {"kind": "box", "size": (0.12, 0.5, 0.12), "color": (0.3, 0.27, 0.24), "pos": (0.25, 0.25, 0.3)},
            {"kind": "box", "size": (0.12, 0.5, 0.12), "color": (0.3, 0.27, 0.24), "pos": (-0.25, 0.25, 0.3)},
        ], pos=pos)
    elif kind == "dog":
        s.composite(name, [
            {"kind": "box", "size": (0.9, 0.4, 0.35), "color": (0.4, 0.3, 0.22), "pos": (0, 0.5, 0)},
            {"kind": "sphere", "radius": 0.2, "color": (0.42, 0.32, 0.24), "pos": (0.5, 0.6, 0)},
        ], pos=pos)
    else:  # perched/winged bird
        s.composite(name, [
            {"kind": "sphere", "radius": 0.14, "color": (0.16, 0.15, 0.16), "pos": (0, 0, 0)},
            {"kind": "box", "size": (0.5, 0.04, 0.18), "color": (0.12, 0.11, 0.12), "pos": (0, 0.02, 0)},
        ], pos=pos)


def _feast_table(s, name, pos, length=7.0, rot=(0, 0, 0)):
    """A long banquet table (the marriage supper): white cloth + benches + a
    heap of food and gold goblets."""
    parts = [
        {"kind": "box", "size": (1.6, 0.16, length), "color": (0.96, 0.93, 0.86), "pos": (0, 1.0, 0), "tex": "cloth", "tile": 1.4},
        {"kind": "box", "size": (1.5, 1.0, length - 0.4), "color": (0.92, 0.88, 0.8), "pos": (0, 0.5, 0)},
        {"kind": "box", "size": (0.5, 0.4, length), "color": (0.7, 0.55, 0.3), "pos": (1.4, 0.4, 0), "tex": "wood"},
        {"kind": "box", "size": (0.5, 0.4, length), "color": (0.7, 0.55, 0.3), "pos": (-1.4, 0.4, 0), "tex": "wood"},
    ]
    rng = _Rng(name)
    fruit = [(0.9, 0.3, 0.2), (0.95, 0.8, 0.25), (0.6, 0.2, 0.5), (0.4, 0.7, 0.3)]
    for k in range(int(length)):
        z = (k - length / 2.0) + 0.6
        parts.append({"kind": "sphere", "radius": rng.rng(0.16, 0.26), "color": rng.pick(fruit), "pos": (rng.rng(-0.4, 0.4), 1.18, z)})
        parts.append({"kind": "cylinder", "radius": 0.1, "height": 0.32, "color": (0.95, 0.82, 0.4), "pos": (rng.rng(-0.5, 0.5), 1.24, z + 0.3), "emissive": (0.4, 0.34, 0.12)})
    s.composite(name, parts, pos=pos, rot=rot)


def _angel(s, name, pos, h=2.2, rot=(0, 0, 0)):
    """A radiant winged figure (white robe, soft gold light, broad wings)."""
    s.composite(name, [
        {"kind": "cylinder", "radius": 0.4, "height": h, "color": (0.97, 0.95, 0.86), "pos": (0, h * 0.5, 0), "emissive": (0.4, 0.38, 0.28)},
        {"kind": "sphere", "radius": 0.28, "color": (0.98, 0.92, 0.78), "pos": (0, h + 0.2, 0), "emissive": (0.5, 0.45, 0.3)},
        {"kind": "box", "size": (0.18, 2.4, 1.0), "color": (0.99, 0.97, 0.9), "pos": (0.6, h * 0.7, -0.2), "rot": (0, 0, 28), "emissive": (0.45, 0.42, 0.32)},
        {"kind": "box", "size": (0.18, 2.4, 1.0), "color": (0.99, 0.97, 0.9), "pos": (-0.6, h * 0.7, -0.2), "rot": (0, 0, -28), "emissive": (0.45, 0.42, 0.32)},
    ], pos=pos, rot=rot)


def _enthroned_lord(s, base, pos):
    """The crowned Lord enthroned in glory (Rev 4-5; 19) — reverent and symbolic,
    not a literal face: a radiant white-and-gold robed figure, a gold crown, a
    halo of light, hand raised in welcome, upon a gilded throne under a shaft of
    glory. Marble dais + steps. Solid throne; the figure reads as light."""
    # gilded throne + marble dais
    s.composite(base + "_Throne", [
        {"kind": "box", "size": (5.0, 0.6, 5.0), "color": (0.92, 0.9, 0.84), "pos": (0, 0.3, 0), "tex": "marble", "tile": 1.0},
        {"kind": "box", "size": (3.6, 0.5, 3.6), "color": (0.95, 0.92, 0.86), "pos": (0, 0.85, 0), "tex": "marble", "tile": 1.0},
        {"kind": "box", "size": (3.0, 2.0, 1.0), "color": (0.96, 0.82, 0.36), "pos": (0, 2.1, -1.3), "tex": "gold", "emissive": (0.55, 0.45, 0.18)},
        {"kind": "box", "size": (0.7, 3.4, 0.7), "color": (0.96, 0.82, 0.36), "pos": (-1.4, 2.7, -1.3), "tex": "gold", "emissive": (0.55, 0.45, 0.18)},
        {"kind": "box", "size": (0.7, 3.4, 0.7), "color": (0.96, 0.82, 0.36), "pos": (1.4, 2.7, -1.3), "tex": "gold", "emissive": (0.55, 0.45, 0.18)},
        {"kind": "box", "size": (1.0, 1.2, 1.0), "color": (0.98, 0.86, 0.4), "pos": (0, 1.7, -0.3)},  # seat
    ], pos=pos)
    # the radiant figure (face left to light), crown, halo, raised hand
    s.composite(base + "_Lord_Glow", [
        {"kind": "cylinder", "radius": 0.6, "height": 2.6, "color": (0.99, 0.97, 0.9), "pos": (0, 1.3, 0), "emissive": (0.7, 0.66, 0.5)},
        {"kind": "box", "size": (1.7, 0.5, 0.7), "color": (0.99, 0.97, 0.9), "pos": (0, 2.0, 0), "emissive": (0.6, 0.56, 0.42)},  # shoulders/mantle
        {"kind": "sphere", "radius": 0.4, "color": (1.0, 0.98, 0.92), "pos": (0, 2.95, 0), "emissive": (0.85, 0.8, 0.62)},  # head as light
        {"kind": "torus", "ring_r": 0.62, "tube_r": 0.08, "color": (1.0, 0.95, 0.7), "pos": (0, 3.0, -0.05), "rot": (90, 0, 0), "emissive": (0.95, 0.85, 0.5)},  # halo
        {"kind": "cone", "radius": 0.5, "height": 0.5, "color": (0.98, 0.85, 0.35), "pos": (0, 3.35, 0), "emissive": (0.7, 0.55, 0.2)},  # crown band
        {"kind": "box", "size": (0.16, 0.5, 0.16), "color": (0.98, 0.86, 0.4), "pos": (0, 3.7, 0), "emissive": (0.7, 0.55, 0.2)},  # crown peak
        {"kind": "cylinder", "radius": 0.12, "height": 1.0, "color": (0.99, 0.97, 0.9), "pos": (0.7, 2.1, 0.3), "rot": (0, 0, 52), "emissive": (0.6, 0.56, 0.42)},  # raised hand of welcome
    ], pos=(pos[0], pos[1] + 1.1, pos[2] - 0.3))
    # shaft of glory + a small Lamb at the foot of the throne (Rev 5)
    s.box(base + "_GloryShaft_Glow", (4.5, 16, 4.5), (1.0, 0.96, 0.8), (pos[0], pos[1] + 9, pos[2]),
          emissive=(0.7, 0.64, 0.4), blend=True, bevel=False)
    s.composite(base + "_Lamb", [
        {"kind": "sphere", "radius": 0.42, "color": (0.98, 0.96, 0.92), "pos": (0, 0.5, 0), "emissive": (0.4, 0.38, 0.3)},
        {"kind": "sphere", "radius": 0.22, "color": (0.98, 0.96, 0.92), "pos": (0, 0.7, 0.4), "emissive": (0.4, 0.38, 0.3)},
    ], pos=(pos[0], pos[1] + 0.7, pos[2] + 2.6))


# ---------------------------------------------------------------------------
# Living-worlds pass: ambient fauna & inhabitants
# ---------------------------------------------------------------------------
# Small, deterministic creatures and stand-in figures used to make each place
# feel inhabited. ALL are decorative and must stay walk-through: embed a binder
# skip-token in the node name (Fauna / Critter / Household / Crow / Dove /
# Butterfly / Firefly / Crowd / Sheep / Foliage). Geometry is deliberately tiny
# (a handful of primitives each) to keep GLBs small.
def _bird(s, name, pos, kind="songbird", rot=(0, 0, 0)):
    """A single posed bird. `name` MUST contain a skip-token (e.g. Crow/Dove/
    Fauna) so it never blocks the player."""
    if kind == "heron":          # tall wader: long legs, S-neck, dagger beak
        parts = [
            {"kind": "cylinder", "radius": 0.05, "height": 1.3, "color": (0.7, 0.66, 0.5), "pos": (-0.12, 0.65, 0), "sides": 5},
            {"kind": "cylinder", "radius": 0.05, "height": 1.3, "color": (0.7, 0.66, 0.5), "pos": (0.12, 0.65, 0), "sides": 5},
            {"kind": "sphere", "radius": 0.3, "color": (0.62, 0.66, 0.72), "pos": (0, 1.45, 0), "segs": 8, "rings": 5},
            {"kind": "cylinder", "radius": 0.07, "height": 0.8, "color": (0.66, 0.7, 0.76), "pos": (0, 1.95, 0.1), "rot": (24, 0, 0), "sides": 5},
            {"kind": "sphere", "radius": 0.12, "color": (0.6, 0.64, 0.7), "pos": (0, 2.35, 0.22), "segs": 7, "rings": 4},
            {"kind": "cone", "radius": 0.05, "height": 0.4, "color": (0.92, 0.78, 0.3), "pos": (0, 2.4, 0.45), "rot": (90, 0, 0), "sides": 5}]
    elif kind == "duck":         # rounded floating body + head + bill
        parts = [
            {"kind": "sphere", "radius": 0.3, "color": (0.4, 0.34, 0.26), "pos": (0, 0.18, 0), "segs": 9, "rings": 5},
            {"kind": "sphere", "radius": 0.16, "color": (0.18, 0.4, 0.3), "pos": (0.26, 0.34, 0), "segs": 8, "rings": 4, "emissive": (0.04, 0.1, 0.07)},
            {"kind": "cone", "radius": 0.07, "height": 0.22, "color": (0.9, 0.74, 0.28), "pos": (0.42, 0.32, 0), "rot": (0, 0, -90), "sides": 5}]
    elif kind == "swan":         # white body, long curved neck, orange bill
        parts = [
            {"kind": "sphere", "radius": 0.4, "color": (0.97, 0.96, 0.94), "pos": (0, 0.3, 0), "segs": 10, "rings": 6, "emissive": (0.18, 0.18, 0.18)},
            {"kind": "cylinder", "radius": 0.07, "height": 0.7, "color": (0.97, 0.96, 0.94), "pos": (0.18, 0.7, 0.05), "rot": (24, 0, -12), "sides": 6, "emissive": (0.14, 0.14, 0.14)},
            {"kind": "sphere", "radius": 0.13, "color": (0.97, 0.96, 0.94), "pos": (0.32, 1.0, 0.12), "segs": 7, "rings": 4, "emissive": (0.16, 0.16, 0.16)},
            {"kind": "cone", "radius": 0.05, "height": 0.2, "color": (0.92, 0.5, 0.2), "pos": (0.46, 0.98, 0.12), "rot": (0, 0, -90), "sides": 5}]
    elif kind == "dove":         # small radiant body, wings tucked-up (flight)
        parts = [
            {"kind": "sphere", "radius": 0.15, "color": (0.98, 0.97, 0.94), "pos": (0, 0, 0), "segs": 7, "rings": 4, "emissive": (0.4, 0.4, 0.38)},
            {"kind": "box", "size": (0.56, 0.04, 0.2), "color": (0.97, 0.96, 0.92), "pos": (0, 0.06, 0), "rot": (0, 0, 18), "emissive": (0.3, 0.3, 0.28)},
            {"kind": "cone", "radius": 0.1, "height": 0.28, "color": (0.95, 0.94, 0.9), "pos": (-0.2, 0, 0), "rot": (0, 0, 90), "sides": 5}]
    elif kind == "peacock":      # noble fan tail + crest
        parts = [
            {"kind": "sphere", "radius": 0.26, "color": (0.1, 0.3, 0.5), "pos": (0, 0.5, 0), "segs": 9, "rings": 5, "emissive": (0.04, 0.12, 0.2)},
            {"kind": "cylinder", "radius": 0.07, "height": 0.5, "color": (0.12, 0.34, 0.46), "pos": (0, 0.85, 0.05), "rot": (16, 0, 0), "sides": 6},
            {"kind": "sphere", "radius": 0.12, "color": (0.12, 0.38, 0.5), "pos": (0, 1.12, 0.1), "segs": 7, "rings": 4, "emissive": (0.05, 0.16, 0.22)},
            {"kind": "pyramid", "size": (1.7, 0.16), "height": 1.7, "color": (0.16, 0.42, 0.34), "pos": (0, 0.95, -0.7), "rot": (74, 0, 0), "emissive": (0.06, 0.18, 0.14)},
            {"kind": "sphere", "radius": 0.08, "color": (0.2, 0.5, 0.3), "pos": (0, 1.5, -1.15), "segs": 6, "rings": 4, "emissive": (0.1, 0.3, 0.16)}]
    elif kind == "owl":          # round body, big head, eye-spots (perched)
        parts = [
            {"kind": "sphere", "radius": 0.24, "color": (0.42, 0.36, 0.28), "pos": (0, 0.2, 0), "segs": 8, "rings": 5},
            {"kind": "sphere", "radius": 0.2, "color": (0.46, 0.4, 0.32), "pos": (0, 0.52, 0), "segs": 8, "rings": 5},
            {"kind": "sphere", "radius": 0.06, "color": (0.95, 0.82, 0.3), "pos": (-0.08, 0.56, 0.16), "segs": 6, "rings": 4, "emissive": (0.5, 0.42, 0.12)},
            {"kind": "sphere", "radius": 0.06, "color": (0.95, 0.82, 0.3), "pos": (0.08, 0.56, 0.16), "segs": 6, "rings": 4, "emissive": (0.5, 0.42, 0.12)}]
    elif kind == "raptor":       # dark soaring bird (hawk / vulture), wings out
        parts = [
            {"kind": "sphere", "radius": 0.18, "color": (0.14, 0.12, 0.12), "pos": (0, 0, 0), "segs": 7, "rings": 4},
            {"kind": "box", "size": (1.7, 0.05, 0.4), "color": (0.12, 0.1, 0.1), "pos": (0, 0.02, 0), "rot": (0, 0, 8)},
            {"kind": "box", "size": (0.3, 0.04, 0.4), "color": (0.1, 0.09, 0.09), "pos": (-0.1, 0, -0.3)}]
    else:                         # songbird / lark / kingfisher (small perched)
        body = {"songbird": (0.5, 0.34, 0.22), "lark": (0.55, 0.46, 0.3),
                "kingfisher": (0.12, 0.46, 0.7)}.get(kind, (0.5, 0.34, 0.22))
        breast = (0.85, 0.5, 0.25) if kind == "kingfisher" else (0.7, 0.6, 0.4)
        parts = [
            {"kind": "sphere", "radius": 0.13, "color": body, "pos": (0, 0, 0), "segs": 7, "rings": 4},
            {"kind": "sphere", "radius": 0.09, "color": breast, "pos": (0.04, -0.04, 0.08), "segs": 6, "rings": 4},
            {"kind": "cone", "radius": 0.06, "height": 0.28, "color": body, "pos": (-0.16, 0.02, 0), "rot": (0, 0, 90), "sides": 5},
            {"kind": "cone", "radius": 0.03, "height": 0.14, "color": (0.9, 0.74, 0.3), "pos": (0.2, 0.0, 0), "rot": (0, 0, -90), "sides": 4}]
    s.composite(name, parts, pos=pos, rot=rot)


def _critter(s, name, pos, kind="frog", rot=(0, 0, 0), col=None):
    """A small ground/water/air critter. `name` MUST contain a skip-token
    (Critter / Fauna / Butterfly / Foliage). `col` tints butterfly/moth wings."""
    if kind in ("frog", "toad"):
        body = (0.3, 0.5, 0.26) if kind == "frog" else (0.42, 0.36, 0.24)
        parts = [
            {"kind": "sphere", "radius": 0.18, "color": body, "pos": (0, 0.12, 0), "segs": 8, "rings": 4},
            {"kind": "sphere", "radius": 0.06, "color": body, "pos": (-0.08, 0.24, 0.08), "segs": 6, "rings": 4},
            {"kind": "sphere", "radius": 0.06, "color": body, "pos": (0.08, 0.24, 0.08), "segs": 6, "rings": 4},
            {"kind": "sphere", "radius": 0.03, "color": (0.95, 0.85, 0.2), "pos": (-0.08, 0.27, 0.12), "segs": 5, "rings": 3, "emissive": (0.4, 0.36, 0.1)},
            {"kind": "sphere", "radius": 0.03, "color": (0.95, 0.85, 0.2), "pos": (0.08, 0.27, 0.12), "segs": 5, "rings": 3, "emissive": (0.4, 0.36, 0.1)}]
    elif kind == "dragonfly":    # thin body + 2 pairs of shimmering wings
        parts = [
            {"kind": "cylinder", "radius": 0.03, "height": 0.5, "color": (0.2, 0.55, 0.55), "pos": (0, 0, 0), "rot": (90, 0, 0), "sides": 5, "emissive": (0.1, 0.3, 0.3)},
            {"kind": "box", "size": (0.5, 0.02, 0.14), "color": (0.7, 0.85, 0.9), "pos": (0, 0.02, 0.06), "emissive": (0.4, 0.5, 0.55)},
            {"kind": "box", "size": (0.5, 0.02, 0.14), "color": (0.7, 0.85, 0.9), "pos": (0, 0.02, -0.06), "emissive": (0.4, 0.5, 0.55)},
            {"kind": "sphere", "radius": 0.05, "color": (0.2, 0.6, 0.6), "pos": (0, 0, 0.24), "segs": 6, "rings": 4, "emissive": (0.1, 0.34, 0.34)}]
    elif kind == "butterfly":    # 2 colourful wings + slim body (or pale moth)
        col = col or (0.95, 0.6, 0.2)
        parts = [
            {"kind": "cylinder", "radius": 0.02, "height": 0.22, "color": (0.15, 0.12, 0.1), "pos": (0, 0, 0), "rot": (90, 0, 0), "sides": 4},
            {"kind": "box", "size": (0.26, 0.02, 0.22), "color": col, "pos": (0.14, 0.01, 0), "rot": (0, 0, 24), "emissive": (col[0]*0.4, col[1]*0.4, col[2]*0.3)},
            {"kind": "box", "size": (0.26, 0.02, 0.22), "color": col, "pos": (-0.14, 0.01, 0), "rot": (0, 0, -24), "emissive": (col[0]*0.4, col[1]*0.4, col[2]*0.3)}]
    elif kind == "fish":         # a back breaking the surface + ripple ring
        parts = [
            {"kind": "torus", "ring_r": 0.5, "tube_r": 0.04, "color": (0.6, 0.7, 0.75), "pos": (0, 0.02, 0), "rot": (90, 0, 0), "emissive": (0.2, 0.26, 0.3)},
            {"kind": "sphere", "radius": 0.16, "color": (0.42, 0.46, 0.5), "pos": (0, 0.06, 0), "segs": 8, "rings": 4},
            {"kind": "cone", "radius": 0.12, "height": 0.2, "color": (0.4, 0.44, 0.48), "pos": (-0.2, 0.12, 0), "rot": (0, 0, 70), "sides": 4}]
    elif kind == "deer":         # graceful quadruped
        tan = (0.52, 0.38, 0.24)
        parts = [
            {"kind": "box", "size": (0.5, 0.55, 1.3), "color": tan, "pos": (0, 1.0, 0)},
            {"kind": "cylinder", "radius": 0.07, "height": 1.0, "color": tan, "pos": (0.17, 0.5, 0.45), "sides": 5},
            {"kind": "cylinder", "radius": 0.07, "height": 1.0, "color": tan, "pos": (-0.17, 0.5, 0.45), "sides": 5},
            {"kind": "cylinder", "radius": 0.07, "height": 1.0, "color": tan, "pos": (0.17, 0.5, -0.45), "sides": 5},
            {"kind": "cylinder", "radius": 0.07, "height": 1.0, "color": tan, "pos": (-0.17, 0.5, -0.45), "sides": 5},
            {"kind": "cylinder", "radius": 0.11, "height": 0.7, "color": tan, "pos": (0, 1.5, 0.7), "rot": (52, 0, 0), "sides": 6},
            {"kind": "sphere", "radius": 0.2, "color": tan, "pos": (0, 1.85, 0.95), "segs": 8, "rings": 5}]
    elif kind == "fox":          # small russet quadruped + bushy tail
        red = (0.7, 0.36, 0.16)
        parts = [
            {"kind": "box", "size": (0.34, 0.32, 0.95), "color": red, "pos": (0, 0.45, 0)},
            {"kind": "sphere", "radius": 0.2, "color": red, "pos": (0, 0.55, 0.55), "segs": 8, "rings": 5},
            {"kind": "cone", "radius": 0.08, "height": 0.2, "color": red, "pos": (-0.08, 0.74, 0.6), "sides": 4},
            {"kind": "cone", "radius": 0.08, "height": 0.2, "color": red, "pos": (0.08, 0.74, 0.6), "sides": 4},
            {"kind": "cylinder", "radius": 0.12, "height": 0.6, "color": (0.85, 0.6, 0.4), "pos": (0, 0.45, -0.6), "rot": (70, 0, 0), "sides": 6},
            {"kind": "cylinder", "radius": 0.05, "height": 0.4, "color": (0.2, 0.16, 0.12), "pos": (0.12, 0.2, 0.3), "sides": 4},
            {"kind": "cylinder", "radius": 0.05, "height": 0.4, "color": (0.2, 0.16, 0.12), "pos": (-0.12, 0.2, -0.3), "sides": 4}]
    elif kind == "hare":         # small rounded body + long ears
        gr = (0.55, 0.48, 0.38)
        parts = [
            {"kind": "sphere", "radius": 0.22, "color": gr, "pos": (0, 0.22, 0), "segs": 8, "rings": 5},
            {"kind": "sphere", "radius": 0.13, "color": gr, "pos": (0, 0.38, 0.2), "segs": 7, "rings": 4},
            {"kind": "box", "size": (0.05, 0.34, 0.1), "color": gr, "pos": (-0.06, 0.6, 0.16), "rot": (12, 0, -6)},
            {"kind": "box", "size": (0.05, 0.34, 0.1), "color": gr, "pos": (0.06, 0.6, 0.16), "rot": (12, 0, 6)}]
    elif kind == "midges":       # a faint hovering cloud of gnats over the bog
        rng = _Rng(name)
        parts = [{"kind": "sphere", "radius": 0.025, "color": (0.2, 0.2, 0.16),
                  "pos": (rng.rng(-0.5, 0.5), rng.rng(-0.3, 0.3), rng.rng(-0.5, 0.5)),
                  "segs": 4, "rings": 3, "emissive": (0.1, 0.1, 0.06)} for _ in range(9)]
    else:
        parts = [{"kind": "sphere", "radius": 0.1, "color": (0.4, 0.4, 0.4), "pos": (0, 0.1, 0), "segs": 6, "rings": 4}]
    s.composite(name, parts, pos=pos, rot=rot)


def _household_figure(s, name, pos, robe=None, skin=None, h=1.55, arm=False, rot=(0, 0, 0)):
    """One placed inhabitant (servant, guest, attendant). `name` MUST contain
    a skip-token (Household / Crowd) so the player walks past, not into, them."""
    rng = _Rng(name)
    robe = robe or rng.pick(_ROBES)
    skin = skin or rng.pick(_SKIN)
    s.composite(name, _person_parts(0, 0, robe, skin, h=h, arm=arm), pos=pos, rot=rot)


# ===========================================================================
# CHAPTER 1 - City of Destruction
# ===========================================================================
def _urban_building(s, name, pos, size=(5, 8, 5), wall=(0.42, 0.4, 0.42),
                    lit=True, brick=True, pitched=False):
    """A multi-storey CITY building (not a village hut): brick-textured walls, a
    flat stone parapet (or, rarely, a low pitched roof), and rows of windows
    (mostly dark in the doomed city, a few lit). Taller than a cottage so the
    skyline reads urban."""
    w, h, d = size
    win_lit = (0.96, 0.86, 0.56)
    win_dead = (0.12, 0.12, 0.15)
    wall_part = {"kind": "box", "size": size,
                 "color": (0.5, 0.46, 0.44) if brick else wall, "pos": (0, h / 2, 0)}
    if brick:
        wall_part["tex"] = "brick"
        wall_part["tile"] = 1.6
    parts = [wall_part]
    if pitched:
        parts.append({"kind": "pyramid", "size": (w + 0.4, d + 0.4), "height": 1.6,
                      "color": (0.3, 0.26, 0.24), "pos": (0, h + 0.8, 0),
                      "tex": "rooftile", "tile": 0.9})
    else:
        parts.append({"kind": "box", "size": (w + 0.45, 0.55, d + 0.45),
                      "color": (0.3, 0.3, 0.33), "pos": (0, h + 0.2, 0),
                      "tex": "stone", "tile": 1.2})
    floors = max(1, int(h // 2.4))
    for f in range(floors):
        wy = 1.4 + f * 2.4
        if wy > h - 0.7:
            break
        for k, wx in enumerate((-w * 0.26, w * 0.26)):
            on = lit and ((f + k) % 3 == 0)
            parts.append({"kind": "box", "size": (0.7, 1.0, 0.12),
                          "color": win_lit if on else win_dead,
                          "pos": (wx, wy, d / 2 + 0.02),
                          "emissive": (0.42, 0.34, 0.18) if on else (0.0, 0.0, 0.0)})
            parts.append({"kind": "box", "size": (0.12, 1.0, 0.7),
                          "color": win_lit if on else win_dead,
                          "pos": (w / 2 + 0.02, wy, wx * 0.6),
                          "emissive": (0.42, 0.34, 0.18) if on else (0.0, 0.0, 0.0)})
    s.composite(name, parts, pos=pos)


def build_city_of_destruction():
    s = Scene("city_of_destruction")
    # Cold, oppressive palette — a doomed city under a leaden sky.
    cold = (0.20, 0.22, 0.26)
    s.ground("ENV_City_Ground", (44, 74), cold)
    _road(s, "ENV_City_Road_Main", 60, -2, 6, (0.30, 0.30, 0.33),
          tex="cobble", tile=2.6)
    s.box("ENV_City_TownSquare", (14, 0.1, 14), (0.34, 0.34, 0.37),
          (0, 0.05, 12), tex="cobble", tile=3.0, bevel=False)
    _road(s, "ENV_City_OuterRoad", 16, -27, 5, (0.28, 0.28, 0.31),
          tex="cobble", tile=1.6)

    cwall = (0.34, 0.37, 0.42)   # cold grey-blue masonry
    croof = (0.23, 0.24, 0.28)
    _cottage(s, "PROP_PlayerHouse", (-7, 0, 6), (5, 3.2, 5),
             (0.40, 0.41, 0.45), (0.28, 0.24, 0.24))
    # Multi-storey city blocks lining the streets (not village huts) — taller,
    # brick, flat-parapet roofs, window rows mostly dark in the doomed city.
    _urban_building(s, "PROP_House_01", (9, 0, 8), (5.0, 9.0, 5.0))
    _urban_building(s, "PROP_House_02", (10, 0, -2), (4.6, 11.0, 4.6))
    _urban_building(s, "PROP_House_03", (-10, 0, -4), (4.8, 8.0, 4.8), pitched=True)
    _urban_building(s, "PROP_House_04", (12, 0, 14), (4.6, 10.0, 4.6))
    _urban_building(s, "PROP_House_05", (-12, 0, 12), (4.6, 7.5, 4.6), pitched=True)
    _urban_building(s, "PROP_House_06", (11, 0, -10), (5.0, 12.0, 5.0))
    # Denser, darker, abandoned tenements pressing in on the streets.
    _urban_building(s, "PROP_House_07", (-13.5, 0, 2), (4.4, 9.5, 4.4), lit=False)
    _urban_building(s, "PROP_House_08", (15, 0, 5), (4.2, 7.0, 4.2), lit=False)
    _urban_building(s, "PROP_House_09", (-9, 0, 17), (4.4, 8.5, 4.4), lit=False)
    _urban_building(s, "PROP_House_10", (6.5, 0, -7), (4.4, 10.5, 4.4), lit=False)
    _urban_building(s, "PROP_House_11", (-15.5, 0, -8), (4.4, 8.0, 4.4), lit=False)
    # Tall ruined towers rising over the rooftops — a real city skyline.
    _urban_building(s, "PROP_CityTower_01", (-16.5, 0, 9), (3.6, 15.0, 3.6), lit=False)
    _urban_building(s, "PROP_CityTower_02", (16.5, 0, 16), (4.0, 17.0, 4.0), lit=True)
    _urban_building(s, "PROP_CityTower_03", (-7, 0, -9), (3.4, 14.0, 3.4), lit=False, pitched=True)

    s.composite("PROP_Book", [
        {"kind": "box", "size": (0.6, 0.9, 0.6), "color": (0.3, 0.22, 0.16),
         "pos": (0, 0.45, 0)},
        {"kind": "box", "size": (0.7, 0.12, 0.5), "color": (0.85, 0.8, 0.7),
         "pos": (0, 0.96, 0), "emissive": (0.2, 0.18, 0.12)},
    ], pos=(1.4, 0, 4))

    s.composite("PROP_CityGate", [
        {"kind": "box", "size": (2, 6, 2), "color": (0.5, 0.49, 0.46),
         "pos": (-4, 3, 0), "tex": "stone", "tile": 1.4},
        {"kind": "box", "size": (2, 6, 2), "color": (0.5, 0.49, 0.46),
         "pos": (4, 3, 0), "tex": "stone", "tile": 1.4},
        {"kind": "box", "size": (10.5, 1.2, 1.6), "color": (0.46, 0.44, 0.40),
         "pos": (0, 6.4, 0), "tex": "stone", "tile": 1.2},
        # keystone + iron-banded posts + a guttering gate lantern (opening stays clear)
        {"kind": "box", "size": (1.4, 1.1, 1.8), "color": (0.5, 0.48, 0.44),
         "pos": (0, 6.95, 0), "tex": "stone"},
        {"kind": "box", "size": (2.15, 0.28, 2.15), "color": (0.16, 0.15, 0.15),
         "pos": (-4, 1.4, 0), "tex": "wood"},
        {"kind": "box", "size": (2.15, 0.28, 2.15), "color": (0.16, 0.15, 0.15),
         "pos": (4, 1.4, 0), "tex": "wood"},
        {"kind": "box", "size": (0.34, 0.8, 0.34), "color": (0.72, 0.52, 0.26),
         "pos": (-2.9, 5.1, 1.0), "emissive": (0.55, 0.32, 0.12)},
    ], pos=(0, 0, -19))

    s.composite("PROP_WarningBell", [
        {"kind": "box", "size": (0.25, 4.0, 0.25), "color": (0.35, 0.3, 0.25),
         "pos": (0, 2.0, 0)},
        {"kind": "cone", "radius": 0.6, "height": 0.9, "color": (0.6, 0.5, 0.25),
         "pos": (0, 4.2, 0), "emissive": (0.15, 0.12, 0.05)},
    ], pos=(6, 0, 2))
    s.box("PROP_Crate_01", (1.0, 1.0, 1.0), (0.42, 0.34, 0.24), (4.5, 0.5, 6))
    s.cylinder("PROP_Barrel_01", 0.6, 1.2, (0.36, 0.28, 0.2), (-4, 0.6, 7))

    # Enclosing cold ramparts — the city hemmed in by its own walls.
    rstone = (0.27, 0.29, 0.34)
    _merl = [{"kind": "box", "size": (1.3, 1.3, 1.8), "color": rstone,
              "pos": (mx, 9.4, 0)} for mx in range(-18, 19, 4)]
    s.composite("ENV_CityWall_Back", [
        {"kind": "box", "size": (40, 9, 1.8), "color": (0.42, 0.44, 0.48),
         "pos": (0, 4.5, 0), "tex": "mossy_stone", "tile": 3.2},
    ] + _merl, pos=(0, 0, -33))
    s.box("ENV_CityWall_Left", (1.8, 8, 60), (0.42, 0.44, 0.48), (-21, 4, 0),
          tex="mossy_stone", tile=3.0)
    s.box("ENV_CityWall_Right", (1.8, 8, 60), (0.42, 0.44, 0.48), (21, 4, 0),
          tex="mossy_stone", tile=3.0)

    # Black smoke pouring up from the burning quarters (rooftop height -> harmless).
    for i, (px, pz) in enumerate([(12, 22), (-11, 24), (4, -24)], start=1):
        s.composite("PROP_SmokeStack_%02d" % i, [
            {"kind": "cylinder", "radius": 1.1, "height": 3.2,
             "color": (0.14, 0.14, 0.16), "pos": (0, 4.6, 0)},
            {"kind": "cone", "radius": 1.7, "height": 4.2,
             "color": (0.12, 0.12, 0.14), "pos": (0, 7.6, 0)},
            {"kind": "sphere", "radius": 1.9, "color": (0.10, 0.10, 0.13),
             "pos": (0.5, 10.6, 0)},
        ], pos=(px, 0, pz))

    # The last chapel still standing in the doomed city.
    _chapel(s, "PROP_Chapel", (-16, 0, -15), rot=(0, 90, 0), kind="ruined")

    # ----- textured detail, market clutter & story props -----
    # cracked dry-earth breaking through the cobbles (thin, non-solid decals)
    for i, (cx, cz, cw) in enumerate([(-6, 14, 3.0), (8, 10, 2.6), (-3, -8, 2.4), (5, 18, 2.2)], start=1):
        s.box("PROP_DryPatch_Cairn_%02d" % i, (cw, 0.05, cw * 0.8), (0.32, 0.28, 0.23),
              (cx, 0.08, cz), tex="dry_earth", tile=1.0, bevel=False)
    # a proclamation board in the square -- the city's official "all is well"
    s.composite("PROP_ProclamationBoard", [
        {"kind": "box", "size": (0.22, 2.4, 0.22), "color": (0.3, 0.24, 0.18), "pos": (-1.0, 1.2, 0), "tex": "wood"},
        {"kind": "box", "size": (0.22, 2.4, 0.22), "color": (0.3, 0.24, 0.18), "pos": (1.0, 1.2, 0), "tex": "wood"},
        {"kind": "box", "size": (2.6, 1.6, 0.12), "color": (0.62, 0.55, 0.4), "pos": (0, 2.0, 0), "tex": "wood", "tile": 0.8},
        {"kind": "box", "size": (2.2, 0.14, 0.14), "color": (0.5, 0.12, 0.1), "pos": (0, 2.5, 0.08), "emissive": (0.18, 0.03, 0.02)},
    ], pos=(6.5, 0, 9))
    # an abandoned market stall, awning sagging
    s.composite("PROP_MarketStall", [
        {"kind": "box", "size": (3.2, 0.18, 2.0), "color": (0.4, 0.3, 0.2), "pos": (0, 1.0, 0), "tex": "wood", "tile": 0.8},
        {"kind": "box", "size": (0.18, 1.0, 0.18), "color": (0.32, 0.24, 0.16), "pos": (-1.4, 0.5, -0.8), "tex": "wood"},
        {"kind": "box", "size": (0.18, 1.0, 0.18), "color": (0.32, 0.24, 0.16), "pos": (1.4, 0.5, -0.8), "tex": "wood"},
        {"kind": "box", "size": (0.18, 1.7, 0.18), "color": (0.32, 0.24, 0.16), "pos": (-1.4, 1.85, 0.8), "tex": "wood"},
        {"kind": "box", "size": (0.18, 1.7, 0.18), "color": (0.32, 0.24, 0.16), "pos": (1.4, 1.85, 0.8), "tex": "wood"},
        {"kind": "box", "size": (3.5, 0.16, 2.5), "color": (0.5, 0.18, 0.16), "pos": (0, 2.55, 0.1), "rot": (8, 0, 0)},
    ], pos=(9.6, 0, 11))
    # a dry well -- the city's water gone
    s.composite("PROP_DryWell", [
        {"kind": "cylinder", "radius": 1.1, "height": 1.3, "color": (0.42, 0.44, 0.48), "pos": (0, 0.65, 0), "tex": "mossy_stone"},
        {"kind": "box", "size": (0.2, 2.2, 0.2), "color": (0.3, 0.24, 0.18), "pos": (-0.9, 1.6, 0), "tex": "wood"},
        {"kind": "box", "size": (0.2, 2.2, 0.2), "color": (0.3, 0.24, 0.18), "pos": (0.9, 1.6, 0), "tex": "wood"},
        {"kind": "box", "size": (2.5, 0.18, 1.3), "color": (0.36, 0.28, 0.2), "pos": (0, 2.75, 0), "tex": "wood", "tile": 0.7},
    ], pos=(-7.6, 0, 15))
    # a broken cart by a frontage (off the central road)
    s.composite("PROP_BrokenCart", [
        {"kind": "box", "size": (2.4, 0.5, 1.2), "color": (0.34, 0.26, 0.18), "pos": (0, 0.7, 0), "tex": "wood", "tile": 0.8},
        {"kind": "cylinder", "radius": 0.7, "height": 0.18, "color": (0.28, 0.22, 0.16), "pos": (-1.0, 0.7, 0.7), "rot": (90, 0, 0), "tex": "wood"},
        {"kind": "cylinder", "radius": 0.7, "height": 0.18, "color": (0.28, 0.22, 0.16), "pos": (-1.0, 0.7, -0.7), "rot": (90, 0, 0), "tex": "wood"},
        {"kind": "box", "size": (0.18, 1.7, 0.18), "color": (0.3, 0.24, 0.18), "pos": (1.3, 1.1, 0), "rot": (0, 0, 24), "tex": "wood"},
    ], pos=(13.8, 0, 2))
    # rubble heaps against the walls (off the path)
    for i, (rx, rz, rr) in enumerate([(16.8, 9, 0.9), (-16.8, 6, 0.8), (14.8, -7, 0.7), (-14.5, 16, 0.7)], start=1):
        s.composite("PROP_Rubble_%02d" % i, [
            {"kind": "sphere", "radius": rr, "color": (0.34, 0.35, 0.39), "pos": (0, rr * 0.5, 0), "tex": "stone"},
            {"kind": "box", "size": (rr, rr * 0.7, rr * 1.2), "color": (0.32, 0.33, 0.37), "pos": (rr * 0.7, rr * 0.35, 0.2), "rot": (0, 20, 12), "tex": "stone"},
        ], pos=(rx, 0, rz))
    # cold guttering street lanterns lining the road (clear of the 6-wide road)
    for i, (lx, lz) in enumerate([(-4.2, 0), (4.2, -8), (-4.2, -15)], start=1):
        s.composite("PROP_StreetLantern_%02d" % i, [
            {"kind": "cylinder", "radius": 0.1, "height": 3.4, "color": (0.22, 0.22, 0.25), "pos": (0, 1.7, 0), "tex": "wood"},
            {"kind": "box", "size": (0.5, 0.6, 0.5), "color": (0.72, 0.56, 0.3), "pos": (0, 3.6, 0), "emissive": (0.5, 0.32, 0.12)},
        ], pos=(lx, 0, lz))
        s.marker("LIGHT_StreetLanternGlow_%02d" % i, (lx, 3.6, lz))
    # a single dead tree clawing at the leaden sky
    s.composite("PROP_DeadTree", [
        {"kind": "cylinder", "radius": 0.35, "height": 4.2, "color": (0.2, 0.17, 0.14), "pos": (0, 2.1, 0), "tex": "bark"},
        {"kind": "cylinder", "radius": 0.12, "height": 2.0, "color": (0.2, 0.17, 0.14), "pos": (0.7, 3.6, 0), "rot": (0, 0, 40), "tex": "bark"},
        {"kind": "cylinder", "radius": 0.12, "height": 1.8, "color": (0.2, 0.17, 0.14), "pos": (-0.6, 3.7, 0.2), "rot": (0, 0, -38), "tex": "bark"},
    ], pos=(-13.5, 0, 19))

    # ----- the burning quarters behind: a layered skyline + fire glow -----
    for i, (bx, bw, bh, bz) in enumerate([(-14, 5, 9, 41), (-7, 4, 12, 44), (0, 6, 10, 42),
                                          (7, 4, 13, 45), (15, 5, 8, 41)], start=1):
        s.box("PROP_DistantTower_Silhouette_%02d" % i, (bw, bh, 1.5), (0.10, 0.10, 0.13),
              (bx, bh / 2, bz), bevel=False)
    s.box("PROP_FireWall_Glow", (46, 16, 1.0), (0.9, 0.4, 0.18), (0, 8, 47),
          emissive=(0.85, 0.32, 0.10), bevel=False)
    for i, (ex, ez) in enumerate([(-8, 38), (4, 39), (12, 37)], start=1):
        s.marker("VFX_EmberField_%02d" % i, (ex, 5, ez))

    # ----- cinematic atmosphere markers (read by the art / VFX systems) -----
    s.marker("VFX_SmokeColumn_03", (4, 0, -24))
    s.marker("VFX_AshFall_01", (0, 11, 6))
    s.marker("VFX_AshFall_02", (-8, 11, 0))
    s.marker("VFX_GroundFog_01", (0, 0.6, 2))
    s.marker("VFX_GroundFog_02", (6, 0.6, -12))
    s.marker("VFX_GodRay_01", (-4, 9, 2), rot=(20, 0, 8))
    s.marker("VFX_GodRay_02", (8, 9, -6), rot=(20, 0, -8))
    s.marker("LIGHT_FireGlowWarm", (0, 7, 40))

    s.marker("NPC_Wife", (-3.0, 0, 5.0))
    s.marker("NPC_Children", (-3.8, 0, 5.6))
    s.marker("NPC_Evangelist", (0, 0, -4))
    s.marker("NPC_Obstinate", (3, 0, -13))
    s.marker("NPC_Pliable", (-3, 0, -13))

    s.zone("TRIGGER_ReadBook", (3, 3, 3), (1.4, 1.5, 4))
    s.zone("TRIGGER_ObstinateConfrontation", (8, 3, 4), (3, 1.5, -13))
    s.zone("TRIGGER_PliableJoin", (8, 3, 4), (-3, 1.5, -13))
    s.zone("TRIGGER_ProclamationRead", (3.5, 3, 3.5), (6.5, 1.5, 9))
    s.zone("TRIGGER_Exit_WildernessRoad", (11, 4, 2), (0, 1.5, -21))

    s.marker("VFX_SmokeColumn_01", (12, 0, 22))
    s.marker("VFX_SmokeColumn_02", (-11, 0, 24))
    s.marker("VFX_DistantRedGlow", (0, 6, 30))
    s.marker("LIGHT_DistantWarningRed", (0, 6, 28))
    s.marker("LIGHT_CityDimMain", (0, 14, 6))
    s.marker("CAM_CityOverview", (0, 14, 24), rot=(-32, 0, 0))
    s.marker("CAM_BookCloseup", (1.4, 1.6, 6), rot=(-12, 180, 0))
    s.marker("CAM_CityGateExit", (0, 4, -10), rot=(-6, 180, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 8))
    return s


# ===========================================================================
# CHAPTER 2 - Wilderness Road
# ===========================================================================
def build_wilderness_road():
    s = Scene("wilderness_road")
    dry = (0.44, 0.39, 0.30)
    s.ground("ENV_Wilderness_Ground", (52, 116), dry)

    # A worn road that doglegs gently through the waste and tips down into the
    # lowland (the Slough) at the far end. forward = -Z.
    s.box("ENV_Wilderness_NarrowRoad", (4.4, 0.12, 60), (0.50, 0.44, 0.34),
          (1.2, 0.06, 12), rot=(0, 5, 0))
    s.box("ENV_Wilderness_RoadBend", (4.0, 0.12, 34), (0.49, 0.43, 0.33),
          (-1.6, 0.06, -22), rot=(0, -7, 0))
    s.box("ENV_Wilderness_RoadSlope", (5.0, 0.12, 14), (0.46, 0.40, 0.30),
          (0, 0.04, -40))

    # Low earth berms draw the eye down the road without walling it in.
    s.box("PROP_Berm_Left", (3.0, 1.1, 72), (0.40, 0.35, 0.27), (12, 0.5, 2))
    s.box("PROP_Berm_Right", (3.0, 1.0, 72), (0.40, 0.35, 0.27), (-12, 0.5, 2))

    # The City of Destruction smouldering behind you -- a broken skyline you keep
    # leaving (behind the spawn, +Z; framed by CAM_CityBehindView).
    s.composite("PROP_CityBackdrop", [
        {"kind": "box", "size": (6, 9, 3), "color": (0.18, 0.13, 0.13), "pos": (-11, 4.5, 0)},
        {"kind": "box", "size": (5, 13, 3), "color": (0.16, 0.12, 0.12), "pos": (-4, 6.5, 0)},
        {"kind": "box", "size": (4, 7, 3), "color": (0.17, 0.12, 0.12), "pos": (3, 3.5, 0)},
        {"kind": "box", "size": (6, 11, 3), "color": (0.15, 0.11, 0.11), "pos": (10, 5.5, 0)},
        {"kind": "box", "size": (3, 5, 3), "color": (0.19, 0.13, 0.12), "pos": (16, 2.5, 0)},
        {"kind": "box", "size": (42, 1.4, 1.0), "color": (0.5, 0.18, 0.10),
         "pos": (0, 0.7, 1.6), "emissive": (0.55, 0.16, 0.05)},
    ], pos=(0, 0, 52))

    # The little light ahead -- the goal you fix your eyes on.
    s.composite("PROP_DistantLightMarker", [
        {"kind": "cone", "radius": 1.3, "height": 2.6, "color": (1.0, 0.93, 0.7),
         "pos": (0, 5, 0), "emissive": (0.95, 0.86, 0.6)},
        {"kind": "sphere", "radius": 1.6, "color": (1.0, 0.95, 0.78),
         "pos": (0, 7.4, 0), "emissive": (0.95, 0.88, 0.62)},
    ], pos=(0, 0, -46))

    # A leaning signpost: the way is marked even out here.
    s.composite("PROP_Signpost_WicketGate", [
        {"kind": "box", "size": (0.18, 2.4, 0.18), "color": (0.34, 0.26, 0.18),
         "pos": (0, 1.2, 0), "rot": (0, 0, 8)},
        {"kind": "box", "size": (1.9, 0.6, 0.12), "color": (0.55, 0.46, 0.32),
         "pos": (0.5, 2.1, 0), "rot": (0, 0, 8)},
    ], pos=(-3.4, 0, 13))

    # A worn wayside stone -- pause here and feel the burden's weight (interactable).
    s.composite("PROP_WaysideStone", [
        {"kind": "box", "size": (1.4, 1.0, 1.1), "color": (0.52, 0.49, 0.44), "pos": (0, 0.5, 0)},
        {"kind": "box", "size": (0.9, 0.5, 0.7), "color": (0.48, 0.45, 0.40), "pos": (0.2, 1.1, 0.1)},
    ], pos=(3.6, 0, 8))

    # (No chapel here — the Wilderness Road is meant to be barren and austere.)

    # Rocks, dead trees, broken fence, dry brush -- the parched in-between land.
    s.composite("PROP_RockCluster_01", [
        {"kind": "box", "size": (1.6, 1.2, 1.4), "color": (0.5, 0.47, 0.42), "pos": (0, 0.6, 0)},
        {"kind": "sphere", "radius": 0.82, "color": (0.52, 0.49, 0.44), "pos": (1.0, 0.55, 0.4)},
    ], pos=(8, 0, 2))
    s.composite("PROP_RockCluster_02", [
        {"kind": "box", "size": (1.4, 1.0, 1.2), "color": (0.5, 0.47, 0.42), "pos": (0, 0.5, 0)},
    ], pos=(-9, 0, -12))
    s.composite("PROP_RockCluster_03", [
        {"kind": "box", "size": (1.2, 0.9, 1.1), "color": (0.49, 0.46, 0.41), "pos": (0, 0.45, 0)},
        {"kind": "box", "size": (0.8, 0.6, 0.7), "color": (0.45, 0.42, 0.37), "pos": (-0.7, 0.3, 0.3)},
    ], pos=(6, 0, -28))
    s.composite("PROP_DeadTree_01", [
        {"kind": "cylinder", "radius": 0.3, "height": 4.0,
         "color": (0.3, 0.24, 0.18), "pos": (0, 2.0, 0)},
        {"kind": "box", "size": (2.4, 0.2, 0.2), "color": (0.3, 0.24, 0.18),
         "pos": (0.4, 3.4, 0), "rot": (0, 0, 28)},
    ], pos=(7, 0, -20))
    s.composite("PROP_DeadTree_02", [
        {"kind": "cylinder", "radius": 0.28, "height": 3.4,
         "color": (0.3, 0.24, 0.18), "pos": (0, 1.7, 0)},
    ], pos=(-8, 0, 20))
    s.composite("PROP_DeadTree_03", [
        {"kind": "cylinder", "radius": 0.26, "height": 3.0,
         "color": (0.29, 0.23, 0.17), "pos": (0, 1.5, 0)},
        {"kind": "box", "size": (1.6, 0.16, 0.16), "color": (0.29, 0.23, 0.17),
         "pos": (-0.5, 2.6, 0), "rot": (0, 0, -22)},
    ], pos=(-6, 0, -30))
    s.composite("PROP_BrokenFence_01", [
        {"kind": "box", "size": (0.2, 1.0, 0.2), "color": (0.4, 0.32, 0.22),
         "pos": (-1.2, 0.5, 0)},
        {"kind": "box", "size": (0.2, 1.0, 0.2), "color": (0.4, 0.32, 0.22),
         "pos": (1.2, 0.5, 0)},
        {"kind": "box", "size": (3.0, 0.16, 0.16), "color": (0.42, 0.34, 0.24),
         "pos": (0, 0.8, 0), "rot": (0, 0, 6)},
    ], pos=(5, 0, 30))
    s.composite("PROP_DryBrush_01", [
        {"kind": "box", "size": (0.5, 0.5, 0.5), "color": (0.46, 0.44, 0.28), "pos": (0, 0.25, 0)},
        {"kind": "box", "size": (0.3, 0.4, 0.3), "color": (0.44, 0.42, 0.26), "pos": (0.4, 0.2, 0.2)},
    ], pos=(-4, 0, 0))
    s.composite("PROP_DryBrush_02", [
        {"kind": "box", "size": (0.5, 0.4, 0.5), "color": (0.46, 0.44, 0.28), "pos": (0, 0.2, 0)},
    ], pos=(4.5, 0, -8))

    # --- 精装修: richer wilderness dressing (decor; non-blocking) ---
    for i, (bx, bz, br) in enumerate([(10, 6, 1.2), (-11, -4, 1.0), (9, -18, 0.9),
                                      (-7, 9, 0.8), (8, 24, 1.1)], start=1):
        s.sphere("PROP_Boulder_%02d" % i, br, (0.5, 0.47, 0.42), (bx, br * 0.55, bz))
    # Dry grass tufts scattered along the verges.
    for i, (gx, gz) in enumerate([(3.2, 4), (-3.4, -2), (5, -14), (-5, 16),
                                  (2.6, -26), (-4, 28), (4, 12), (-2.8, -34)], start=1):
        s.composite("PROP_GrassTuft_%02d" % i, [
            {"kind": "cone", "radius": 0.16, "height": 0.7, "color": (0.56, 0.52, 0.32),
             "pos": (dx * 0.16, 0.33, dz * 0.16)}
            for dx, dz in ((-1, 0), (0, 0), (1, 0), (0, 1), (0, -1))], pos=(gx, 0, gz))
    # A wooden waymark cross + stone cairns marking the narrow way.
    s.composite("PROP_Waymark", [
        {"kind": "cylinder", "radius": 0.12, "height": 2.6, "color": (0.36, 0.28, 0.2), "pos": (0, 1.3, 0)},
        {"kind": "box", "size": (1.1, 0.18, 0.18), "color": (0.36, 0.28, 0.2), "pos": (0, 2.1, 0)},
    ], pos=(3.6, 0, -2))
    for i, (cx, cz) in enumerate([(-2.8, 18), (2.6, -30)], start=1):
        s.composite("PROP_Cairn_%02d" % i, [
            {"kind": "sphere", "radius": 0.42, "color": (0.5, 0.47, 0.42), "pos": (0, 0.36, 0)},
            {"kind": "sphere", "radius": 0.3, "color": (0.52, 0.49, 0.44), "pos": (0.05, 0.86, 0)},
            {"kind": "sphere", "radius": 0.2, "color": (0.5, 0.47, 0.42), "pos": (-0.03, 1.22, 0)},
        ], pos=(cx, 0, cz))
    # Hardier green shrubs as the gate-light nears (hope returning to the land).
    for i, (sx2, sz2) in enumerate([(-6, -36), (6, -40), (-3, -44)], start=1):
        s.composite("PROP_GreenBush_%02d" % i, [
            {"kind": "sphere", "radius": 0.72, "color": (0.32, 0.46, 0.28), "pos": (0, 0.5, 0)},
            {"kind": "sphere", "radius": 0.5, "color": (0.35, 0.5, 0.3), "pos": (0.4, 0.7, 0.2)},
        ], pos=(sx2, 0, sz2))
    # Two crows on the broken fence (small, non-solid).
    for i, (kx, kz) in enumerate([(5.3, 30), (4.7, 29.5)], start=1):
        s.composite("PROP_Crow_%02d" % i, [
            {"kind": "sphere", "radius": 0.16, "color": (0.08, 0.08, 0.1), "pos": (0, 0, 0)},
            {"kind": "sphere", "radius": 0.1, "color": (0.08, 0.08, 0.1), "pos": (0, 0.12, 0.12)},
        ], pos=(kx, 1.05, kz))
    # A low ridge line on the far horizon (backdrop).
    s.composite("PROP_DistantRidge", [
        {"kind": "pyramid", "size": (24, 9), "height": 7, "color": (0.3, 0.31, 0.38), "pos": (rx, 3.5, 0)}
        for rx in (-22, -6, 12, 28)], pos=(0, 0, -58))

    # --- NPCs & story beats (travel order: spawn +Z -> exit -Z) ---
    # 1. Obstinate catches up and makes his last argument, then turns back.
    s.zone("TRIGGER_ObstinateReturns", (9, 3, 3), (1.0, 1.5, 35))
    s.marker("NPC_Obstinate", (2.2, 0, 32))
    # 2. Pliable, full of shallow excitement, asks about the glory ahead.
    s.zone("TRIGGER_PliableRoadDialogue", (9, 3, 3), (0.0, 1.5, 27))
    s.marker("NPC_Pliable", (-2.4, 0, 23))
    # 3. (PROP_WaysideStone above) the burden's weight -- a chosen pause.
    # 4. The voices of the old life follow on the wind.
    s.zone("TRIGGER_CityVoices", (10, 3, 4), (-1.0, 1.5, -6))
    # 5. At the brink of the lowland: fix your eyes on the little light.
    s.zone("TRIGGER_FixEyesOnLight", (9, 3, 3), (0, 1.5, -34))
    s.zone("TRIGGER_Exit_SloughOfDespond", (10, 4, 2), (0, 1.5, -44))

    # --- lights / vfx / cameras / spawn ---
    s.marker("VFX_WindDust_01", (0, 1.5, 0))
    s.marker("VFX_DistantLightGlow", (0, 5, -46))
    s.marker("VFX_CityEmberSmoke", (0, 2, 50))
    s.marker("LIGHT_DistantGateGlow", (0, 5, -46))
    s.marker("LIGHT_CityEmberRed", (0, 5, 49))
    s.marker("LIGHT_WildernessMain", (0, 16, 4))
    s.marker("CAM_WildernessOverview", (0, 12, 28), rot=(-28, 0, 0))
    s.marker("CAM_CityBehindView", (0, 6, -2), rot=(-6, 180, 0))
    s.marker("CAM_SloughReveal", (0, 6, -30), rot=(-14, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 40))
    return s


# ===========================================================================
# CHAPTER 3 - Slough of Despond
# ===========================================================================
def build_slough_of_despond():
    s = Scene("slough_of_despond")
    # Murkier, colder mire — heavier and more hopeless underfoot.
    # Paler, drier moor around the mire so the dark wet bog reads with strong
    # contrast (the mud was previously the same tone as the ground = invisible).
    s.ground("ENV_Slough_Ground", (40, 96), (0.40, 0.38, 0.31))
    # The mire bed: RAISED to just under the stone path, widened to fill both
    # sides, and made a DARK, wet brown-black so it clearly reads as a swamp
    # against the pale moor and the grey safe path.
    s.box("ENV_Slough_MudBasin", (30, 0.34, 56), (0.16, 0.16, 0.11), (0, 0.0, -18),
          tex="mud", tile=3.0, roughness=0.5)
    # The deep despair bog at the centre: a near-black sheet of standing water,
    # proud of the mud so it reads as a wide, drowning pool.
    s.box("ENV_Slough_DeepBog_WaterSurface", (18, 0.12, 30), (0.07, 0.09, 0.08),
          (0, 0.19, -26), tex="mud", tile=2.0, roughness=0.32, metallic=0.1,
          emissive=(0.015, 0.02, 0.018), bevel=False)
    s.box("ENV_Slough_SafeStonePath", (3, 0.2, 60), (0.5, 0.5, 0.55),
          (0, 0.08, -10))
    s.box("ENV_Slough_ExitSlope", (10, 0.12, 10), (0.34, 0.36, 0.3), (0, 0.05, -48))

    s.composite("PROP_BrokenPlank_01", [
        {"kind": "box", "size": (2.6, 0.12, 0.5), "color": (0.4, 0.32, 0.22),
         "pos": (0, 0.1, 0), "rot": (0, 18, 0)},
    ], pos=(3, 0, -2))
    s.composite("PROP_BrokenPlank_02", [
        {"kind": "box", "size": (2.2, 0.12, 0.5), "color": (0.38, 0.3, 0.2),
         "pos": (0, 0.1, 0), "rot": (0, -25, 0)},
    ], pos=(-4, 0, -22))
    s.composite("PROP_DeadReeds_01", [
        {"kind": "box", "size": (0.06, 1.6, 0.06), "color": (0.4, 0.42, 0.3),
         "pos": (x * 0.2, 0.8, 0)} for x in range(-3, 4)
    ], pos=(6, 0, -8))
    s.composite("PROP_DeadReeds_02", [
        {"kind": "box", "size": (0.06, 1.4, 0.06), "color": (0.4, 0.42, 0.3),
         "pos": (x * 0.2, 0.7, 0)} for x in range(-3, 4)
    ], pos=(-7, 0, -28))

    s.composite("PROP_PromiseStone_Hope_01", [
        {"kind": "box", "size": (0.7, 0.9, 0.3), "color": (0.85, 0.82, 0.55),
         "pos": (0, 0.45, 0), "emissive": (0.5, 0.46, 0.3)}], pos=(-6, 0, -6))
    s.composite("PROP_PromiseStone_Faith_01", [
        {"kind": "box", "size": (0.7, 0.9, 0.3), "color": (0.8, 0.84, 0.7),
         "pos": (0, 0.45, 0), "emissive": (0.45, 0.5, 0.4)}], pos=(6, 0, -16))
    s.composite("PROP_PromiseStone_Perseverance_01", [
        {"kind": "box", "size": (0.7, 0.9, 0.3), "color": (0.78, 0.78, 0.6),
         "pos": (0, 0.45, 0), "emissive": (0.45, 0.45, 0.3)}], pos=(0, 0, -26))

    # --- 精装修: deeper, sodden mire dressing ---
    for i, (rx, rz) in enumerate([(5, -4), (-6, -18), (7, -30), (-5, -40)], start=3):
        s.composite("PROP_DeadReeds_%02d" % i, [
            {"kind": "box", "size": (0.05, 1.2 + (k % 3) * 0.25, 0.05),
             "color": (0.38, 0.4, 0.28), "pos": (k * 0.16 - 0.4, 0.65, 0)}
            for k in range(6)], pos=(rx, 0, rz))
    for i, (lx, lz, la) in enumerate([(-8, -10, 22), (8, -34, -16)], start=1):
        s.composite("PROP_SunkLog_%02d" % i, [
            {"kind": "cylinder", "radius": 0.3, "height": 3.2, "color": (0.26, 0.22, 0.16),
             "pos": (0, 0.18, 0), "rot": (0, la, 92)}], pos=(lx, 0, lz))
    s.composite("PROP_BrokenWheelFoliage", [
        {"kind": "torus", "ring_r": 0.7, "tube_r": 0.1, "color": (0.3, 0.25, 0.18),
         "pos": (0, 0.5, 0), "rot": (0, 0, 78)}], pos=(-9, 0, 1))
    for i, (mx, mz, mr) in enumerate([(3, -10, 0.5), (-4, -34, 0.45), (6, -22, 0.4)], start=1):
        s.composite("PROP_MireFoliage_%02d" % i, [
            {"kind": "sphere", "radius": mr, "color": (0.3, 0.34, 0.28), "pos": (0, mr * 0.35, 0)}], pos=(mx, 0, mz))

    # Half-sunken chapel adrift in the mire: nave swallowed by the bog, only the
    # weathered roof and the cross standing above the muck -- "out of the depths
    # I cry to you" (Ps 130). A landmark of hope you cannot quite reach while
    # struggling, not a save point; named with the 'Silhouette' skip-token so it
    # stays non-solid and off the safe stone path.
    _chapel(s, "PROP_SunkenChapel_Silhouette", (-9.5, -4.1, -19), rot=(0, 16, 0), kind="ruined")
    s.marker("VFX_SunkenChapelCrossGlow", (-9.5, 7.0, -19))
    s.marker("LIGHT_SunkenChapelPrayerGlow", (-9.5, 6.4, -19))

    s.marker("NPC_Pliable", (-2, 0, 2))
    s.marker("NPC_Help", (0, 0, -38))

    s.zone("COL_MudZone_Shallow_01", (18, 2, 16), (0, 1, -6),
           color=(0.3, 0.32, 0.26, 0.6))
    s.zone("COL_MudZone_Shallow_02", (12, 2, 8), (-7, 1, -14),
           color=(0.3, 0.32, 0.26, 0.6))
    s.zone("COL_MudZone_Deep_01", (20, 2, 14), (0, 1, -32),
           color=(0.18, 0.22, 0.18, 0.78))
    s.zone("COL_MudZone_Deep_02", (10, 2, 8), (7, 1, -24),
           color=(0.18, 0.22, 0.18, 0.78))
    s.zone("COL_FalseGround_01", (4, 0.6, 4), (4, 0.2, -20),
           color=(0.32, 0.34, 0.28, 0.5))

    s.zone("TRIGGER_PliableLeaves", (20, 4, 2), (0, 1.5, -12))
    s.zone("TRIGGER_HelpAppears", (16, 4, 3), (0, 1.5, -36))
    s.zone("TRIGGER_Exit_WicketGate", (20, 4, 2), (0, 1.5, -50))

    s.marker("VFX_FogVolume_Main", (0, 1.5, -18))
    s.marker("VFX_MudBubbles_01", (0, 0.2, -6))
    s.marker("VFX_MudBubbles_02", (0, 0.2, -32))
    s.marker("VFX_PromiseGlow_01", (-6, 0.6, -6))
    s.marker("LIGHT_SloughDimMain", (0, 14, -6))
    s.marker("LIGHT_PromiseStoneGlow_01", (-6, 1.2, -6))
    s.marker("LIGHT_PromiseStoneGlow_02", (6, 1.2, -16))
    s.marker("CAM_SloughOverview", (0, 12, 18), rot=(-30, 0, 0))
    s.marker("CAM_PliableLeaves", (6, 3, -8), rot=(-10, 200, 0))
    s.marker("CAM_HelpAppears", (5, 3, -34), rot=(-10, 180, 0))
    s.marker("CAM_ExitReveal", (0, 5, -44), rot=(-14, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 10))
    return s


# ===========================================================================
# CHAPTER 4 - Wicket Gate
# ===========================================================================
def build_wicket_gate():
    s = Scene("wicket_gate")
    s.ground("ENV_Wicket_Path", (16, 60), (0.26, 0.27, 0.31))
    _road(s, "ENV_Wicket_Path_Strip", 40, 0, 4, (0.3, 0.31, 0.36))
    s.box("ENV_Wicket_CliffEdges", (2.5, 6, 60), (0.14, 0.15, 0.2), (8.5, 3, 0))
    s.box("ENV_Wicket_CliffEdges_R", (2.5, 6, 60), (0.14, 0.15, 0.2), (-8.5, 3, 0))
    s.box("ENV_Wicket_GatePlatform", (10, 0.3, 10), (0.32, 0.3, 0.3),
          (0, 0.1, -9))

    for _nm, _x in (("PROP_StonePost_Left", -2.4), ("PROP_StonePost_Right", 2.4)):
        s.composite(_nm, [
            {"kind": "box", "size": (1.4, 5, 1.4), "color": (0.46, 0.45, 0.43), "pos": (0, 2.5, 0)},
            {"kind": "sphere", "radius": 0.86, "color": (0.5, 0.49, 0.46), "pos": (0, 5.2, 0)},
        ], pos=(_x, 0, -8))
    s.composite("PROP_WicketGate", [
        {"kind": "box", "size": (5.6, 1.0, 1.0), "color": (0.4, 0.34, 0.26),
         "pos": (0, 5.2, 0)},
    ], pos=(0, 0, -8))
    s.box("PROP_GateDoor", (3.0, 4.2, 0.3), (0.62, 0.46, 0.26), (0, 2.1, -8),
          emissive=(0.5, 0.34, 0.12))
    # --- 精装修: warm lanterns at the gate + rubble along the dark cliffs ---
    for i, lx in enumerate((-3.4, 3.4), start=1):
        s.composite("PROP_GateLight_%02d" % i, [
            {"kind": "cylinder", "radius": 0.08, "height": 3.0, "color": (0.3, 0.26, 0.2), "pos": (0, 1.5, 0)},
            {"kind": "sphere", "radius": 0.34, "color": (1.0, 0.82, 0.45), "pos": (0, 3.1, 0), "emissive": (0.95, 0.7, 0.3)},
        ], pos=(lx, 0, -7.5))
    for i, (bx, bz, br) in enumerate([(7.2, 8, 1.0), (-7.2, -2, 0.9), (7.0, -12, 0.8),
                                      (-7.0, 16, 0.7), (6.8, 0, 0.6)], start=1):
        s.composite("PROP_CliffRubble_%02d" % i, [
            {"kind": "sphere", "radius": br, "color": (0.2, 0.21, 0.26), "pos": (0, br * 0.5, 0)},
            {"kind": "sphere", "radius": br * 0.6, "color": (0.22, 0.23, 0.28), "pos": (br * 0.7, br * 0.4, 0.3)},
        ], pos=(bx, 0, bz))

    # Small gate chapel just inside the narrow way -- a place to kneel and give
    # thanks the moment grace draws you through. "Enter through the narrow gate"
    # (Mt 7:13). A real worship/restore point (PROP_Chapel) set on the platform's
    # left, clear of the central road, the exit portal and the arrow zone behind.
    _chapel(s, "PROP_Chapel", (-4.2, 0, -11), rot=(0, 90, 0), kind="gate")
    s.marker("LIGHT_WicketChapelGlow", (-4.2, 3.2, -11))

    s.marker("NPC_Goodwill", (0, 0, -10.5))
    s.zone("TRIGGER_GateKnock", (3.4, 4, 1.6), (0, 2, -8),
           color=(0.9, 0.8, 0.4, 0.25))
    s.zone("TRIGGER_Exit_CrossAndTomb", (8, 4, 2), (0, 1.5, -12))
    s.zone("COL_ArrowPressureZone", (10, 4, 28), (0, 2, 6),
           color=(0.4, 0.2, 0.45, 0.18))

    s.marker("VFX_ArrowEmitter_01", (7, 1.5, 12))
    s.marker("VFX_ArrowEmitter_02", (-7, 1.5, 12))
    s.marker("VFX_GateGlow", (0, 2.2, -8))
    s.marker("LIGHT_GateWarmLight", (0, 3, -9))
    s.marker("LIGHT_WicketDimMain", (0, 12, 6))
    s.marker("CAM_WicketGateOverview", (0, 8, 18), rot=(-30, 0, 0))
    s.marker("CAM_GateKnockCloseup", (0, 2.5, -3), rot=(-8, 180, 0))
    s.marker("CAM_GoodwillPull", (3, 2.5, -10), rot=(-6, 200, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 20))
    return s


# ===========================================================================
# CHAPTER 5 - Cross and Tomb
# ===========================================================================
def build_cross_and_tomb():
    s = Scene("cross_and_tomb")
    # Warm dawn breaking over the hill of grace.
    s.ground("ENV_Cross_Ground", (44, 60), (0.52, 0.5, 0.36))
    # Flat ground -> gentle flush ramp -> low hilltop, all continuously walkable.
    s.ramp("ENV_Cross_HillPath", 8, 12, 1.0, (0.5, 0.46, 0.34), (0, 0, -2))
    s.box("ENV_Cross_Hilltop", (22, 1.0, 16), (0.42, 0.48, 0.36), (0, 0.5, -22))
    s.box("ENV_Cross_TombSlope", (10, 0.1, 7), (0.4, 0.42, 0.34), (-7, 1.05, -18))
    _chapel(s, "PROP_Chapel", (13, 0, 6), rot=(0, -90, 0), kind="calvary")
    # --- 精装修: life returning to the hill of grace (flowers, light, doves) ---
    for i, (fx, fz, fc) in enumerate([(-3, -16, (0.95, 0.85, 0.4)), (3, -14, (0.9, 0.5, 0.6)),
                                      (-5, -22, (0.86, 0.86, 0.95)), (5, -20, (0.95, 0.8, 0.45)),
                                      (-2, -10, (0.9, 0.6, 0.82))], start=1):
        s.composite("PROP_HillFlower_%02d" % i, [
            {"kind": "cone", "radius": 0.12, "height": 0.5, "color": (0.4, 0.55, 0.32), "pos": (0, 0.25, 0)},
            {"kind": "sphere", "radius": 0.22, "color": fc, "pos": (0, 0.62, 0),
             "emissive": tuple(c * 0.4 for c in fc)}], pos=(fx, 1.0, fz))
    for i, (gx, gz) in enumerate([(-2, -18), (2, -16), (0, -24)], start=1):
        s.composite("PROP_DawnGlow_%02d" % i, [
            {"kind": "sphere", "radius": 0.16, "color": (1.0, 0.95, 0.7),
             "pos": (0, 0, 0), "emissive": (0.95, 0.85, 0.5)}], pos=(gx, 2.3, gz))
    for i, (dx2, dz2) in enumerate([(-6.4, -18), (0.6, -16.6)], start=1):
        s.composite("PROP_DoveFoliage_%02d" % i, [
            {"kind": "sphere", "radius": 0.18, "color": (0.95, 0.95, 0.92), "pos": (0, 0, 0)},
            {"kind": "sphere", "radius": 0.1, "color": (0.95, 0.95, 0.92), "pos": (0, 0.12, 0.14)}], pos=(dx2, 2.6, dz2))

    s.composite("PROP_Cross", [
        {"kind": "box", "size": (0.5, 5.0, 0.5), "color": (0.45, 0.34, 0.22),
         "pos": (0, 2.5, 0)},
        {"kind": "box", "size": (2.6, 0.5, 0.5), "color": (0.45, 0.34, 0.22),
         "pos": (0, 3.6, 0)},
    ], pos=(0, 1.0, -20))
    s.composite("PROP_Tomb", [
        {"kind": "box", "size": (4, 3, 4), "color": (0.52, 0.52, 0.54),
         "pos": (0, 1.5, 0)},
        {"kind": "sphere", "radius": 1.3, "color": (0.42, 0.42, 0.44),
         "pos": (2.3, 1.0, 1.8)},
    ], pos=(-7, 1.0, -18))
    s.sphere("PROP_RollingBurden", 0.72, (0.3, 0.26, 0.22), (0, 1.7, -18.5))
    s.marker("PROP_NewGarmentMarker", (0, 1.6, -17))
    s.marker("PROP_ScrollMarker", (0.8, 1.6, -17))
    s.marker("PROP_SealMarker", (-0.8, 1.6, -17))

    s.zone("TRIGGER_CrossEvent", (6, 4, 5), (0, 2.5, -19),
           color=(1.0, 0.92, 0.6, 0.2))
    s.zone("TRIGGER_DemoEnd", (12, 4, 3), (0, 2.0, -26))
    s.marker("PATH_BurdenRoll_Start", (0, 1.6, -18.5))
    s.marker("PATH_BurdenRoll_Mid", (-3.5, 1.4, -18))
    s.marker("PATH_BurdenRoll_End", (-6.5, 1.2, -17.5))

    s.marker("VFX_CrossLight", (0, 6, -14))
    s.marker("VFX_BurdenDust", (-6.5, 2.0, -10.6))
    s.marker("VFX_NewGarmentGlow", (0, 2.6, -10))
    s.marker("VFX_SkyClear", (0, 18, -14))
    s.marker("LIGHT_CrossSunrise", (0, 16, -30))
    s.marker("LIGHT_CrossEventGlow", (0, 4, -13))
    s.marker("CAM_CrossOverview", (0, 8, 8), rot=(-22, 0, 0))
    s.marker("CAM_BurdenFall", (3, 4, -10), rot=(-10, 200, 0))
    s.marker("CAM_TombRoll", (-3, 4, -8), rot=(-12, 150, 0))
    s.marker("CAM_DemoEnd", (0, 6, -22), rot=(-10, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 12))
    return s


# ===========================================================================
# CHAPTER 6 - Interpreter's House (interior)
# ===========================================================================
def build_interpreter_house():
    s = Scene("interpreter_house")
    wood = (0.32, 0.24, 0.18)
    wall = (0.4, 0.34, 0.28)
    s.box("ENV_InterpreterHouse_Floor", (40, 0.4, 40), (0.3, 0.24, 0.2),
          (0, -0.2, 0))
    s.box("ENV_InterpreterHouse_MainHall", (12, 0.1, 12), (0.46, 0.36, 0.26),
          (0, 0.06, 0), tex="wood", tile=2.2)
    s.box("ENV_InterpreterHouse_DustRoom", (10, 0.1, 10), (0.34, 0.3, 0.26),
          (-14, 0.06, 0))
    s.box("ENV_InterpreterHouse_FireRoom", (10, 0.1, 10), (0.4, 0.3, 0.24),
          (14, 0.06, 0))
    s.box("ENV_InterpreterHouse_CageRoom", (10, 0.1, 10), (0.28, 0.28, 0.3),
          (-14, 0.06, -14))
    s.box("ENV_InterpreterHouse_NarrowRoom", (6, 0.1, 14), (0.34, 0.32, 0.26),
          (14, 0.06, -14))
    s.box("ENV_InterpreterHouse_ExitHall", (6, 0.1, 12), (0.34, 0.3, 0.24),
          (0, 0.06, -18))
    # enclosing walls (visual)
    # North wall with a central doorway (the chapter exit) so the way out is open.
    _wall(s, "ENV_InterpreterHouse_WallN_L", (17, 4, 0.4), (-11.5, 2, -22), wall)
    _wall(s, "ENV_InterpreterHouse_WallN_R", (17, 4, 0.4), (11.5, 2, -22), wall)
    _wall(s, "ENV_InterpreterHouse_WallS", (40, 4, 0.4), (0, 2, 14), wall)

    s.marker("NPC_Interpreter", (0, 0, -3))
    # Warm hanging lamps pooling light through the instructive hall.
    s.sphere("PROP_HallLight_01", 0.42, (1.0, 0.92, 0.7), (-4, 3.3, -2), emissive=(0.95, 0.82, 0.5))
    s.sphere("PROP_HallLight_02", 0.42, (1.0, 0.92, 0.7), (4, 3.3, -3), emissive=(0.95, 0.82, 0.5))
    _chapel(s, "PROP_Chapel", (-12, 0, 13), rot=(0, 0, 0), kind="gate")
    # --- 精装修: a warmly furnished house of instruction ---
    for i, (lx, lz) in enumerate([(-6, 6), (6, 6), (-6, -6), (6, -6)], start=3):
        s.composite("PROP_HallLight_%02d" % i, [
            {"kind": "sphere", "radius": 0.22, "color": (1.0, 0.86, 0.55),
             "pos": (0, 0, 0), "emissive": (0.9, 0.72, 0.4)}], pos=(lx, 2.8, lz))
    s.composite("PROP_Bookshelf", [
        {"kind": "box", "size": (3.0, 2.6, 0.6), "color": (0.34, 0.24, 0.16), "pos": (0, 1.3, 0)},
        {"kind": "box", "size": (2.7, 0.12, 0.5), "color": (0.72, 0.62, 0.42), "pos": (0, 0.8, 0.06)},
        {"kind": "box", "size": (2.7, 0.12, 0.5), "color": (0.72, 0.62, 0.42), "pos": (0, 1.5, 0.06)},
        {"kind": "box", "size": (2.7, 0.12, 0.5), "color": (0.72, 0.62, 0.42), "pos": (0, 2.2, 0.06)},
    ], pos=(-5.5, 0, 5.5), rot=(0, 90, 0))
    s.composite("PROP_HallBench", [
        {"kind": "box", "size": (3.0, 0.3, 0.8), "color": (0.4, 0.3, 0.2), "pos": (0, 0.5, 0)},
        {"kind": "box", "size": (3.0, 0.8, 0.18), "color": (0.4, 0.3, 0.2), "pos": (0, 0.9, -0.32)}], pos=(5.5, 0, 8))
    s.composite("PROP_FloorRugFoliage", [
        {"kind": "box", "size": (6, 0.04, 4), "color": (0.5, 0.2, 0.18), "pos": (0, 0.02, 0)}], pos=(0, 0, 0))
    s.cylinder("PROP_DustRoom_Broom", 0.1, 1.8, wood, (-13, 0.9, 1), rot=(0, 0, 18))
    s.cylinder("PROP_DustRoom_WaterBowl", 0.5, 0.3, (0.4, 0.5, 0.6),
               (-15, 0.2, -1), emissive=(0.1, 0.14, 0.18))
    s.marker("PROP_DustRoom_DustCloud", (-14, 1.4, 0))
    s.composite("PROP_FireWall_Fire", [
        {"kind": "cone", "radius": 0.7, "height": 1.6, "color": (1.0, 0.5, 0.2),
         "pos": (0, 0.8, 0), "emissive": (0.9, 0.4, 0.1)}], pos=(13, 0, 0))
    s.box("PROP_FireWall_HiddenOil", (0.3, 2.5, 3), (0.3, 0.28, 0.24),
          (15.4, 1.25, 0))
    s.composite("PROP_CagedMan_Cage", [
        {"kind": "box", "size": (0.1, 2.4, 0.1), "color": (0.2, 0.2, 0.22),
         "pos": (x, 1.2, z)}
        for x in (-1.0, -0.5, 0, 0.5, 1.0) for z in (-1.0, 1.0)
    ], pos=(-14, 0, -14))
    s.box("PROP_CagedMan_Figure", (0.7, 1.6, 0.5), (0.3, 0.3, 0.34),
          (-14, 0.8, -14), emissive=(0.04, 0.04, 0.06))
    s.box("PROP_NarrowRoom_Door_Left", (0.3, 3, 2), (0.4, 0.32, 0.22),
          (12.5, 1.5, -14))
    s.box("PROP_NarrowRoom_Door_Right", (0.3, 3, 2), (0.4, 0.32, 0.22),
          (15.5, 1.5, -14))
    s.composite("PROP_NarrowRoom_CenterLight", [
        {"kind": "cone", "radius": 0.5, "height": 1.4, "color": (1.0, 0.95, 0.7),
         "pos": (0, 0.7, 0), "emissive": (0.9, 0.85, 0.6)}], pos=(14, 0, -20))

    s.zone("TRIGGER_DustRoomStart", (4, 3, 4), (-14, 1.5, 3))
    s.zone("TRIGGER_FireRoomStart", (4, 3, 4), (14, 1.5, 3))
    s.zone("TRIGGER_CageRoomStart", (4, 3, 4), (-14, 1.5, -11))
    s.zone("TRIGGER_NarrowRoomStart", (4, 3, 4), (14, 1.5, -10))
    s.zone("TRIGGER_Exit_HillDifficulty", (6, 4, 3), (0, 1.5, -20))
    s.zone("COL_DustCloudZone", (6, 3, 6), (-14, 1.5, 0), color=(0.5, 0.45, 0.4, 0.4))
    s.zone("COL_CageFearZone", (6, 3, 6), (-14, 1.5, -14), color=(0.3, 0.34, 0.4, 0.4))
    s.zone("COL_FalseDoor_Left", (1, 3, 2), (12.5, 1.5, -14), color=(0.5, 0.3, 0.3, 0.35))
    s.zone("COL_FalseDoor_Right", (1, 3, 2), (15.5, 1.5, -14), color=(0.5, 0.3, 0.3, 0.35))

    for nm, pos in [("VFX_DustCloud", (-14, 1.4, 0)), ("VFX_FireHiddenGlow", (15, 1.2, 0)),
                    ("VFX_CageColdMist", (-14, 1.0, -14)), ("VFX_NarrowRoomLight", (14, 1.5, -20))]:
        s.marker(nm, pos)
    for nm, pos in [("LIGHT_InterpreterMainWarm", (0, 4, 0)), ("LIGHT_DustRoomDim", (-14, 4, 0)),
                    ("LIGHT_FireRoomGlow", (14, 3, 0)), ("LIGHT_CageRoomCold", (-14, 4, -14))]:
        s.marker(nm, pos)
    for nm, pos, rot in [("CAM_InterpreterHallOverview", (0, 8, 14), (-30, 0, 0)),
                         ("CAM_DustRoom", (-14, 4, 6), (-20, 0, 0)),
                         ("CAM_FireBehindWall", (18, 3, 0), (-6, -90, 0)),
                         ("CAM_CagedMan", (-14, 3, -9), (-10, 0, 0)),
                         ("CAM_NarrowRoom", (14, 3, -8), (-10, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 10))
    return s


# ===========================================================================
# CHAPTER 7 - Hill Difficulty
# ===========================================================================
def build_hill_difficulty():
    s = Scene("hill_difficulty")
    s.ground("ENV_Hill_Base", (54, 76), (0.46, 0.4, 0.3))
    # The true path: one gentle, flush ramp from the fork up to a low summit.
    s.ramp("ENV_Hill_DifficultyPath", 6, 24, 2.0, (0.5, 0.44, 0.32), (0, 0, 2))
    s.box("ENV_Hill_Summit", (26, 2.0, 14), (0.5, 0.46, 0.36), (0, 1.0, -29))
    # The two false paths stay flat -- they lead the pilgrim astray, not up.
    s.box("ENV_Hill_DangerPath", (5, 0.1, 28), (0.42, 0.42, 0.4), (-16, 0.05, -6))
    s.box("ENV_Hill_DestructionPath", (7, 0.1, 28), (0.46, 0.4, 0.34), (16, 0.05, -6))

    _sign(s, "PROP_PathSign_Difficulty", (1.6, 0, 6), (0.7, 0.6, 0.3))
    _sign(s, "PROP_PathSign_Danger", (-13, 0, 6), (0.4, 0.45, 0.55))
    _sign(s, "PROP_PathSign_Destruction", (13, 0, 6), (0.55, 0.45, 0.4))
    s.composite("PROP_ArborBench", [
        {"kind": "box", "size": (2.4, 0.3, 0.9), "color": (0.4, 0.32, 0.2),
         "pos": (0, 0.6, 0)},
        {"kind": "box", "size": (2.4, 0.9, 0.2), "color": (0.4, 0.32, 0.2),
         "pos": (0, 1.0, -0.4)},
    ], pos=(6, 0, 0))
    _chapel(s, "PROP_Chapel", (11, 0, 9), rot=(0, -90, 0), kind="pilgrim")
    # --- 精装修: scree, pines and a wayside spring on the climb ---
    for i, (bx, bz, br) in enumerate([(-4.5, -4, 0.7), (4.5, -10, 0.6), (-4, -18, 0.8), (4.5, -24, 0.65)], start=1):
        s.composite("PROP_Scree_%02d" % i, [
            {"kind": "sphere", "radius": br, "color": (0.5, 0.46, 0.4), "pos": (0, br * 0.5, 0)},
            {"kind": "sphere", "radius": br * 0.6, "color": (0.52, 0.48, 0.42), "pos": (br * 0.6, br * 0.4, 0.2)}], pos=(bx, 0, bz))
    for i, (px, pz, ph) in enumerate([(-9, -2, 4.5), (9, -16, 5.0), (-11, -22, 4.0)], start=1):
        s.composite("PROP_Pine_%02d" % i, [
            {"kind": "cylinder", "radius": 0.22, "height": ph * 0.4, "color": (0.32, 0.24, 0.16), "pos": (0, ph * 0.2, 0)},
            {"kind": "cone", "radius": 1.2, "height": ph * 0.5, "color": (0.2, 0.4, 0.26), "pos": (0, ph * 0.55, 0)},
            {"kind": "cone", "radius": 0.9, "height": ph * 0.42, "color": (0.22, 0.43, 0.28), "pos": (0, ph * 0.8, 0)}], pos=(px, 0, pz))
    s.composite("PROP_WaysideSpring", [
        {"kind": "cylinder", "radius": 0.9, "height": 0.5, "color": (0.45, 0.44, 0.4), "pos": (0, 0.25, 0)},
        {"kind": "cylinder", "radius": 0.7, "height": 0.2, "color": (0.32, 0.5, 0.6), "pos": (0, 0.5, 0),
         "emissive": (0.1, 0.2, 0.26), "metallic": 0.1, "roughness": 0.08}], pos=(8.6, 0, 1))
    s.composite("PROP_SummitMarker", [
        {"kind": "cone", "radius": 0.6, "height": 2.4, "color": (0.9, 0.8, 0.4),
         "pos": (0, 1.2, 0), "emissive": (0.6, 0.55, 0.25)},
        {"kind": "sphere", "radius": 0.7, "color": (1.0, 0.92, 0.6),
         "pos": (0, 2.9, 0), "emissive": (0.92, 0.8, 0.45)},
    ], pos=(0, 2.0, -29))
    s.box("PROP_DistantPalaceSilhouette", (16, 9, 2), (0.3, 0.3, 0.4),
          (0, 12, -46))
    # Boulders strewn beside the climb.
    s.sphere("PROP_HillBoulder_01", 1.1, (0.5, 0.46, 0.4), (-5, 0.6, -8))
    s.sphere("PROP_HillBoulder_02", 0.9, (0.48, 0.45, 0.39), (5, 0.5, -18))

    s.marker("NPC_Timorous", (-11, 0, 2))
    s.marker("NPC_Mistrust", (11, 0, 2))

    s.zone("TRIGGER_PathChoiceFork", (16, 3, 4), (0, 1.5, 6))
    s.zone("TRIGGER_DangerPathReturn", (5, 3, 3), (-16, 1.5, -16))
    s.zone("TRIGGER_DestructionPathCollapse", (7, 3, 3), (16, 1.5, -14))
    s.zone("TRIGGER_ArborRest", (4, 3, 4), (6, 1.5, 0))
    s.zone("TRIGGER_Exit_PalaceBeautiful", (10, 4, 2), (0, 2.5, -34))
    s.zone("COL_FalsePath_Danger", (5, 3, 28), (-16, 1.5, -6), color=(0.3, 0.34, 0.5, 0.35))
    s.zone("COL_FalsePath_Destruction", (7, 3, 28), (16, 1.5, -6), color=(0.5, 0.4, 0.3, 0.35))
    s.zone("COL_SteepSlopeZone_01", (6, 3, 12), (0, 1.0, -4), color=(0.5, 0.45, 0.35, 0.25))
    s.zone("COL_SteepSlopeZone_02", (6, 3, 12), (0, 1.8, -16), color=(0.5, 0.45, 0.35, 0.25))
    s.zone("COL_ArborSleepZone", (5, 3, 5), (6, 1.5, 0), color=(0.4, 0.4, 0.55, 0.4))

    s.marker("VFX_FalsePathShimmer_Danger", (-16, 0.5, -6))
    s.marker("VFX_FalsePathShimmer_Destruction", (16, 0.5, -6))
    s.marker("VFX_SummitLight", (0, 4, -29))
    s.marker("VFX_ArborSleepMist", (6, 1.0, 0))
    s.marker("LIGHT_HillMain", (0, 18, 6))
    s.marker("LIGHT_SummitGold", (0, 4, -29))
    s.marker("CAM_HillForkOverview", (0, 10, 22), rot=(-30, 0, 0))
    s.marker("CAM_HillClimb", (6, 4, -6), rot=(-18, 160, 0))
    s.marker("CAM_ArborRest", (9, 3, 0), rot=(-12, 200, 0))
    s.marker("CAM_SummitReveal", (0, 5, -22), rot=(-12, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 18))
    return s


# ===========================================================================
# CHAPTER 8 - Palace Beautiful
# ===========================================================================
def build_palace_beautiful():
    s = Scene("palace_beautiful")
    stone = (0.55, 0.5, 0.44)
    s.ground("ENV_Palace_Ground", (48, 60), (0.4, 0.42, 0.36))
    s.box("ENV_Palace_GateCourt", (16, 0.1, 12), (0.62, 0.6, 0.56), (0, 0.06, 16),
          tex="marble", tile=2.4)
    s.box("ENV_Palace_MainHall", (18, 0.1, 16), (0.66, 0.64, 0.6), (0, 0.06, 0),
          tex="marble", tile=2.8)
    s.box("ENV_Palace_RestRoom", (10, 0.1, 10), (0.48, 0.44, 0.4), (-15, 0.06, -2))
    s.box("ENV_Palace_ArmorRoom", (10, 0.1, 10), (0.5, 0.46, 0.42), (15, 0.06, -2))
    s.box("ENV_Palace_Balcony", (14, 0.1, 6), (0.46, 0.44, 0.4), (0, 0.06, -16))
    _wall(s, "ENV_Palace_WallBack", (44, 6, 0.5), (0, 3, -20), stone)
    _wall(s, "ENV_Palace_WallL", (0.5, 6, 40), (-23, 3, 0), stone)
    _wall(s, "ENV_Palace_WallR", (0.5, 6, 40), (23, 3, 0), stone)

    _pgcol = [(0.85, 0), (1.0, 0.4), (0.72, 0.9), (0.66, 5.0), (0.9, 5.5), (1.05, 6.0)]
    s.composite("PROP_PalaceGate", [
        {"kind": "lathe", "profile": _pgcol, "color": stone, "pos": (-4, 0, 0)},
        {"kind": "lathe", "profile": _pgcol, "color": stone, "pos": (4, 0, 0)},
        {"kind": "box", "size": (9.4, 1.2, 1.6), "color": (0.5, 0.46, 0.4),
         "pos": (0, 6.4, 0)},
        {"kind": "box", "size": (10.4, 0.6, 1.9), "color": (0.52, 0.48, 0.42),
         "pos": (0, 7.2, 0)},
    ], pos=(0, 0, 22))
    s.composite("PROP_DiningTable", [
        {"kind": "box", "size": (5, 0.3, 1.6), "color": (0.5, 0.38, 0.24),
         "pos": (0, 1.0, 0), "tex": "wood", "tile": 1.2}], pos=(0, 0, 0))
    s.composite("PROP_Bed", [
        {"kind": "box", "size": (2.2, 0.6, 3.6), "color": (0.5, 0.42, 0.4),
         "pos": (0, 0.5, 0)},
        {"kind": "box", "size": (2.2, 0.4, 1.0), "color": (0.7, 0.66, 0.6),
         "pos": (0, 0.9, -1.2)}], pos=(-15, 0, -2))
    s.composite("PROP_ArmorStand", [
        {"kind": "box", "size": (1.2, 1.6, 0.5), "color": (0.6, 0.62, 0.68),
         "pos": (0, 1.4, 0), "emissive": (0.18, 0.2, 0.24),
         "metallic": 0.95, "roughness": 0.3},
        {"kind": "cylinder", "radius": 0.2, "height": 1.0, "color": (0.4, 0.4, 0.42),
         "pos": (0, 0.5, 0)},
        {"kind": "sphere", "radius": 0.33, "color": (0.66, 0.68, 0.74),
         "pos": (0, 2.5, 0), "metallic": 0.95, "roughness": 0.28,
         "emissive": (0.12, 0.13, 0.16)}], pos=(15, 0, -3))
    s.box("PROP_Sword", (0.16, 1.8, 0.16), (0.75, 0.78, 0.85), (13.6, 1.3, -3),
          emissive=(0.2, 0.22, 0.28))
    s.box("PROP_Shield", (1.2, 1.4, 0.2), (0.6, 0.6, 0.68), (16.4, 1.3, -3),
          emissive=(0.15, 0.16, 0.2))
    s.box("PROP_ValleyView", (12, 7, 1.5), (0.2, 0.2, 0.28), (0, 4, -19.5))
    # Warm hearth glow in the rest room + festive pennants on the gate.
    s.sphere("PROP_HearthGlow", 0.6, (1.0, 0.6, 0.3), (-15, 0.8, -5), emissive=(0.95, 0.45, 0.15))
    s.box("PROP_GateBanner_Left", (0.16, 2.2, 1.2), (0.72, 0.2, 0.26), (-4, 8.3, 22), emissive=(0.32, 0.06, 0.08))
    s.box("PROP_GateBanner_Right", (0.16, 2.2, 1.2), (0.72, 0.2, 0.26), (4, 8.3, 22), emissive=(0.32, 0.06, 0.08))
    _chapel(s, "PROP_Chapel", (-11, 0, 15), rot=(0, 0, 0), kind="pilgrim")
    # --- 精装修: a richer noble hall (columns, banners, hearth, urns) ---
    _hcol = [(0.5, 0), (0.6, 0.3), (0.42, 0.6), (0.4, 4.6), (0.56, 5.0), (0.66, 5.4)]
    for i, (cx, cz) in enumerate([(-7, 6), (7, 6), (-7, -6), (7, -6)], start=1):
        s.lathe("PROP_HallColumn_%02d" % i, _hcol, stone, (cx, 0, cz))
    for i, (bx, bz, bc) in enumerate([(-8.6, 2, (0.72, 0.18, 0.2)), (8.6, 2, (0.2, 0.3, 0.72)),
                                      (-8.6, -8, (0.62, 0.5, 0.16))], start=1):
        s.box("PROP_HallBanner_%02d" % i, (0.16, 3.0, 1.4), bc, (bx, 3.0, bz),
              emissive=tuple(c * 0.25 for c in bc))
    s.composite("PROP_HearthFire", [
        {"kind": "cone", "radius": 0.5, "height": 1.2, "color": (1.0, 0.5, 0.2),
         "pos": (0, 0.6, 0), "emissive": (0.95, 0.45, 0.12)}], pos=(-15, 0, -6))
    for i, ux in enumerate((-5, 5), start=1):
        s.lathe("PROP_GardenUrn_%02d" % i,
                [(0.3, 0), (0.5, 0.4), (0.6, 0.8), (0.4, 1.2), (0.5, 1.5), (0.3, 1.7)],
                (0.6, 0.55, 0.45), (ux, 0, 18))

    s.marker("NPC_Watchman", (0, 0, 20))
    s.marker("NPC_Discretion", (-2, 0, 14))
    s.marker("NPC_Prudence", (2, 0, 2))
    s.marker("NPC_Piety", (-3, 0, -2))
    s.marker("NPC_Charity", (3, 0, -4))

    s.zone("TRIGGER_PalaceDoorExamination", (8, 4, 3), (0, 1.5, 15))
    s.zone("TRIGGER_RestAtPalace", (6, 3, 6), (-15, 1.5, -2))
    s.zone("TRIGGER_ReceiveArmor", (6, 3, 6), (15, 1.5, -3))
    s.zone("TRIGGER_Exit_ValleyHumiliation", (10, 4, 2), (0, 1.5, -18))

    s.marker("VFX_HearthWarmth", (0, 1.5, -4))
    s.marker("VFX_ArmorGlow", (15, 1.4, -3))
    s.marker("VFX_BalconyValleyMist", (0, 1.0, -17))
    s.marker("LIGHT_PalaceWarmMain", (0, 5, 0))
    s.marker("LIGHT_ArmorRoomGlow", (15, 4, -3))
    s.marker("CAM_PalaceExterior", (0, 9, 30), rot=(-26, 0, 0))
    s.marker("CAM_DoorExamination", (0, 3, 19), rot=(-6, 180, 0))
    s.marker("CAM_MainHall", (0, 6, 12), rot=(-20, 0, 0))
    s.marker("CAM_ArmorRoom", (15, 3, 3), rot=(-10, 0, 0))
    s.marker("CAM_ValleyReveal", (0, 4, -14), rot=(-10, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 24))
    return s


# ===========================================================================
# CHAPTER 9 - Valley of Humiliation (Apollyon arena)
# ===========================================================================
def build_valley_humiliation():
    s = Scene("valley_humiliation")
    # Darker, scorched battlefield — oppressive and close.
    s.ground("ENV_Humiliation_ValleyFloor", (54, 70), (0.30, 0.27, 0.26))
    s.box("ENV_Humiliation_DescentPath", (8, 0.12, 18), (0.34, 0.32, 0.3), (0, 0.06, 22))
    s.box("ENV_Humiliation_BossArena", (34, 0.1, 34), (0.26, 0.22, 0.22),
          (0, 0.06, -6))
    s.box("ENV_Humiliation_ExitPath", (8, 0.12, 14), (0.36, 0.36, 0.32), (0, 0.06, -30))

    s.composite("PROP_BattleStone_01", [
        {"kind": "box", "size": (2.2, 1.6, 2.0), "color": (0.4, 0.38, 0.36), "pos": (0, 0.8, 0)},
        {"kind": "sphere", "radius": 1.1, "color": (0.42, 0.4, 0.38), "pos": (0.6, 1.2, 0.5)}], pos=(-12, 0, -4))
    s.composite("PROP_BattleStone_02", [
        {"kind": "box", "size": (2.4, 1.8, 2.2), "color": (0.4, 0.38, 0.36), "pos": (0, 0.9, 0)},
        {"kind": "sphere", "radius": 1.25, "color": (0.43, 0.41, 0.39), "pos": (-0.6, 1.4, -0.4)}], pos=(12, 0, -10))
    s.cylinder("PROP_BrokenSpear_01", 0.08, 2.6, (0.4, 0.34, 0.26),
               (-6, 0.5, 2), rot=(0, 0, 70))
    # Brimstone embers smouldering on the field.
    s.sphere("PROP_EmberGlow_01", 0.5, (1.0, 0.3, 0.12), (-8, 0.6, -12), emissive=(0.95, 0.25, 0.05))
    s.sphere("PROP_EmberGlow_02", 0.42, (1.0, 0.35, 0.14), (8, 0.5, -12), emissive=(0.9, 0.28, 0.06))
    _chapel(s, "PROP_Chapel", (13, 0, 18), rot=(0, -90, 0), kind="pilgrim")
    # --- 精装修: more battlefield wreckage ---
    for i, (sx2, sz2, sa) in enumerate([(-8, 2, 60), (9, -6, -50), (-9, -10, 40), (8, 4, 75)], start=2):
        s.cylinder("PROP_BrokenSpear_%02d" % i, 0.07, 2.4, (0.4, 0.34, 0.26), (sx2, 0.4, sz2), rot=(0, 0, sa))
    for i, (dx2, dz2) in enumerate([(-6, -4), (7, -10), (-3, -14)], start=1):
        s.composite("PROP_BrokenShield_%02d" % i, [
            {"kind": "cylinder", "radius": 0.6, "height": 0.12, "color": (0.4, 0.36, 0.3),
             "pos": (0, 0.06, 0), "rot": (90, 0, 20)}], pos=(dx2, 0, dz2))
    for i, (ex, ez) in enumerate([(-10, -10), (10, -8), (0, -14)], start=3):
        s.composite("PROP_EmberGlow_%02d" % i, [
            {"kind": "sphere", "radius": 0.32, "color": (1.0, 0.32, 0.12),
             "pos": (0, 0.4, 0), "emissive": (0.95, 0.25, 0.05)}], pos=(ex, 0, ez))
    s.composite("PROP_FallenBannerFoliage", [
        {"kind": "cylinder", "radius": 0.1, "height": 3.5, "color": (0.3, 0.24, 0.18), "pos": (0, 0.2, 0), "rot": (0, 0, 80)},
        {"kind": "box", "size": (0.12, 1.6, 1.0), "color": (0.5, 0.12, 0.12), "pos": (1.3, 0.3, 0), "rot": (0, 0, 80)}], pos=(-9, 0, 3))
    s.marker("PROP_ArmorLightMarker", (0, 1.2, 14))

    s.marker("NPC_Apollyon", (0, 0, -16))
    s.marker("ENEMY_ApollyonBoss", (0, 0, -16))

    s.zone("TRIGGER_ApollyonIntro", (16, 4, 4), (0, 2, 4))
    s.zone("TRIGGER_BossStart", (16, 4, 4), (0, 2, -2))
    s.zone("TRIGGER_BossVictory", (8, 4, 4), (0, 2, -16))
    s.zone("TRIGGER_Exit_ShadowValley", (8, 4, 2), (0, 1.5, -34))
    s.zone("COL_BossArenaBounds", (34, 6, 34), (0, 3, -6), color=(0.4, 0.2, 0.2, 0.1))
    s.zone("COL_DespairFlameZone", (10, 3, 10), (-8, 1.5, -12), color=(0.5, 0.2, 0.15, 0.4))
    s.zone("COL_ShameFieldZone", (10, 3, 10), (8, 1.5, -12), color=(0.4, 0.2, 0.4, 0.4))

    for nm, pos in [("VFX_ApollyonEntrance", (0, 2, -16)), ("VFX_FearRoarWave", (0, 1.5, -10)),
                    ("VFX_AccusationBolt", (0, 2, -12)), ("VFX_DespairFlame", (-8, 1, -12)),
                    ("VFX_VictoryLight", (0, 4, -16))]:
        s.marker(nm, pos)
    s.marker("LIGHT_HumiliationMain", (0, 16, 8))
    s.marker("LIGHT_BossRed", (0, 8, -16))
    s.marker("LIGHT_VictoryGold", (0, 8, -16))
    s.marker("CAM_ValleyDescent", (0, 8, 26), rot=(-28, 0, 0))
    s.marker("CAM_ApollyonIntro", (0, 3, -8), rot=(-6, 180, 0))
    s.marker("CAM_BossFightWide", (0, 9, 14), rot=(-26, 0, 0))
    s.marker("CAM_BossVictory", (0, 4, -10), rot=(-8, 180, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 26))
    return s


# ===========================================================================
# CHAPTER 10 - Valley of the Shadow of Death
# ===========================================================================
def build_valley_shadow_death():
    s = Scene("valley_shadow_death")
    s.ground("ENV_ShadowValley_Ground", (20, 96), (0.12, 0.12, 0.16))
    s.box("ENV_ShadowValley_NarrowPath", (4, 0.12, 84), (0.18, 0.18, 0.22),
          (0, 0.06, 0))
    s.box("ENV_ShadowValley_LeftWall", (3, 10, 90), (0.08, 0.08, 0.12),
          (7, 5, 0))
    s.box("ENV_ShadowValley_RightWall", (3, 10, 90), (0.08, 0.08, 0.12),
          (-7, 5, 0))
    s.box("ENV_ShadowValley_ExitSlope", (8, 0.12, 12), (0.3, 0.3, 0.34), (0, 0.05, -44))
    # A prayer chapel against the valley wall at the entrance — light before the dark.
    _chapel(s, "PROP_Chapel", (-3.5, 0, 25), rot=(0, 0, 0), kind="ruined")

    for i, z in enumerate((24, 8, -8, -24), start=1):
        s.composite("PROP_FaintPathMarker_%02d" % i, [
            {"kind": "cylinder", "radius": 0.3, "height": 0.5,
             "color": (0.6, 0.62, 0.7), "pos": (0, 0.25, 0),
             "emissive": (0.3, 0.32, 0.4)},
            {"kind": "sphere", "radius": 0.28, "color": (0.72, 0.78, 0.98),
             "pos": (0, 0.72, 0), "emissive": (0.52, 0.58, 0.85)}], pos=(0, 0, z))
    s.composite("PROP_BrokenSkullRock_01", [
        {"kind": "box", "size": (1.2, 1.0, 1.2), "color": (0.3, 0.3, 0.32), "pos": (0, 0.5, 0)},
        {"kind": "sphere", "radius": 0.55, "color": (0.62, 0.6, 0.58), "pos": (0.2, 1.05, 0.1)}], pos=(4, 0, 12))
    s.composite("PROP_DeadBranch_01", [
        {"kind": "cylinder", "radius": 0.12, "height": 2.4,
         "color": (0.2, 0.18, 0.16), "pos": (0, 1.0, 0), "rot": (0, 0, 40)}],
        pos=(-4, 0, -6))
    # --- 精装修: more guiding lights + grim rubble in the dark valley ---
    for i, gz in enumerate([16, 0, -12, -28], start=1):
        s.composite("PROP_PathGlow_%02d" % i, [
            {"kind": "sphere", "radius": 0.2, "color": (0.7, 0.78, 0.98),
             "pos": (0, 0.3, 0), "emissive": (0.5, 0.58, 0.85)}], pos=(0, 0, gz))
    for i, (jx, jz, jr) in enumerate([(5, 8, 0.7), (-5, -4, 0.6), (5.2, -22, 0.65), (-5, -36, 0.55)], start=1):
        s.composite("PROP_JaggedRock_%02d" % i, [
            {"kind": "cone", "radius": jr, "height": jr * 3.0, "color": (0.18, 0.18, 0.22),
             "pos": (0, jr * 1.5, 0)}], pos=(jx, 0, jz))
    s.composite("PROP_FallenPillarFoliage", [
        {"kind": "cylinder", "radius": 0.4, "height": 4.0, "color": (0.22, 0.22, 0.26),
         "pos": (0, 0.4, 0), "rot": (0, 10, 90)}], pos=(4.6, 0, -30))

    s.zone("TRIGGER_PrayerPrompt", (4, 4, 4), (0, 2, 20))
    s.zone("TRIGGER_FalseVoice_Left", (4, 4, 4), (-3, 2, 0))
    s.zone("TRIGGER_FalseVoice_Right", (4, 4, 4), (3, 2, -16))
    s.zone("TRIGGER_ShadowCollapseCheck", (6, 4, 30), (0, 2, -6))
    s.zone("TRIGGER_Exit_VerticalSliceEnd", (8, 4, 2), (0, 1.5, -42))

    s.zone("COL_FearZone_01", (5, 4, 8), (0, 2, 4), color=(0.1, 0.1, 0.2, 0.4))
    s.zone("COL_FearZone_02", (5, 4, 8), (0, 2, -20), color=(0.1, 0.1, 0.2, 0.4))
    s.zone("COL_FalseVoiceZone_Left", (4, 4, 6), (-4, 2, 2), color=(0.2, 0.1, 0.25, 0.4))
    s.zone("COL_FalseVoiceZone_Right", (4, 4, 6), (4, 2, -14), color=(0.2, 0.1, 0.25, 0.4))
    s.zone("COL_NarrowCliffEdge", (1.5, 6, 84), (5.4, 3, 0), color=(0.4, 0.1, 0.1, 0.25))
    s.zone("COL_DarknessDeepZone", (8, 5, 20), (0, 2.5, -2), color=(0.05, 0.05, 0.1, 0.5))

    s.marker("VFX_DarkFog_Main", (0, 2, 0))
    s.marker("VFX_Whisper_Left", (-4, 1.5, 0))
    s.marker("VFX_Whisper_Right", (4, 1.5, -16))
    s.marker("VFX_PrayerLight", (0, 2, 20))
    s.marker("VFX_ExitDawn", (0, 4, -44))
    s.marker("LIGHT_PlayerSmallLight", (0, 2, 28))
    s.marker("LIGHT_PrayerLight", (0, 3, 20))
    s.marker("LIGHT_ExitDawn", (0, 6, -46))
    s.marker("CAM_ShadowValleyEntry", (0, 6, 34), rot=(-20, 0, 0))
    s.marker("CAM_DarkPath", (3, 3, 8), rot=(-8, 160, 0))
    s.marker("CAM_FalseVoice", (3, 2.5, 0), rot=(-6, 200, 0))
    s.marker("CAM_ExitDawnReveal", (0, 5, -40), rot=(-12, 0, 0))
    s.marker("SPAWN_Player_Start", (0, 1, 30))
    return s


# ===========================================================================
# CHAPTER 11 - Vanity Fair
# ===========================================================================
def build_vanity_fair():
    s = Scene("vanity_fair")
    # Warm, gaudy fairground — saturated and inviting on the surface.
    s.ground("ENV_VanityFair_Ground", (50, 70), (0.52, 0.34, 0.28))
    _road(s, "ENV_VanityFair_MainStreet", 60, 0, 6, (0.62, 0.44, 0.32))
    s.box("ENV_VanityFair_MarketSquare", (24, 0.1, 16), (0.64, 0.48, 0.34), (0, 0.06, 6))
    s.box("ENV_VanityFair_TrialSquare", (16, 0.1, 14), (0.56, 0.42, 0.38), (0, 0.06, -14))
    _road(s, "ENV_VanityFair_ExitRoad", 14, -28, 5, (0.5, 0.38, 0.32))

    s.composite("PROP_Stall_Applause", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.8, 0.7, 0.2), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.9, 0.2, 0.3), "pos": (0, 3.0, 0)}], pos=(-8, 0, 8))
    s.composite("PROP_Stall_Comfort", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.6, 0.4, 0.7), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.4, 0.3, 0.7), "pos": (0, 3.0, 0)}], pos=(8, 0, 8))
    s.composite("PROP_Stall_Influence", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.3, 0.7, 0.4), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.2, 0.6, 0.5), "pos": (0, 3.0, 0)}], pos=(0, 0, 12))
    # More stalls crowding the fair (flanking, off the central path).
    s.composite("PROP_Stall_Riches", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.92, 0.5, 0.16), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.95, 0.78, 0.2), "pos": (0, 3.0, 0)},
        {"kind": "sphere", "radius": 0.28, "color": (0.98, 0.85, 0.3), "pos": (0, 3.9, 0), "emissive": (0.5, 0.4, 0.1)}], pos=(-12, 0, 2))
    s.composite("PROP_Stall_Pleasure", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.2, 0.66, 0.7), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.85, 0.25, 0.5), "pos": (0, 3.0, 0)},
        {"kind": "sphere", "radius": 0.28, "color": (0.95, 0.4, 0.6), "pos": (0, 3.9, 0), "emissive": (0.4, 0.12, 0.2)}], pos=(12, 0, 2))
    s.composite("PROP_Stall_Honor", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.7, 0.2, 0.7), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.95, 0.8, 0.25), "pos": (0, 3.0, 0)}], pos=(0, 0, 19))
    s.box("PROP_Banner_Red_01", (0.2, 4.4, 1.7), (0.92, 0.14, 0.18), (-11, 2.7, 2), emissive=(0.45, 0.06, 0.08))
    s.box("PROP_Banner_Gold_01", (0.2, 4.4, 1.7), (0.95, 0.78, 0.18), (11, 2.7, 2), emissive=(0.45, 0.36, 0.06))
    s.box("PROP_Banner_Purple_01", (0.2, 4.0, 1.6), (0.6, 0.16, 0.78), (-4, 2.5, 12), emissive=(0.28, 0.06, 0.36))
    s.box("PROP_Banner_Teal_01", (0.2, 4.0, 1.6), (0.12, 0.7, 0.74), (4, 2.5, 12), emissive=(0.05, 0.32, 0.34))
    s.box("PROP_Banner_Crimson_01", (0.2, 3.6, 1.5), (0.86, 0.1, 0.32), (0, 2.3, 20), emissive=(0.4, 0.05, 0.14))
    s.box("PROP_TrialPlatform", (8, 1.0, 6), (0.5, 0.42, 0.4), (0, 0.5, -14))
    # Crowd figures: a robed body (cylinder) topped with a head (sphere).
    _cparts = [part
               for x in (-1, 0, 1) for z in (0, 1)
               for part in (
                   {"kind": "cylinder", "radius": 0.34, "height": 1.5,
                    "color": (0.42, 0.36, 0.42), "pos": (x * 1.0, 0.75, z * 1.1)},
                   {"kind": "sphere", "radius": 0.26, "color": (0.72, 0.6, 0.52),
                    "pos": (x * 1.0, 1.68, z * 1.1)})]
    s.composite("PROP_CrowdCluster_01", _cparts, pos=(-6, 0, -10))
    s.composite("PROP_CrowdCluster_02", _cparts, pos=(6, 0, -10))
    s.composite("PROP_CrowdCluster_03", _cparts, pos=(-10, 0, 5))
    s.composite("PROP_CrowdCluster_04", _cparts, pos=(10, 0, 6))
    s.composite("PROP_BrokenPilgrimSign", [
        {"kind": "box", "size": (0.2, 1.4, 0.2), "color": (0.4, 0.34, 0.24), "pos": (0, 0.7, 0), "rot": (0, 0, 20)}], pos=(10, 0, 18))
    # ----- a teeming fair: piled goods, merchant shops, and dense crowds -----
    # goods heaped on every named stall counter
    for _gnm, _gp in [("Applause", (-8, 1.3, 9.3)), ("Comfort", (8, 1.3, 9.3)),
                      ("Influence", (0, 1.3, 13.3)), ("Riches", (-12, 1.3, 3.3)),
                      ("Pleasure", (12, 1.3, 3.3)), ("Honor", (0, 1.3, 20.3))]:
        _market_goods(s, "PROP_StallGoods_%s" % _gnm, _gp)
    # merchant shops lining the fair street (solid, set off the central road)
    _shop(s, "PROP_Shop_Silks", (-13.5, 0, 11), awning=(0.7, 0.18, 0.5))
    _shop(s, "PROP_Shop_Goldsmith", (13.5, 0, 11), awning=(0.9, 0.72, 0.2))
    _shop(s, "PROP_Shop_Wines", (-14, 0, 0), awning=(0.55, 0.12, 0.16))
    _shop(s, "PROP_Shop_Relics", (14, 0, 0), awning=(0.4, 0.3, 0.7))
    _shop(s, "PROP_Shop_Trinkets", (-13.5, 0, 18), awning=(0.2, 0.6, 0.6))
    _shop(s, "PROP_Shop_Masks", (13.5, 0, 18), awning=(0.8, 0.4, 0.2))
    # the great press of fairgoers (non-solid 'Crowd' -- the player wades through)
    for _ci, (_cx, _cz, _rw, _cl) in enumerate(
            [(-5, 3, 3, 4), (5, 3, 3, 4), (-7, 15, 3, 4), (7, 15, 3, 4), (0, 17, 2, 5),
             (-4, -4, 3, 4), (4, -4, 3, 4), (0, -6, 2, 4), (-6, -12, 3, 4), (6, -12, 3, 4)], start=5):
        _crowd(s, "PROP_CrowdCluster_%02d" % _ci, (_cx, 0, _cz), rows=_rw, cols=_cl)
    # hawkers' hand-carts of wares dotted through the square
    for _wi, (_wx, _wz) in enumerate([(-3, 8), (3, 8), (-2, 16), (2, -2)], start=1):
        s.composite("PROP_WaresCart_%02d" % _wi, [
            {"kind": "box", "size": (1.8, 0.5, 1.0), "color": (0.42, 0.3, 0.2), "pos": (0, 0.7, 0), "tex": "wood"},
            {"kind": "cylinder", "radius": 0.5, "height": 0.16, "color": (0.3, 0.24, 0.16), "pos": (-0.7, 0.5, 0.6), "rot": (90, 0, 0), "tex": "wood"},
            {"kind": "cylinder", "radius": 0.5, "height": 0.16, "color": (0.3, 0.24, 0.16), "pos": (-0.7, 0.5, -0.6), "rot": (90, 0, 0), "tex": "wood"},
        ], pos=(_wx, 0, _wz))
        _market_goods(s, "PROP_WaresCart_%02d_Goods" % _wi, (_wx, 0.95, _wz))

    # A quiet chapel at the edge of the clamouring fair.
    _chapel(s, "PROP_Chapel", (-16, 0, -4), rot=(0, 90, 0), kind="trial")

    s.marker("NPC_Faithful", (-2, 0, -10))
    s.marker("NPC_Hopeful", (2, 0, -10))
    s.marker("NPC_Merchant_Applause", (-8, 0, 6))
    s.marker("NPC_Merchant_Comfort", (8, 0, 6))
    s.marker("NPC_Merchant_Influence", (0, 0, 10))
    s.marker("NPC_TrialJudge", (0, 1.0, -16))

    s.zone("TRIGGER_EnterVanityFair", (10, 4, 3), (0, 1.5, 20))
    s.zone("TRIGGER_FaithfulTrial", (12, 4, 4), (0, 1.5, -10))
    s.zone("TRIGGER_FaithfulLost", (8, 4, 3), (0, 1.5, -16))
    s.zone("TRIGGER_HopefulJoins", (8, 4, 3), (0, 1.5, -20))
    s.zone("TRIGGER_Exit_DoubtingCastle", (10, 4, 2), (0, 1.5, -30))
    s.zone("COL_VanityApplauseZone", (6, 3, 6), (-8, 1.5, 8), color=(0.8, 0.7, 0.2, 0.3))
    s.zone("COL_ComfortTentZone", (6, 3, 6), (8, 1.5, 8), color=(0.6, 0.4, 0.7, 0.3))
    s.zone("COL_InfluenceStageZone", (6, 3, 6), (0, 1.5, 12), color=(0.3, 0.7, 0.4, 0.3))
    s.zone("COL_CrowdPressureZone", (20, 3, 8), (0, 1.5, -10), color=(0.5, 0.3, 0.3, 0.25))

    for nm, pos in [("VFX_VanityGlitter", (0, 3, 6)), ("VFX_CrowdNoisePulse", (0, 2, -10)),
                    ("VFX_TrialSpotlight", (0, 4, -14)), ("VFX_HopefulJoinLight", (2, 2, -20))]:
        s.marker(nm, pos)
    for nm, pos in [("LIGHT_VanityFairMain", (0, 14, 4)), ("LIGHT_TrialSpotlight", (0, 8, -14)),
                    ("LIGHT_HopefulJoin", (2, 4, -20))]:
        s.marker(nm, pos)
    for nm, pos, rot in [("CAM_VanityEntrance", (0, 8, 30), (-26, 0, 0)),
                         ("CAM_MarketWide", (0, 10, 18), (-30, 0, 0)),
                         ("CAM_TrialScene", (0, 4, -6), (-8, 180, 0)),
                         ("CAM_FaithfulLost", (4, 3, -14), (-8, 200, 0)),
                         ("CAM_HopefulJoins", (4, 3, -18), (-8, 200, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 24))
    return s


# ===========================================================================
# CHAPTER 12 - Doubting Castle
# ===========================================================================
def _battlement_wall(s, name, run, pos, color, axis="x", height=7.5,
                     thick=1.2, merlon=0.9):
    """A curtain wall with a crenellated top (alternating merlons). `axis` is the
    horizontal direction the wall runs along ('x' or 'z'); `run` is its length.
    The rampart blocks the pilgrim; the merlons sit on top out of reach."""
    if axis == "x":
        s.box(name, (run, height, thick), color, (pos[0], height / 2.0, pos[2]))
    else:
        s.box(name, (thick, height, run), color, (pos[0], height / 2.0, pos[2]))
    parts = []
    n = max(2, int(run // 1.7))
    start = -((n - 1) * 1.7) / 2.0
    for i in range(n):
        off = start + i * 1.7
        if axis == "x":
            parts.append({"kind": "box", "size": (1.0, 0.9, thick + 0.08),
                          "color": color, "pos": (off, height + 0.45, 0)})
        else:
            parts.append({"kind": "box", "size": (thick + 0.08, 0.9, 1.0),
                          "color": color, "pos": (0, height + 0.45, off)})
    s.composite(name + "_Merlon", parts, pos=(pos[0], 0, pos[2]))


def _keep_tower(s, name, pos, color, height=9.5, radius=1.7):
    """A stout round dungeon tower: tapered shaft + a corbelled battlement ring
    + a conical slate cap, so the keep reads as a brooding fortress turret."""
    shaft = [(radius, 0), (radius * 1.06, 0.4 * height), (radius * 0.92, 0.82 * height),
             (radius * 1.12, 0.86 * height), (radius * 1.12, 0.94 * height),
             (radius * 0.5, 0.95 * height), (0.0, height)]
    s.lathe(name, shaft, color, pos)
    # crenellation ring on the corbel
    parts = []
    import math as _m
    for i in range(10):
        a = 2.0 * _m.pi * i / 10.0
        parts.append({"kind": "box", "size": (0.5, 0.8, 0.5), "color": color,
                      "pos": (radius * 1.12 * _m.cos(a), 0.9 * height,
                              radius * 1.12 * _m.sin(a))})
    s.composite(name + "_Crown", parts, pos=pos)


def build_doubting_castle():
    s = Scene("doubting_castle")
    stone = (0.34, 0.34, 0.38)
    s.ground("ENV_Doubting_ByPathMeadow", (40, 30), (0.34, 0.4, 0.3), (0, 0, 22))
    # A walkable floor (not a solid block) so the cell/hall are reachable; the
    # castle's bulk is read from its walls, gate and storm instead.
    s.box("ENV_Doubting_CastleExterior", (30, 0.12, 32), (0.28, 0.28, 0.32), (0, 0.06, -8))
    s.box("ENV_Doubting_Cell", (10, 0.1, 10), (0.22, 0.22, 0.26), (0, 0.06, -8))
    s.box("ENV_Doubting_DarkHall", (6, 0.1, 16), (0.2, 0.2, 0.24), (0, 0.06, 2))
    _road(s, "ENV_Doubting_EscapePath", 14, -22, 5, (0.3, 0.32, 0.3))
    _wall(s, "ENV_Doubting_CellWallL", (0.6, 7, 10), (-5, 3.5, -8), stone)
    _wall(s, "ENV_Doubting_CellWallR", (0.6, 7, 10), (5, 3.5, -8), stone)

    s.box("PROP_CellDoor", (3, 3.4, 0.3), (0.4, 0.34, 0.2), (0, 1.7, -3), emissive=(0.1, 0.08, 0.04))
    s.composite("PROP_CellChains", [
        {"kind": "cylinder", "radius": 0.06, "height": 1.6, "color": (0.2, 0.2, 0.22), "pos": (0, 0.8, 0)}], pos=(-3, 0, -10))
    s.box("PROP_ScrollMemory", (0.5, 0.12, 0.4), (0.85, 0.8, 0.7), (2, 0.4, -10), emissive=(0.25, 0.22, 0.16))
    s.composite("PROP_PromiseKey", [
        {"kind": "box", "size": (0.16, 0.6, 0.16), "color": (0.98, 0.86, 0.42), "pos": (0, 0.3, 0), "emissive": (0.85, 0.72, 0.28)},
        {"kind": "torus", "ring_r": 0.17, "tube_r": 0.06, "color": (0.98, 0.86, 0.42), "pos": (0, 0.66, 0), "rot": (90, 0, 0), "emissive": (0.85, 0.72, 0.28)}], pos=(0, 0.5, -10))
    _merlons = [{"kind": "box", "size": (0.9, 0.9, 1.7), "color": stone,
                 "pos": (dx, 9.3, 0)} for dx in (-3.5, -1.75, 0, 1.75, 3.5)]
    s.composite("PROP_CastleGate", [
        {"kind": "box", "size": (1.4, 8, 1.4), "color": stone, "pos": (-3.5, 4, 0)},
        {"kind": "box", "size": (1.4, 8, 1.4), "color": stone, "pos": (3.5, 4, 0)},
        {"kind": "box", "size": (8.4, 1.4, 1.6), "color": stone, "pos": (0, 8.4, 0)},
    ] + _merlons, pos=(0, 0, 4))
    s.marker("PROP_StormCloudMarker", (0, 12, 14))
    # Heavy corner towers giving the castle its brooding mass.
    _tower = [(1.6, 0), (1.8, 0.5), (1.5, 1.0), (1.4, 9.0), (1.7, 9.5),
              (1.9, 10.2), (1.3, 11.0), (0.0, 12.6)]
    s.lathe("PROP_CastleTower_Left", _tower, stone, (-11, 0, -8))
    s.lathe("PROP_CastleTower_Right", _tower, stone, (11, 0, -8))

    # --- A real fortress: crenellated curtain walls ringing the bailey, with a
    # gate gap at the front (x≈0, z=7) and an escape gap at the back (x≈0, z=-19),
    # four tall corner towers, and a stone keep clenched around the dungeon cell.
    wall_dim = (0.34, 0.32, 0.37)
    _battlement_wall(s, "PROP_CastleWall_FrontL", 10.4, (-7.8, 0, 7), wall_dim, "x")
    _battlement_wall(s, "PROP_CastleWall_FrontR", 10.4, (7.8, 0, 7), wall_dim, "x")
    _battlement_wall(s, "PROP_CastleWall_BackL", 10.8, (-7.6, 0, -19), wall_dim, "x")
    _battlement_wall(s, "PROP_CastleWall_BackR", 10.8, (7.6, 0, -19), wall_dim, "x")
    _battlement_wall(s, "PROP_CastleWall_Left", 26.0, (-13, 0, -6), wall_dim, "z")
    _battlement_wall(s, "PROP_CastleWall_Right", 26.0, (13, 0, -6), wall_dim, "z")
    # Tall corner towers (reuse the brooding tower profile).
    s.lathe("PROP_CastleTower_FrontLeft", _tower, stone, (-13, 0, 7))
    s.lathe("PROP_CastleTower_FrontRight", _tower, stone, (13, 0, 7))
    s.lathe("PROP_CastleTower_BackLeft", _tower, stone, (-13, 0, -19))
    s.lathe("PROP_CastleTower_BackRight", _tower, stone, (13, 0, -19))
    # The keep: four dungeon turrets clenched around the cell (x=±5, z=-3/-13),
    # so the pilgrim wakes inside the heart of a great stone keep.
    keep_stone = (0.3, 0.3, 0.34)
    s.composite("PROP_KeepWallBack", [
        {"kind": "box", "size": (3.6, 7.0, 0.7), "color": keep_stone, "pos": (-3.4, 3.5, 0)},
        {"kind": "box", "size": (3.6, 7.0, 0.7), "color": keep_stone, "pos": (3.4, 3.5, 0)},
        {"kind": "box", "size": (10.6, 1.0, 0.7), "color": keep_stone, "pos": (0, 7.4, 0)},
    ], pos=(0, 0, -13))
    _keep_tower(s, "PROP_KeepTower_FrontLeft", (-5, 0, -3), keep_stone)
    _keep_tower(s, "PROP_KeepTower_FrontRight", (5, 0, -3), keep_stone)
    _keep_tower(s, "PROP_KeepTower_BackLeft", (-5, 0, -13), keep_stone)
    _keep_tower(s, "PROP_KeepTower_BackRight", (5, 0, -13), keep_stone)
    # A chapel out in the By-Path meadow — mercy within reach of the dungeon.
    _chapel(s, "PROP_Chapel", (-12, 0, 20), rot=(0, 90, 0), kind="ruined")
    # --- 精装修: a grimmer castle ground (graves, dead trees, puddles, chains) ---
    for i, (gx, gz) in enumerate([(7, 18), (11, 22), (5, 25)], start=1):
        s.composite("PROP_GraveCairn_%02d" % i, [
            {"kind": "box", "size": (0.7, 1.0, 0.2), "color": (0.3, 0.31, 0.34), "pos": (0, 0.5, 0)},
            {"kind": "sphere", "radius": 0.34, "color": (0.32, 0.33, 0.36), "pos": (0, 1.0, 0)}], pos=(gx, 0, gz))
    for i, (dx2, dz2, dh) in enumerate([(-10, 14, 3.5), (12, 16, 3.0)], start=1):
        s.composite("PROP_DeadTreeFoliage_%02d" % i, [
            {"kind": "cylinder", "radius": 0.24, "height": dh, "color": (0.22, 0.18, 0.16), "pos": (0, dh * 0.5, 0)},
            {"kind": "box", "size": (1.8, 0.16, 0.16), "color": (0.22, 0.18, 0.16), "pos": (0.4, dh * 0.8, 0), "rot": (0, 0, 28)}], pos=(dx2, 0, dz2))
    for i, (px, pz, pr) in enumerate([(0, 6, 1.6), (-3, -2, 1.2), (3, -12, 1.4)], start=1):
        s.composite("PROP_PuddleFoliage_%02d" % i, [
            {"kind": "box", "size": (pr, 0.03, pr * 0.8), "color": (0.1, 0.11, 0.16),
             "pos": (0, 0.02, 0), "metallic": 0.1, "roughness": 0.08}], pos=(px, 0, pz))
    s.composite("PROP_CellChains_02", [
        {"kind": "cylinder", "radius": 0.05, "height": 1.4, "color": (0.2, 0.2, 0.22), "pos": (0, 0.7, 0)}], pos=(3, 0, -10))

    s.marker("NPC_Hopeful", (1.5, 0, -9))
    s.marker("NPC_GiantDespair", (0, 0, 1))
    s.marker("NPC_Diffidence", (3, 0, 1))

    s.zone("TRIGGER_ByPathChoice", (10, 3, 4), (0, 1.5, 16))
    s.zone("TRIGGER_Capture", (10, 4, 4), (0, 2, 8))
    s.zone("TRIGGER_CellDespairStart", (8, 3, 8), (0, 1.5, -8))
    s.zone("TRIGGER_FindPromiseKey", (3, 3, 3), (0, 1.5, -10))
    s.zone("TRIGGER_UsePromiseKey", (3, 3, 2), (0, 1.5, -3))
    s.zone("TRIGGER_Exit_DelectableMountains", (8, 4, 2), (0, 1.5, -26))
    s.zone("COL_DespairCellZone", (9, 3, 9), (0, 1.5, -8), color=(0.1, 0.1, 0.18, 0.45))
    s.zone("COL_ShameWhisperZone", (6, 3, 12), (0, 1.5, 2), color=(0.2, 0.12, 0.2, 0.4))
    s.zone("COL_CastleDarkHall", (6, 4, 16), (0, 2, 2), color=(0.08, 0.08, 0.12, 0.4))

    for nm, pos in [("VFX_StormRain", (0, 8, 16)), ("VFX_CellDarkness", (0, 2, -8)),
                    ("VFX_PromiseKeyGlow", (0, 0.6, -10)), ("VFX_CastleDoorUnlock", (0, 1.7, -3))]:
        s.marker(nm, pos)
    s.marker("LIGHT_CellCold", (0, 4, -8))
    s.marker("LIGHT_PromiseKeyGlow", (0, 1.0, -10))
    for nm, pos, rot in [("CAM_ByPathMeadow", (0, 8, 28), (-26, 0, 0)),
                         ("CAM_Capture", (0, 6, 14), (-24, 0, 0)),
                         ("CAM_CellAwake", (0, 3, -3), (-8, 180, 0)),
                         ("CAM_PromiseKeyReveal", (2, 2, -8), (-12, 180, 0)),
                         ("CAM_Escape", (0, 5, -18), (-14, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 24))
    return s


# ===========================================================================
# CHAPTER 13 - Delectable Mountains
# ===========================================================================
def build_delectable_mountains():
    s = Scene("delectable_mountains")
    s.ground("ENV_Mountains_Pasture", (54, 60), (0.38, 0.55, 0.32))
    s.box("ENV_Mountains_ShepherdCamp", (14, 0.1, 12), (0.42, 0.5, 0.34), (-10, 0.06, 8))
    _road(s, "ENV_Mountains_ViewpointPath", 40, -6, 5, (0.5, 0.5, 0.4))
    s.box("ENV_Mountains_CelestialView", (12, 0.12, 8), (0.45, 0.55, 0.4), (0, 0.06, -22))
    _road(s, "ENV_Mountains_ExitPath", 12, -30, 5, (0.46, 0.5, 0.38))

    s.composite("PROP_ShepherdTent", [
        {"kind": "pyramid", "size": (4, 4), "height": 3, "color": (0.7, 0.62, 0.45), "pos": (0, 1.5, 0)}], pos=(-10, 0, 8))
    s.box("PROP_ShepherdMap", (0.7, 0.1, 0.5), (0.85, 0.82, 0.65), (-9, 0.5, 6), emissive=(0.2, 0.2, 0.14))
    s.composite("PROP_Viewpoint_CelestialCity", [
        {"kind": "cylinder", "radius": 0.5, "height": 1.2, "color": (0.7, 0.7, 0.6), "pos": (0, 0.6, 0)}], pos=(0, 1.2, -20))
    s.composite("PROP_Viewpoint_ErrorCliff", [
        {"kind": "cylinder", "radius": 0.5, "height": 1.2, "color": (0.6, 0.55, 0.5), "pos": (0, 0.6, 0)}], pos=(-9, 0, -10))
    s.composite("PROP_Viewpoint_ShortcutGrave", [
        {"kind": "cylinder", "radius": 0.5, "height": 1.2, "color": (0.55, 0.5, 0.5), "pos": (0, 0.6, 0)}], pos=(9, 0, -10))
    s.box("PROP_DistantCelestialCity", (18, 8, 2), (0.93, 0.91, 0.72), (0, 10, -40), emissive=(0.74, 0.68, 0.46))
    s.composite("PROP_PastureStone_01", [
        {"kind": "box", "size": (1.4, 1.0, 1.2), "color": (0.5, 0.5, 0.46), "pos": (0, 0.5, 0)}], pos=(8, 0, 6))
    _chapel(s, "PROP_Chapel", (12, 0, 8), rot=(0, -90, 0), kind="pilgrim")
    s.composite("PROP_PastureTree_01", [
        {"kind": "cylinder", "radius": 0.28, "height": 2.4,
         "color": (0.34, 0.24, 0.16), "pos": (0, 1.2, 0)},
        {"kind": "sphere", "radius": 1.6, "color": (0.2, 0.45, 0.25),
         "pos": (0, 3.1, 0)},
        {"kind": "sphere", "radius": 1.1, "color": (0.23, 0.5, 0.28),
         "pos": (0.9, 3.7, 0.4)},
        {"kind": "sphere", "radius": 1.0, "color": (0.19, 0.43, 0.24),
         "pos": (-0.8, 3.5, -0.3)},
    ], pos=(-14, 0, -2))
    # A fuller grove + a small flock grazing the delectable pasture.
    for _i, (_x, _z, _r) in enumerate([(-16, -5, 1.45), (-11, -7, 1.2)], start=2):
        s.composite("PROP_PastureTree_%02d" % _i, [
            {"kind": "cylinder", "radius": 0.26, "height": 2.2, "color": (0.34, 0.24, 0.16), "pos": (0, 1.1, 0)},
            {"kind": "sphere", "radius": _r, "color": (0.21, 0.46, 0.26), "pos": (0, 2.9, 0)},
            {"kind": "sphere", "radius": _r * 0.72, "color": (0.24, 0.5, 0.29), "pos": (0.6, 3.4, 0.3)}], pos=(_x, 0, _z))
    for _i, (_x, _z) in enumerate([(-6, 12), (-4, 14), (-8, 13)], start=1):
        s.composite("PROP_Sheep_%02d" % _i, [
            {"kind": "sphere", "radius": 0.5, "color": (0.9, 0.9, 0.86), "pos": (0, 0.6, 0)},
            {"kind": "sphere", "radius": 0.22, "color": (0.32, 0.3, 0.3), "pos": (0, 0.74, 0.48)}], pos=(_x, 0, _z))

    s.marker("NPC_Shepherd_Knowledge", (-9, 0, 4))
    s.marker("NPC_Shepherd_Experience", (-11, 0, 6))
    s.marker("NPC_Shepherd_Watchful", (-8, 0, 7))
    s.marker("NPC_Shepherd_Sincere", (-12, 0, 4))
    s.marker("NPC_Hopeful", (-6, 0, 8))

    s.zone("TRIGGER_CelestialView", (6, 3, 4), (0, 2, -20))
    s.zone("TRIGGER_ErrorCliffView", (4, 3, 4), (-9, 1.5, -10))
    s.zone("TRIGGER_ShortcutGraveView", (4, 3, 4), (9, 1.5, -10))
    s.zone("TRIGGER_ReceiveShepherdMap", (5, 3, 5), (-10, 1.5, 8))
    s.zone("TRIGGER_Exit_EnchantedGround", (8, 4, 2), (0, 1.5, -32))
    s.zone("COL_ErrorCliffWarningZone", (6, 3, 6), (-9, 1.5, -10), color=(0.5, 0.3, 0.3, 0.3))

    # ----- a living pasture: a grazing flock, a shepherd's dog, wildflowers, birds -----
    for _i, (_fx, _fz) in enumerate([(-7, 10), (-9, 6), (-6, 13), (8, 11), (10, 7),
                                     (7, 4), (-8, -2), (9, -3), (-5, 2), (6, 15)], start=1):
        _fauna(s, "PROP_Sheep_%02d" % _i, (_fx, 0, _fz), kind="sheep")
    _fauna(s, "PROP_ShepherdDog_Foliage", (-7, 0, -7), kind="dog")
    for _i, (_gx, _gz) in enumerate([(-4, 8), (4, 6), (-10, 12), (10, 13), (-3, 14),
                                     (5, -4), (-9, 2), (8, 0), (2, 12), (-6, 5)], start=1):
        _flora(s, "PROP_Flower_%02d" % _i, (_gx, 0, _gz), kind="flower", n=7)
    for _i, (_tx, _tz) in enumerate([(-12, 4), (12, 9), (-11, -6)], start=1):
        _flora(s, "PROP_GrassTuft_%02d" % _i, (_tx, 0, _tz), kind="grass", n=8)
    _fauna(s, "PROP_Crow_Hill_01", (-2, 3.2, 6), kind="bird")
    _fauna(s, "PROP_Crow_Hill_02", (3, 3.0, 9), kind="bird")

    s.marker("VFX_CelestialCityDistantGlow", (0, 10, -40))
    s.marker("VFX_MountainWind", (0, 3, 0))
    s.marker("VFX_MapGlow", (-9, 0.6, 6))
    s.marker("LIGHT_MountainSun", (0, 20, 10))
    s.marker("LIGHT_CelestialDistantGlow", (0, 10, -40))
    for nm, pos, rot in [("CAM_MountainEntrance", (0, 9, 26), (-26, 0, 0)),
                         ("CAM_CelestialView", (0, 4, -14), (-10, 0, 0)),
                         ("CAM_ErrorCliff", (-9, 3, -4), (-10, 0, 0)),
                         ("CAM_ShepherdWarning", (-9, 3, 12), (-12, 180, 0)),
                         ("CAM_ExitToEnchantedGround", (0, 5, -26), (-12, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 20))
    return s


# ===========================================================================
# CHAPTER 14 - Enchanted Ground
# ===========================================================================
def build_enchanted_ground():
    s = Scene("enchanted_ground")
    s.ground("ENV_Enchanted_Ground", (44, 90), (0.6, 0.62, 0.4))
    _road(s, "ENV_Enchanted_MainPath", 80, 0, 4, (0.7, 0.68, 0.5))
    s.box("ENV_Enchanted_SoftField", (40, 0.08, 60), (0.62, 0.66, 0.46), (0, 0.04, -4))
    s.box("ENV_Enchanted_ExitSlope", (8, 0.12, 12), (0.55, 0.6, 0.42), (0, 0.05, -42))

    # Luminous dream-blooms — beautiful, and dangerously soporific.
    s.composite("PROP_DreamFlower_01", [
        {"kind": "cone", "radius": 0.45, "height": 1.0, "color": (0.55, 0.7, 0.5), "pos": (0, 0.5, 0)},
        {"kind": "sphere", "radius": 0.55, "color": (0.98, 0.62, 0.82), "pos": (0, 1.25, 0), "emissive": (0.6, 0.3, 0.45)}], pos=(-5, 0, 18))
    s.composite("PROP_DreamFlower_02", [
        {"kind": "cone", "radius": 0.45, "height": 1.0, "color": (0.55, 0.7, 0.5), "pos": (0, 0.5, 0)},
        {"kind": "sphere", "radius": 0.55, "color": (0.82, 0.72, 0.98), "pos": (0, 1.25, 0), "emissive": (0.5, 0.42, 0.62)}], pos=(5, 0, 6))
    s.composite("PROP_DreamFlower_03", [
        {"kind": "cone", "radius": 0.4, "height": 0.9, "color": (0.55, 0.7, 0.5), "pos": (0, 0.45, 0)},
        {"kind": "sphere", "radius": 0.5, "color": (0.98, 0.8, 0.6), "pos": (0, 1.1, 0), "emissive": (0.6, 0.45, 0.25)}], pos=(-7, 0, -2))
    s.composite("PROP_DreamFlower_04", [
        {"kind": "cone", "radius": 0.4, "height": 0.9, "color": (0.55, 0.7, 0.5), "pos": (0, 0.45, 0)},
        {"kind": "sphere", "radius": 0.5, "color": (0.7, 0.95, 0.8), "pos": (0, 1.1, 0), "emissive": (0.35, 0.55, 0.42)}], pos=(7, 0, -18))
    # --- 精装修: a lusher, dreamier (and more seductive) enchanted ground ---
    for i, (fx, fz, fc) in enumerate([(-3, 22, (0.98, 0.62, 0.82)), (4, 12, (0.82, 0.72, 0.98)),
                                      (-6, 2, (0.7, 0.95, 0.8)), (5, -28, (0.98, 0.8, 0.6)),
                                      (-4, -32, (0.95, 0.7, 0.9))], start=5):
        s.composite("PROP_DreamFlower_%02d" % i, [
            {"kind": "cone", "radius": 0.4, "height": 0.9, "color": (0.55, 0.7, 0.5), "pos": (0, 0.45, 0)},
            {"kind": "sphere", "radius": 0.48, "color": fc, "pos": (0, 1.1, 0),
             "emissive": tuple(c * 0.6 for c in fc)}], pos=(fx, 0, fz))
    for i, (mx, mz) in enumerate([(5, 18), (-5, 8), (6, -8), (-6, -22)], start=1):
        s.composite("PROP_SoftMoundFoliage_%02d" % i, [
            {"kind": "sphere", "radius": 0.9, "color": (0.5, 0.66, 0.42), "pos": (0, 0.4, 0)},
            {"kind": "sphere", "radius": 0.6, "color": (0.54, 0.7, 0.46), "pos": (0.5, 0.5, 0.3)}], pos=(mx, 0, mz))
    for i, (gx, gz) in enumerate([(2, 20), (-2, 6), (3, -10), (-3, -26), (1, 14)], start=1):
        s.composite("PROP_FireflyGlow_%02d" % i, [
            {"kind": "sphere", "radius": 0.12, "color": (1.0, 0.95, 0.6),
             "pos": (0, 0, 0), "emissive": (0.95, 0.85, 0.45)}], pos=(gx, 1.4, gz))
    s.composite("PROP_DreamArborFoliage", [
        {"kind": "cylinder", "radius": 0.12, "height": 2.4, "color": (0.4, 0.34, 0.22), "pos": (-1.4, 1.2, 0)},
        {"kind": "cylinder", "radius": 0.12, "height": 2.4, "color": (0.4, 0.34, 0.22), "pos": (1.4, 1.2, 0)},
        {"kind": "box", "size": (3.4, 0.2, 1.4), "color": (0.4, 0.34, 0.22), "pos": (0, 2.4, 0)},
        {"kind": "sphere", "radius": 1.3, "color": (0.45, 0.62, 0.4), "pos": (0, 2.9, 0)},
        {"kind": "box", "size": (2.6, 0.25, 0.7), "color": (0.46, 0.4, 0.3), "pos": (0, 0.5, 0.2)},
    ], pos=(-8, 0, -8))
    s.box("PROP_SoftGrassPatch_01", (4, 0.1, 4), (0.55, 0.7, 0.45), (-6, 0.1, -6))
    s.cylinder("PROP_AwakeStone_01", 0.5, 0.5, (0.7, 0.72, 0.8), (0, 0.25, 10), emissive=(0.35, 0.36, 0.42))
    s.cylinder("PROP_AwakeStone_02", 0.5, 0.5, (0.7, 0.72, 0.8), (0, 0.25, -16), emissive=(0.35, 0.36, 0.42))
    s.marker("PROP_ShepherdMapUsePoint", (0, 1.0, 2))
    s.box("PROP_TestimonyMarker_Cross", (0.4, 1.4, 0.4), (0.8, 0.7, 0.4), (-3, 0.7, 0))
    s.box("PROP_TestimonyMarker_Slough", (0.4, 1.4, 0.4), (0.6, 0.6, 0.4), (3, 0.7, -10))
    s.box("PROP_TestimonyMarker_Castle", (0.4, 1.4, 0.4), (0.5, 0.5, 0.55), (-3, 0.7, -22))
    _chapel(s, "PROP_Chapel", (-11, 0, 8), rot=(0, 90, 0), kind="pilgrim")

    s.marker("NPC_Hopeful", (1.5, 0, 16))
    s.marker("NPC_Ignorance_Optional", (4, 0, -24))

    s.zone("TRIGGER_EnterEnchantedGround", (6, 4, 3), (0, 2, 26))
    s.zone("TRIGGER_TestimonyConversation", (6, 3, 6), (0, 1.5, -6))
    s.zone("TRIGGER_HopefulWake", (6, 3, 6), (0, 1.5, -2))
    s.zone("TRIGGER_Exit_RiverOfDeath", (8, 4, 2), (0, 1.5, -40))
    s.zone("COL_SleepZone_01", (8, 3, 10), (0, 1.5, 4), color=(0.6, 0.6, 0.4, 0.35))
    s.zone("COL_SleepZone_02", (8, 3, 10), (0, 1.5, -20), color=(0.6, 0.6, 0.4, 0.35))
    s.zone("COL_DreamFlowerZone", (6, 3, 6), (-5, 1.5, 16), color=(0.8, 0.5, 0.7, 0.3))
    s.zone("COL_SoftGrassRestZone", (6, 3, 6), (-6, 1.5, -6), color=(0.55, 0.7, 0.45, 0.35))

    s.marker("VFX_SleepMist", (0, 1.5, 0))
    s.marker("VFX_DreamPollen", (-5, 1.5, 16))
    s.marker("VFX_AwakeStoneGlow", (0, 0.5, 10))
    s.marker("LIGHT_EnchantedSoftMain", (0, 16, 4))
    s.marker("LIGHT_AwakeStoneGlow", (0, 1.5, 10))
    for nm, pos, rot in [("CAM_EnchantedEntrance", (0, 8, 32), (-24, 0, 0)),
                         ("CAM_DrowsyField", (4, 5, 4), (-16, 160, 0)),
                         ("CAM_TestimonyWalk", (4, 3, -6), (-10, 160, 0)),
                         ("CAM_ExitToRiver", (0, 5, -38), (-12, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 30))
    return s


# ===========================================================================
# CHAPTER 15 - River of Death
# ===========================================================================
def build_river_of_death():
    s = Scene("river_of_death")
    # Flat, flush banks + a thin water surface the pilgrim wades across (depth is
    # symbolic, driven by RiverDepthSystem, not a real drop -- so no 0.5m steps).
    s.box("ENV_River_NearBank", (44, 0.12, 18), (0.3, 0.32, 0.3), (0, 0.06, 18))
    s.box("ENV_River_WaterPlane", (44, 0.1, 40), (0.08, 0.12, 0.22), (0, 0.02, -6), emissive=(0.02, 0.04, 0.08))
    s.box("ENV_River_DeepChannel", (44, 0.1, 14), (0.05, 0.07, 0.16), (0, 0.04, -6))
    s.box("ENV_River_FarBank", (44, 0.12, 16), (0.4, 0.42, 0.4), (0, 0.06, -30))
    _road(s, "ENV_River_CityApproach", 12, -40, 6, (0.6, 0.6, 0.5))
    # A real waist-high water SURFACE the pilgrim wades INTO: a translucent, glossy
    # sheet at ~0.95 m over the crossing band, so stepping off the near bank sinks
    # him to the waist and the deep water hides his legs (RiverWaterZone toggles the
    # swim posture; the dark WaterPlane below shows through as the river's depth).
    s.box("ENV_River_WaterSurface", (44, 0.1, 32), (0.16, 0.32, 0.46, 0.55), (0, 0.95, -7),
          emissive=(0.05, 0.12, 0.2), metallic=0.1, roughness=0.05, bevel=False,
          blend=True, double_sided=True)

    s.composite("PROP_RiverStone_01", [
        {"kind": "box", "size": (1.4, 0.6, 1.4), "color": (0.4, 0.42, 0.44), "pos": (0, 0.3, 0)}], pos=(-3, 0, 4))
    s.composite("PROP_RiverStone_02", [
        {"kind": "box", "size": (1.4, 0.6, 1.4), "color": (0.4, 0.42, 0.44), "pos": (0, 0.3, 0)}], pos=(3, 0, -14))
    s.composite("PROP_FarBankLight", [
        {"kind": "cone", "radius": 1.0, "height": 3.0, "color": (1.0, 0.95, 0.75), "pos": (0, 1.5, 0), "emissive": (0.95, 0.88, 0.65)},
        {"kind": "sphere", "radius": 1.2, "color": (1.0, 0.96, 0.8), "pos": (0, 3.5, 0), "emissive": (0.95, 0.9, 0.7)}], pos=(0, 0, -30))
    s.box("PROP_DistantCelestialGate", (12, 9, 2), (0.98, 0.93, 0.72), (0, 6, -44), emissive=(0.9, 0.82, 0.55))
    _chapel(s, "PROP_Chapel", (-14, 0, 16), rot=(0, 90, 0), kind="river")
    # --- 精装修: reedy near bank, stepping stones, driftwood, radiant far shore ---
    for i, (rx, rz) in enumerate([(-12, 16), (10, 18), (-16, 14), (14, 15)], start=1):
        s.composite("PROP_BankReeds_%02d" % i, [
            {"kind": "box", "size": (0.05, 1.1 + (k % 3) * 0.2, 0.05), "color": (0.4, 0.46, 0.34),
             "pos": (k * 0.16 - 0.4, 0.6, 0)} for k in range(6)], pos=(rx, 0, rz))
    for i, (sx2, sz2, sr) in enumerate([(-3, 8, 0.6), (2, 0, 0.55), (-2, -8, 0.5), (3, -20, 0.6)], start=3):
        s.composite("PROP_RiverStone_%02d" % i, [
            {"kind": "sphere", "radius": sr, "color": (0.4, 0.42, 0.45), "pos": (0, sr * 0.4, 0)}], pos=(sx2, 0, sz2))
    for i, (dx2, dz2, da) in enumerate([(-7, 6, 20), (7, -4, -25)], start=1):
        s.composite("PROP_DriftwoodFoliage_%02d" % i, [
            {"kind": "cylinder", "radius": 0.18, "height": 2.6, "color": (0.32, 0.27, 0.2),
             "pos": (0, 0.12, 0), "rot": (0, da, 90)}], pos=(dx2, 0, dz2))
    for i, (gx, gz) in enumerate([(-4, -30), (4, -30), (0, -34)], start=1):
        s.composite("PROP_FarShoreGlow_%02d" % i, [
            {"kind": "sphere", "radius": 0.4, "color": (1.0, 0.93, 0.72),
             "pos": (0, 0.5, 0), "emissive": (0.95, 0.85, 0.6)}], pos=(gx, 0, gz))

    s.marker("NPC_Hopeful", (1.5, 0, 14))
    s.marker("NPC_ShiningOne_01", (-2, 0, -30))
    s.marker("NPC_ShiningOne_02", (2, 0, -30))
    # The river creature: it surfaces mid-stream to bar the crossing and lunges at
    # the pilgrim's heart (fear/despair). It is symbolic, never lethal — when faith
    # outweighs fear it sinks back and the water opens. (RiverMonster.gd)
    s.marker("ENEMY_RiverMonster", (0, 0.9, -4))

    s.zone("TRIGGER_EnterRiver", (10, 4, 3), (0, 2, 12))
    s.zone("TRIGGER_MidRiverFear", (12, 4, 4), (0, 2, -6))
    s.zone("TRIGGER_RiverMemoryRecall", (12, 4, 4), (0, 2, -12))
    s.zone("TRIGGER_Exit_CelestialCity", (10, 4, 2), (0, 1.5, -36))
    s.zone("COL_RiverFearZone", (24, 4, 10), (0, 2, 2), color=(0.1, 0.12, 0.25, 0.4))
    s.zone("COL_RiverDeepZone", (24, 4, 10), (0, 2, -10), color=(0.05, 0.07, 0.2, 0.5))
    s.zone("COL_RiverMemoryPromptZone", (24, 4, 6), (0, 2, -14), color=(0.2, 0.2, 0.35, 0.3))
    # The wet stretch: entering it sinks the pilgrim to the waist and starts the
    # swim/wade posture; faith vs. fear sets how hard the water pulls. (RiverWaterZone)
    s.zone("COL_RiverWater", (44, 4, 32), (0, 2, -7), color=(0.12, 0.3, 0.5, 0.16))

    for nm, pos in [("VFX_RiverMist", (0, 1.5, -6)), ("VFX_CityGlowAcrossRiver", (0, 6, -44)),
                    ("VFX_MemoryLight_Cross", (-3, 1.5, -8)), ("VFX_MemoryLight_Key", (3, 1.5, -10)),
                    ("VFX_WaterShallowing", (0, 0.2, -10))]:
        s.marker(nm, pos)
    s.marker("LIGHT_RiverMoon", (0, 18, 16))
    s.marker("LIGHT_CelestialAcrossRiver", (0, 8, -40))
    for nm, pos, rot in [("CAM_RiverApproach", (0, 7, 28), (-24, 0, 0)),
                         ("CAM_MidRiver", (5, 3, -6), (-8, 170, 0)),
                         ("CAM_HopefulEncouragement", (3, 2.5, 4), (-6, 180, 0)),
                         ("CAM_FarBank", (0, 5, -26), (-12, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1.2, 24))
    return s


# ===========================================================================
# CHAPTER 16 - Celestial City
# ===========================================================================
def build_celestial_city():
    s = Scene("celestial_city")
    # Warm, radiant approach — gold and cream, brighter the nearer the gate.
    s.box("ENV_Celestial_FarBank", (40, 1.0, 14), (0.62, 0.56, 0.42), (0, 0.0, 20))
    _road(s, "ENV_Celestial_ApproachRoad", 40, 0, 8, (0.96, 0.86, 0.58))
    s.box("ENV_Celestial_GatePlatform", (16, 0.3, 12), (0.98, 0.89, 0.64), (0, 0.1, -16))
    # The gate opens into a REAL, walkable interior (the City within) -- not a wall.
    s.box("ENV_Celestial_InteriorFloor", (32, 0.3, 40), (0.95, 0.90, 0.72), (0, 0.1, -44),
          tex="marble", tile=2.4, bevel=False)
    _road(s, "ENV_Celestial_InteriorAisle", 40, -44, 6, (0.98, 0.92, 0.62),
          tex="marble", tile=2.0)
    s.box("ENV_Celestial_FarRadiance_Glow", (44, 28, 2), (1.0, 0.96, 0.78), (0, 13, -66),
          emissive=(0.92, 0.80, 0.5), blend=True, bevel=False)

    # Gilded lintel + a radiant halo ring and finials crowning the gate.
    s.composite("PROP_CelestialGate", [
        {"kind": "box", "size": (10, 1.6, 1.6), "color": (0.95, 0.9, 0.55),
         "pos": (0, 9.0, 0), "emissive": (0.7, 0.62, 0.3)},
        {"kind": "torus", "ring_r": 2.3, "tube_r": 0.34, "color": (0.98, 0.92, 0.6),
         "pos": (0, 11.8, 0.2), "rot": (90, 0, 0), "emissive": (0.85, 0.72, 0.36)},
        {"kind": "sphere", "radius": 0.62, "color": (0.98, 0.92, 0.6),
         "pos": (-4.5, 9.9, 0), "emissive": (0.7, 0.62, 0.32)},
        {"kind": "sphere", "radius": 0.62, "color": (0.98, 0.92, 0.6),
         "pos": (4.5, 9.9, 0), "emissive": (0.7, 0.62, 0.32)},
    ], pos=(0, 0, -18))
    _arch = [(0.85, 0), (0.98, 0.5), (0.75, 1.0), (0.7, 8.0), (0.92, 8.6), (0.8, 9.0)]
    s.lathe("PROP_GateArch_Left", _arch, (0.92, 0.88, 0.72), (-4.5, 0, -18),
            emissive=(0.4, 0.38, 0.3))
    s.lathe("PROP_GateArch_Right", _arch, (0.92, 0.88, 0.72), (4.5, 0, -18),
            emissive=(0.4, 0.38, 0.3))
    _pillar = [(0.6, 0), (0.82, 0.5), (0.55, 1.0), (0.5, 8.8), (0.72, 9.3),
               (0.86, 9.8), (0.6, 10.0)]
    s.lathe("PROP_CityLightPillar_01", _pillar, (0.9, 0.9, 0.8), (-8, 0, -14),
            emissive=(0.5, 0.5, 0.4))
    s.lathe("PROP_CityLightPillar_02", _pillar, (0.9, 0.9, 0.8), (8, 0, -14),
            emissive=(0.5, 0.5, 0.4))

    # Grand staircase climbing to the gate threshold.
    _stair = [{"kind": "box", "size": (12 - k * 1.3, 0.18, 1.4),
               "color": (0.96, 0.9, 0.7), "pos": (0, 0.09 + k * 0.18, -k * 1.0),
               "emissive": (0.24, 0.21, 0.12)} for k in range(5)]
    s.composite("PROP_CelestialStair", _stair, pos=(0, 0, -11))
    # Warm city walls framing the gate.
    s.box("ENV_Celestial_WallLeft", (1.8, 11, 16), (0.9, 0.84, 0.66),
          (-12.5, 5.5, -22), emissive=(0.22, 0.2, 0.12))
    s.box("ENV_Celestial_WallRight", (1.8, 11, 16), (0.9, 0.84, 0.66),
          (12.5, 5.5, -22), emissive=(0.22, 0.2, 0.12))

    # Soaring gilded spires of the City beyond the wall (out of reach).
    def _spire(H):
        return [(1.3, 0), (1.5, H * 0.06), (1.0, H * 0.12), (0.85, H * 0.66),
                (1.15, H * 0.72), (0.45, H * 0.86), (0.0, H)]
    for i, (sxp, hh) in enumerate([(-9, 17), (-3, 23), (3, 20), (9, 25)], start=1):
        s.lathe("PROP_CelestialSpire_%02d" % i, _spire(hh), (0.96, 0.9, 0.64),
                (sxp, 0, -29), emissive=(0.5, 0.42, 0.22))

    # ----- the City within: the throne, the host of heaven, the marriage supper -----
    s.box("ENV_Celestial_InteriorWallLeft", (1.6, 13, 40), (0.93, 0.86, 0.66),
          (-15.5, 6.5, -44), tex="marble", tile=3.0, emissive=(0.24, 0.22, 0.14))
    s.box("ENV_Celestial_InteriorWallRight", (1.6, 13, 40), (0.93, 0.86, 0.66),
          (15.5, 6.5, -44), tex="marble", tile=3.0, emissive=(0.24, 0.22, 0.14))
    # the crowned Lord enthroned in glory at the far end (reverent, symbolic)
    _enthroned_lord(s, "PROP_Celestial", (0, 0.3, -56))
    s.composite("PROP_ThroneSteps", [
        {"kind": "box", "size": (10 - k * 1.6, 0.3, 1.4), "color": (0.95, 0.9, 0.72),
         "pos": (0, 0.15 + k * 0.3, k * 1.0), "tex": "marble"} for k in range(4)], pos=(0, 0, -51))
    # ranks of angels flanking the aisle
    for i, (ax, az) in enumerate([(-5, -32), (5, -32), (-5, -42), (5, -42), (-5, -50), (5, -50)], start=1):
        _angel(s, "PROP_Angel_Crowd_%02d" % i, (ax, 0, az), rot=(0, (90 if ax < 0 else -90), 0))
    # the great multitude of the redeemed in white, lining the way, rejoicing
    _white = [(0.97, 0.95, 0.9), (0.95, 0.93, 0.86), (0.99, 0.97, 0.92), (0.93, 0.9, 0.84)]
    for i, (cx, cz) in enumerate([(-10, -30), (10, -30), (-11, -38), (11, -38),
                                  (-10, -46), (10, -46), (-9, -53), (9, -53)], start=1):
        _crowd(s, "PROP_SaintHost_Crowd_%02d" % i, (cx, 0, cz), rows=3, cols=4, robes=_white, hands_raised=True)
    # the marriage supper of the Lamb -- long laden feast tables to the sides
    _feast_table(s, "PROP_FeastTable_01", (-12.5, 0, -40), length=9.0)
    _feast_table(s, "PROP_FeastTable_02", (12.5, 0, -40), length=9.0)
    _feast_table(s, "PROP_FeastTable_03", (-12.5, 0, -52), length=7.0)
    _feast_table(s, "PROP_FeastTable_04", (12.5, 0, -52), length=7.0)
    # the river of life (wade-through) and the tree of life (Rev 22)
    s.box("ENV_RiverOfLife_WaterSurface", (2.6, 0.12, 34), (0.6, 0.85, 0.95),
          (-14, 0.16, -46), tex="water", blend=True, bevel=False)
    s.composite("PROP_TreeOfLife", [
        {"kind": "cylinder", "radius": 0.7, "height": 6.0, "color": (0.5, 0.4, 0.28), "pos": (0, 3, 0), "tex": "bark"},
        {"kind": "sphere", "radius": 3.0, "color": (0.6, 0.85, 0.45), "pos": (0, 7.0, 0), "emissive": (0.2, 0.3, 0.12)},
        {"kind": "sphere", "radius": 2.0, "color": (0.7, 0.9, 0.5), "pos": (1.6, 6.2, 0.5), "emissive": (0.22, 0.32, 0.14)},
    ], pos=(14, 0, -46))

    _chapel(s, "PROP_Chapel", (-10, 0, 8), rot=(0, 90, 0), kind="celestial")
    s.marker("PROP_JourneyReviewMarker", (0, 1.5, -49))

    s.marker("NPC_Hopeful", (1.6, 0, 6))
    s.marker("NPC_ShiningOne_01", (-3.5, 0, -30))   # greeters along the interior aisle
    s.marker("NPC_ShiningOne_02", (3.5, 0, -34))
    s.marker("NPC_Gatekeeper", (0, 0, -16))

    # Arrival is WALKED, not cut to credits: gate -> feast -> throne (the finale).
    s.zone("TRIGGER_EnterCelestialCity", (8, 4, 3), (0, 2, -20))
    s.zone("TRIGGER_FeastWelcome", (18, 4, 5), (0, 2, -38))
    s.zone("TRIGGER_ThroneWorship", (10, 4, 4), (0, 2, -52))
    # interior glory + feast lighting and cinematic camera anchors
    s.marker("LIGHT_ThroneGlorySun", (0, 16, -56))
    s.marker("LIGHT_FeastWarm_L", (-12, 5, -44))
    s.marker("LIGHT_FeastWarm_R", (12, 5, -44))
    s.marker("VFX_GloryMotes_Throne", (0, 6, -54))
    s.marker("VFX_PetalFall_Aisle", (0, 8, -40))
    s.marker("CAM_InteriorAisle", (0, 5, -26), rot=(-8, 0, 0))
    s.marker("CAM_ThroneApproach", (0, 6, -46), rot=(-12, 0, 0))

    s.marker("VFX_CelestialGateGlow", (0, 6, -18))
    s.marker("VFX_CityLightRays", (0, 12, -24))
    s.marker("VFX_FinalWelcomeParticles", (0, 3, -10))
    s.marker("LIGHT_CelestialMain", (0, 20, 8))
    s.marker("LIGHT_GateGlow", (0, 6, -18))
    s.marker("LIGHT_CityInteriorGlow", (0, 8, -26))
    for nm, pos, rot in [("CAM_CelestialApproach", (0, 8, 26), (-24, 0, 0)),
                         ("CAM_GateOpen", (0, 5, -8), (-10, 180, 0)),
                         ("CAM_JourneyReview", (4, 3, 2), (-8, 190, 0)),
                         ("CAM_FinalEntry", (0, 5, -12), (-10, 0, 0)),
                         ("CAM_EndCredits", (0, 7, -22), (-10, 0, 0))]:
        s.marker(nm, pos, rot)
    s.marker("SPAWN_Player_Start", (0, 1, 20))
    return s


# ---------------------------------------------------------------------------
_BASE_SCENES = {
    "city_of_destruction": build_city_of_destruction,
    "wilderness_road": build_wilderness_road,
    "slough_of_despond": build_slough_of_despond,
    "wicket_gate": build_wicket_gate,
    "cross_and_tomb": build_cross_and_tomb,
    "interpreter_house": build_interpreter_house,
    "hill_difficulty": build_hill_difficulty,
    "palace_beautiful": build_palace_beautiful,
    "valley_humiliation": build_valley_humiliation,
    "valley_shadow_death": build_valley_shadow_death,
    "vanity_fair": build_vanity_fair,
    "doubting_castle": build_doubting_castle,
    "delectable_mountains": build_delectable_mountains,
    "enchanted_ground": build_enchanted_ground,
    "river_of_death": build_river_of_death,
    "celestial_city": build_celestial_city,
}


# ===========================================================================
# Industrial-grade dressing pass
# ---------------------------------------------------------------------------
# Adds depth, density and framing to every chapter (City of Destruction and the
# already-dense Wilderness Road are left as-is). Applied centrally by wrapping
# the builders, so each builder above keeps ALL of its gameplay markers; the
# dressing only ADDS decorative nodes (non-solid scatter via binder skip-tokens;
# rocks/boulders stay solid). forward = -Z; spawn toward +Z.
# ===========================================================================
def _dress_slough(s):
    """Bleak drowned fen ringing the mire: dead trees, sedge, mossy stones, moor."""
    for i, (x, z, h) in enumerate([(-14, 6, 3.4), (13, -4, 3.8), (-16, -18, 3.0),
                                   (15, -26, 2.8), (-13, -40, 2.9), (14, 12, 3.2),
                                   (-10, -8, 2.6)], 1):
        s.composite("PROP_Foliage_DeadTree_%02d" % i, [
            {"kind": "cylinder", "radius": 0.2, "height": h, "color": (0.2, 0.19, 0.16),
             "pos": (0, h / 2, 0), "sides": 6},
            {"kind": "cylinder", "radius": 0.07, "height": 1.5, "color": (0.2, 0.19, 0.16),
             "pos": (0.5, h * 0.82, 0.1), "rot": (0, 0, 42), "sides": 4},
            {"kind": "cylinder", "radius": 0.06, "height": 1.2, "color": (0.2, 0.19, 0.16),
             "pos": (-0.4, h * 0.7, -0.1), "rot": (0, 0, -38), "sides": 4}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-11, 2), (12, -12), (-13, -28), (12, -34), (10, 18),
                                (-9, 16), (8, -44), (-8, -46), (11, 6), (-12, -6)], 1):
        _reedclump(s, "PROP_Reeds_Fen_%02d" % i, (x, 0, z), (0.33, 0.4, 0.3), 1.8)
    for i, (x, z, sz) in enumerate([(-12, 10, 1.3), (12, 4, 1.1), (-15, -14, 1.4),
                                    (14, -22, 1.2), (-11, -36, 1.0), (13, -44, 1.2)], 1):
        _rock(s, "PROP_Rock_Moss_%02d" % i, (x, 0, z), sz, (0.3, 0.34, 0.27))
    for i, (x, z) in enumerate([(-9, 20), (9, 14), (-7, -48), (7, -50), (-6, 30), (6, 28)], 1):
        _grass(s, "PROP_Grass_Sedge_%02d" % i, (x, 0, z), (0.35, 0.42, 0.3))
    s.composite("PROP_SunkenCart", [
        {"kind": "box", "size": (2.4, 0.8, 1.3), "color": (0.3, 0.25, 0.17),
         "pos": (0, 0.25, 0), "rot": (10, 0, 7)},
        {"kind": "cylinder", "radius": 0.6, "height": 0.18, "color": (0.24, 0.19, 0.13),
         "pos": (1.0, 0.2, 0.7), "rot": (90, 0, 0), "sides": 10}], pos=(-9, 0, -12))
    # Tussock mounds breaking up the open mire (non-solid grassy humps).
    for i, (x, z) in enumerate([(-3, -2), (3, -8), (-5, -16), (4, -20), (-2, -26),
                                (5, -30), (-4, 0), (2, -36), (-6, -22), (6, -14),
                                (-3, -42), (3, 4)], 1):
        s.composite("PROP_Grass_Tussock_%02d" % i, [
            {"kind": "sphere", "radius": 0.7, "color": (0.25, 0.3, 0.22),
             "pos": (0, 0.22, 0), "segs": 8, "rings": 4},
            {"kind": "cone", "radius": 0.1, "height": 0.7, "color": (0.36, 0.42, 0.28),
             "pos": (-0.2, 0.55, 0), "sides": 4},
            {"kind": "cone", "radius": 0.1, "height": 0.8, "color": (0.36, 0.42, 0.28),
             "pos": (0.15, 0.6, 0.1), "sides": 4},
            {"kind": "cone", "radius": 0.09, "height": 0.6, "color": (0.33, 0.4, 0.26),
             "pos": (0.05, 0.5, -0.2), "sides": 4}], pos=(x, 0, z))
    # A dense reed fringe hugging the safe stone path so the way reads clearly.
    for i, z in enumerate(range(8, -40, -8), 1):
        _reedclump(s, "PROP_Reeds_PathL_%02d" % i, (-2.6, 0, z), (0.32, 0.4, 0.3), 1.5)
        _reedclump(s, "PROP_Reeds_PathR_%02d" % i, (2.6, 0, z), (0.32, 0.4, 0.3), 1.5)
    # The drowned moor closing the horizon (near + tall so it reads, not zooms out).
    _ridge(s, "PROP_Ridge_Moor", (0, 0, -56),
           [(-20, 22, 9), (-2, 26, 12), (20, 22, 10)], (0.18, 0.22, 0.24))
    # --- 住满世界: the fen teems with cold, indifferent life (all walk-through) ---
    # Herons stalking the mire to the sides of the safe stone path.
    for i, (x, z) in enumerate([(-10, -6), (11, -20), (-12, -34), (10, 4)], 1):
        _bird(s, "PROP_Fauna_Heron_%02d" % i, (x, 0, z), kind="heron",
              rot=(0, 90 if x < 0 else -90, 0))
    # Frogs & toads hunched on sunk logs and tussock mounds.
    for i, (x, z) in enumerate([(-8, -10), (8, -34), (-3, -2), (3, -8), (5, -30), (-4, 0)], 1):
        _critter(s, "PROP_Critter_Frog_%02d" % i, (x, 0.2, z),
                 kind=("toad" if i % 2 else "frog"))
    # Dragonflies and clouds of midges hanging over the muck.
    for i, (x, z) in enumerate([(-5, -14), (6, -24), (-6, -4), (4, -38)], 1):
        _critter(s, "PROP_Critter_Dragonfly_%02d" % i, (x, 0.9, z), kind="dragonfly", rot=(0, i * 47, 0))
    for i, (x, z) in enumerate([(-7, -18), (7, -8), (-9, -30), (8, -22)], 1):
        _critter(s, "PROP_Critter_Midges_%02d" % i, (x, 1.4, z), kind="midges")
    # A lapwing or two calling from the reed fringe; a lone crow gliding over.
    for i, (x, z) in enumerate([(-9, 14), (9, 10)], 1):
        _bird(s, "PROP_Fauna_Marshbird_%02d" % i, (x, 1.0, z), kind="lark")
    _bird(s, "PROP_Crow_Fen_01", (4, 5.5, -26), kind="raptor", rot=(0, 30, 0))
    # Sparse marsh ferns clinging to the firmer hummocks.
    for i, (x, z) in enumerate([(-11, -2), (11, -16), (-9, -38), (10, -28)], 1):
        _flora(s, "PROP_Foliage_Marsh_%02d" % i, (x, 0, z), kind="fern", n=5)
    # Dark standing-water pools on the shallower flanks of the mire (clear of the
    # central deep bog; non-solid via the WaterSurface skip-token).
    for i, (x, z, r) in enumerate([(-9, 4, 2.2), (9, 0, 2.0), (-11, -16, 2.0),
                                   (11, -22, 1.9), (-9, -44, 2.2), (8, -44, 1.9)], 1):
        s.cylinder("PROP_MudPool_%02d_WaterSurface" % i, r, 0.08, (0.08, 0.10, 0.09),
                   (x, 0.20, z), sides=16, emissive=(0.012, 0.018, 0.015),
                   metallic=0.08, roughness=0.4)
    # Sickly green algae scum on the deep bog & pools — unmistakably a swamp
    # (non-solid via the Foliage skip-token).
    for i, (x, z, r) in enumerate([(-3, -22, 1.3), (3, -28, 1.5), (-2, -32, 1.1),
                                   (4, -18, 1.0), (0, -36, 1.2), (-9, 4, 1.0),
                                   (11, -22, 0.9)], 1):
        s.composite("PROP_AlgaeScum_%02d_Foliage" % i, [
            {"kind": "cylinder", "radius": r, "height": 0.04, "color": (0.34, 0.46, 0.2),
             "pos": (0, 0, 0), "sides": 12, "emissive": (0.1, 0.16, 0.05),
             "roughness": 0.95}], pos=(x, 0.28, z))
    # Low, half-sunk mud mounds breaking the muck on the flanks (non-solid).
    for i, (x, z, r) in enumerate([(-11, -8, 0.9), (11, -16, 1.0), (-10, -34, 0.8),
                                   (10, -6, 0.85), (-12, -24, 0.95)], 1):
        s.composite("PROP_MudMound_%02d_Foliage" % i, [
            {"kind": "sphere", "radius": r, "color": (0.2, 0.17, 0.11),
             "pos": (0, r * 0.3, 0), "segs": 9, "rings": 5, "roughness": 0.9}],
            pos=(x, 0.16, z))


def _dress_wicket(s):
    """A rocky ravine climbing to the gate, lit by lanterns, the City glowing beyond."""
    for i, (x, z) in enumerate([(6.4, 14), (-6.4, 8), (6.6, -2), (-6.6, 2),
                                (6.2, 18), (-6.2, -4)], 1):
        _rock(s, "PROP_Rock_Ravine_%02d" % i, (x, 0, z), 1.5, (0.2, 0.21, 0.27))
    for i, (x, z) in enumerate([(2.6, 12), (-2.6, 6), (2.6, 0), (-2.6, -4)], 1):
        _lantern(s, "PROP_Lantern_Path_%02d" % i, (x, 0, z), (1.0, 0.82, 0.45))
    for i, (x, z) in enumerate([(3.4, 16), (-3.4, 10), (3.2, 4), (-3.2, -2)], 1):
        _bush(s, "PROP_Bush_Ravine_%02d" % i, (x, 0, z), 0.6, (0.24, 0.3, 0.22))
    # The radiant City of God glimpsed through the open gate (beyond, -Z).
    s.composite("PROP_Distant_CityBeyond", [
        {"kind": "box", "size": (3, 9, 2), "color": (0.98, 0.93, 0.74), "pos": (px, hy, 0),
         "emissive": (0.85, 0.78, 0.5)}
        for (px, hy) in [(-4, 4.5), (-1, 6.5), (2, 5.5), (5, 7.5), (0, 3.5)]], pos=(0, 0, -22))
    # Dark brooding hills rising above the ravine walls.
    _ridge(s, "PROP_Ridge_Above_L", (-12, 0, 4), [(0, 18, 12), (8, 14, 9)], (0.12, 0.13, 0.18))
    _ridge(s, "PROP_Ridge_Above_R", (12, 0, 4), [(0, 18, 12), (-8, 14, 9)], (0.12, 0.13, 0.18))
    s.marker("LIGHT_GateCityGlow", (0, 5, -16))
    # --- 住满世界: a sparse sign of life on the narrow way (restrained) ---
    # Two small birds on the ravine rocks; a single dove waiting above the gate.
    _bird(s, "PROP_Fauna_Songbird_01", (6.4, 1.6, 14), kind="songbird", rot=(0, -120, 0))
    _bird(s, "PROP_Fauna_Songbird_02", (-6.4, 1.6, 8), kind="songbird", rot=(0, 120, 0))
    _bird(s, "PROP_Dove_Gate_01", (2.2, 4.6, -8.5), kind="dove", rot=(0, 200, 0))
    # A hare at the ravine edge; hardy tufts in the rock cracks.
    _critter(s, "PROP_Critter_Hare_01", (-6, 0, 16), kind="hare", rot=(0, -30, 0))
    for i, (x, z) in enumerate([(5, 4), (-5, 0)], 1):
        _flora(s, "PROP_Grass_Crack_%02d" % i, (x, 0, z), kind="grass", n=4)


def _dress_cross(s):
    """The hill of grace greening with new life: meadow trees, blossom, far hills."""
    for i, (x, z, h) in enumerate([(-15, 6, 5.0), (16, 2, 5.5), (-17, -10, 4.6),
                                   (17, -14, 5.0), (-14, 18, 4.4), (15, 20, 4.8)], 1):
        _tree(s, "PROP_Foliage_Oak_%02d" % i, (x, 0, z), h,
              (0.3, 0.5, 0.26), (0.4, 0.3, 0.18))
    for i, (x, z, c) in enumerate([(-4, 4, (0.95, 0.8, 0.4)), (4, 2, (0.95, 0.55, 0.6)),
                                   (-3, -6, (0.85, 0.7, 0.95)), (3, -8, (0.98, 0.85, 0.5)),
                                   (-5, 10, (0.95, 0.6, 0.55)), (5, 12, (0.9, 0.82, 0.45))], 1):
        _flower(s, "PROP_Flower_Hill_%02d" % i, (x, 0, z), c, (c[0]*0.4, c[1]*0.4, c[2]*0.4))
    for i, (x, z) in enumerate([(-7, 0), (7, -4), (-6, 8), (6, 6), (-8, -12), (8, -10)], 1):
        _bush(s, "PROP_Bush_Bloom_%02d" % i, (x, 0, z), 0.7, (0.34, 0.5, 0.28))
    for i, (x, z) in enumerate([(-2.6, 6), (2.6, 4), (-2.6, 0), (2.6, -2)], 1):
        _grass(s, "PROP_Grass_Path_%02d" % i, (x, 0, z), (0.42, 0.56, 0.32))
    _ridge(s, "PROP_Ridge_GreenHills", (0, 0, -44),
           [(-20, 22, 7), (-2, 26, 9), (20, 24, 8)], (0.36, 0.46, 0.34))
    # --- 住满世界: new life answering the grace of the Cross ---
    # Butterflies dancing above the hill blossoms (hilltop surface ~y=1.0).
    for i, (x, z) in enumerate([(-3, -16), (3, -14), (-5, -22), (4, -11)], 1):
        _critter(s, "PROP_Butterfly_Grace_%02d" % i, (x, 1.7, z), kind="butterfly", rot=(0, i * 64, 0))
    # Songbirds returned to the meadow oaks.
    _bird(s, "PROP_Fauna_Songbird_01", (-15, 4.5, 6), kind="songbird", rot=(0, 60, 0))
    _bird(s, "PROP_Fauna_Songbird_02", (16, 4.2, 2), kind="songbird", rot=(0, -70, 0))
    # A white lamb resting near the empty tomb — the Lamb who was slain (Rev 5).
    _fauna(s, "PROP_Sheep_Lamb_Tomb", (-6, 1.1, -17), kind="sheep")
    # A hare in the greening grass below the hill.
    _critter(s, "PROP_Critter_Hare_01", (5, 0, 4), kind="hare", rot=(0, -30, 0))


def _dress_interpreter(s):
    """Furnish the instructive house: runner rug, sconces, shelves, beams, hearth."""
    # Long runner rug down the central hall.
    s.box("PROP_Decor_HallRug", (3.0, 0.06, 22), (0.5, 0.18, 0.16), (0, 0.12, -6),
          emissive=(0.12, 0.04, 0.04))
    # Wall sconces (warm) along the main hall.
    for i, (x, z) in enumerate([(-6.2, 6), (6.2, 6), (-6.2, -6), (6.2, -6)], 1):
        _lantern(s, "PROP_Lantern_Sconce_%02d" % i, (x, 0, z), (1.0, 0.84, 0.5))
    # Bookshelves & cabinets against the south wall.
    for i, x in enumerate([-9, -4.5, 4.5, 9], 1):
        s.composite("PROP_Decor_Bookshelf_%02d" % i, [
            {"kind": "box", "size": (2.6, 3.0, 0.7), "color": (0.32, 0.22, 0.15),
             "pos": (0, 1.5, 0)},
            {"kind": "box", "size": (2.3, 0.5, 0.6), "color": (0.6, 0.5, 0.34),
             "pos": (0, 1.0, 0.06), "emissive": (0.12, 0.1, 0.05)},
            {"kind": "box", "size": (2.3, 0.5, 0.6), "color": (0.55, 0.46, 0.3),
             "pos": (0, 2.0, 0.06), "emissive": (0.1, 0.08, 0.04)}], pos=(x, 0, 12.6))
    # Ceiling beams spanning the hall.
    for i, z in enumerate([6, 0, -6, -12], 1):
        s.box("PROP_Decor_Beam_%02d" % i, (12, 0.4, 0.4), (0.26, 0.19, 0.13), (0, 3.9, z))
    # A warm hearth on the east edge of the hall.
    s.composite("PROP_Decor_Hearth", [
        {"kind": "box", "size": (3.0, 2.4, 1.0), "color": (0.4, 0.36, 0.32), "pos": (0, 1.2, 0)},
        {"kind": "box", "size": (1.6, 1.3, 0.5), "color": (0.1, 0.08, 0.08), "pos": (0, 0.8, 0.4)},
        {"kind": "cone", "radius": 0.6, "height": 1.2, "color": (1.0, 0.55, 0.2),
         "pos": (0, 0.9, 0.45), "emissive": (0.95, 0.45, 0.12), "sides": 8}], pos=(8.5, 0, 11))
    s.marker("LIGHT_HearthGlowWarm", (8.5, 1.4, 10))
    # Potted greenery softening the hall corners.
    for i, (x, z) in enumerate([(-5, 9), (5, 9), (-5, -16), (5, -16)], 1):
        _bush(s, "PROP_Bush_Pot_%02d" % i, (x, 0, z), 0.55, (0.26, 0.42, 0.26))
    # --- 住满世界: the Interpreter's household (calm, attentive, indoors) ---
    # Two pupils listening toward the Interpreter (who stands at z=-3); clear of
    # the central instruction spot.
    _household_figure(s, "PROP_Household_Pupil_01", (-4.5, 0, 3), robe=(0.36, 0.4, 0.5), h=1.5, rot=(0, 180, 0))
    _household_figure(s, "PROP_Household_Pupil_02", (4.5, 0, 4), robe=(0.5, 0.42, 0.3), h=1.55, rot=(0, 180, 0))
    # A servant tending the south hearth (arm raised), off in the corner.
    _household_figure(s, "PROP_Household_Servant_01", (7, 0, 9), robe=(0.46, 0.36, 0.26), h=1.58, arm=True, rot=(0, -120, 0))
    # A caged songbird's free cousin: a robin perched on the hall bookshelf, and
    # one on a ceiling beam — small living warmth in the house of instruction.
    _bird(s, "PROP_Fauna_Robin_01", (-5.5, 2.75, 5.5), kind="songbird", rot=(0, -90, 0))
    _bird(s, "PROP_Fauna_Robin_02", (3, 3.7, -6), kind="songbird", rot=(0, 30, 0))
    # The house-dog dozing by the warm hearth.
    _fauna(s, "PROP_Sheep_HouseDog", (8.5, 0, 9.4), kind="dog")


def _dress_hill(s):
    """A real rocky hillside: pines and boulders on the climb, peaks behind."""
    for i, (x, z, h) in enumerate([(-9, -2, 6.5), (9, -6, 7.0), (-11, -16, 6.0),
                                   (11, -20, 6.8), (-7, -24, 5.6), (8, -26, 6.2)], 1):
        _pine(s, "PROP_Foliage_Pine_%02d" % i, (x, 0, z), h, (0.16, 0.3, 0.22))
    for i, (x, z, sz) in enumerate([(-6, -10, 1.6), (6, -14, 1.8), (-4, -20, 1.3),
                                    (5, -22, 1.5), (-8, -6, 1.4), (7, -2, 1.5)], 1):
        _rock(s, "PROP_Rock_Slope_%02d" % i, (x, 0, z), sz, (0.5, 0.46, 0.4))
    # The Danger path (left) grim and cold; Destruction path (right) broken rubble.
    for i, (x, z) in enumerate([(-15, -2), (-17, -10), (-14, -16)], 1):
        s.composite("PROP_Foliage_DeadTree_Danger_%02d" % i, [
            {"kind": "cylinder", "radius": 0.16, "height": 3.2, "color": (0.2, 0.22, 0.26),
             "pos": (0, 1.6, 0), "sides": 6}], pos=(x, 0, z))
    for i, (x, z, sz) in enumerate([(15, -4, 1.4), (17, -12, 1.7), (14, -18, 1.3)], 1):
        _rock(s, "PROP_Rock_Rubble_%02d" % i, (x, 0, z), sz, (0.44, 0.36, 0.3))
    for i, (x, z) in enumerate([(-3, 8), (3, 6), (4, 2), (-4, 4)], 1):
        _flower(s, "PROP_Flower_Verge_%02d" % i, (x, 0, z), (0.9, 0.82, 0.4))
    # A grand mountain range crowning the summit horizon.
    _ridge(s, "PROP_Ridge_Peaks", (0, 0, -52),
           [(-24, 22, 13), (-6, 26, 17), (12, 24, 14), (28, 20, 11)], (0.34, 0.36, 0.46))
    # --- 住满世界: mountain life (clear of the central climb) ---
    # Larks perched in the pines; a hawk wheeling high over the summit.
    _bird(s, "PROP_Fauna_Lark_01", (-9, 4.2, -2), kind="lark", rot=(0, 40, 0))
    _bird(s, "PROP_Fauna_Lark_02", (9, 4.6, -16), kind="lark", rot=(0, -50, 0))
    _bird(s, "PROP_Crow_Hawk_01", (0, 9.5, -24), kind="raptor", rot=(0, 20, 0))
    _bird(s, "PROP_Fauna_Songbird_Arbor", (6, 1.45, -0.4), kind="songbird", rot=(0, 180, 0))
    # Hares startled among the scree on the lower climb.
    for i, (x, z) in enumerate([(-5, -6), (4.5, -22)], 1):
        _critter(s, "PROP_Critter_Hare_%02d" % i, (x, 0, z), kind="hare", rot=(0, i * 70, 0))
    # Two deer grazing the high summit meadow (summit top is y=2.0).
    for i, (x, z) in enumerate([(-7, -30), (7, -31)], 1):
        _critter(s, "PROP_Fauna_Deer_%02d" % i, (x, 2.0, z), kind="deer", rot=(0, -40 + i * 80, 0))
    # Hardy alpine flowers and grass tufts along the verges and on the summit.
    for i, (x, z, k, y) in enumerate([(-6, -4, "flower", 0.0), (6, -10, "grass", 0.0),
                                      (-7, -20, "grass", 0.0), (-5, -30, "flower", 2.0),
                                      (5, -28, "flower", 2.0)], 1):
        _flora(s, "PROP_Flower_Alpine_%02d" % i, (x, y, z), kind=k, n=5)


def _dress_palace(s):
    """A formal palace garden: cypress avenue, hedges, fountain, braziers, beds."""
    for i, (x, z) in enumerate([(-6, 18), (6, 18), (-6, 12), (6, 12), (-6, 6), (6, 6)], 1):
        _pine(s, "PROP_Foliage_Cypress_%02d" % i, (x, 0, z), 5.5, (0.2, 0.36, 0.26))
    for i, (x, z) in enumerate([(-4, 20), (4, 20), (-4, 9), (4, 9)], 1):
        _lantern(s, "PROP_Lantern_Court_%02d" % i, (x, 0, z), (1.0, 0.84, 0.5))
    # Clipped hedges lining the gate court.
    for i, (x, z) in enumerate([(-7.5, 15), (7.5, 15)], 1):
        s.box("PROP_Hedge_Court_%02d" % i, (1.2, 1.3, 9), (0.22, 0.36, 0.24), (x, 0.65, 15))
    # A central fountain in the gate court.
    s.composite("PROP_Decor_Fountain", [
        {"kind": "cylinder", "radius": 2.0, "height": 0.6, "color": (0.7, 0.68, 0.6), "pos": (0, 0.3, 0), "sides": 16},
        {"kind": "cylinder", "radius": 1.6, "height": 0.5, "color": (0.5, 0.62, 0.7),
         "pos": (0, 0.55, 0), "sides": 16, "emissive": (0.1, 0.16, 0.2)},
        {"kind": "cylinder", "radius": 0.3, "height": 1.6, "color": (0.72, 0.7, 0.62), "pos": (0, 1.1, 0), "sides": 10},
        {"kind": "sphere", "radius": 0.5, "color": (0.6, 0.7, 0.78), "pos": (0, 2.0, 0), "emissive": (0.18, 0.24, 0.28), "segs": 10, "rings": 6}], pos=(0, 0, 18))
    # Flower beds flanking the hall.
    for i, (x, z, c) in enumerate([(-9, 2, (0.92, 0.5, 0.55)), (9, 2, (0.95, 0.8, 0.4)),
                                   (-9, -6, (0.7, 0.55, 0.95)), (9, -6, (0.95, 0.6, 0.45))], 1):
        _flower(s, "PROP_Flower_Bed_%02d" % i, (x, 0, z), c, (c[0]*0.4, c[1]*0.4, c[2]*0.4))
    # Festive pennant poles on the approach.
    for i, (x, z, c) in enumerate([(-8, 24, (0.8, 0.18, 0.2)), (8, 24, (0.9, 0.78, 0.2))], 1):
        s.composite("PROP_Banner_Approach_%02d" % i, [
            {"kind": "cylinder", "radius": 0.1, "height": 6, "color": (0.4, 0.38, 0.34), "pos": (0, 3, 0), "sides": 6},
            {"kind": "box", "size": (0.12, 2.0, 1.4), "color": c, "pos": (0, 4.8, 0.7),
             "emissive": (c[0]*0.4, c[1]*0.4, c[2]*0.4)}], pos=(x, 0, z))
    _ridge(s, "PROP_Ridge_Distant", (0, 0, -30), [(-22, 20, 8), (4, 24, 10), (24, 18, 7)], (0.4, 0.43, 0.52))
    # --- 住满世界: the House Beautiful as a living, praising household ---
    # Rich, festive robes for the family of the house (brighter than the road).
    house_robes = [(0.82, 0.3, 0.32), (0.3, 0.4, 0.72), (0.7, 0.6, 0.24),
                   (0.5, 0.34, 0.6), (0.86, 0.84, 0.78)]
    praise_robes = [(0.92, 0.9, 0.82), (0.95, 0.86, 0.5), (0.86, 0.88, 0.92)]
    # Two servants attending the feast table (trays raised), off the centre aisle.
    _household_figure(s, "PROP_Household_Servant_01", (-6, 0, 3), robe=(0.6, 0.5, 0.34), h=1.6, arm=True, rot=(0, -60, 0))
    _household_figure(s, "PROP_Household_Servant_02", (6, 0, -3), robe=(0.58, 0.48, 0.32), h=1.58, arm=True, rot=(0, 120, 0))
    # Family & guests gathered at the hall (non-solid clusters, off-aisle).
    _crowd(s, "PROP_Household_Crowd_Hall_01", (-8, 0, -1), rows=2, cols=2, spacing=1.2, robes=house_robes)
    _crowd(s, "PROP_Household_Crowd_Hall_02", (8, 0, 1), rows=2, cols=2, spacing=1.2, robes=house_robes)
    # A small choir lifting praise toward the balcony (hands raised).
    _crowd(s, "PROP_Household_Crowd_Choir_01", (-5, 0, -13), rows=2, cols=2, spacing=1.1, robes=praise_robes, hands_raised=True)
    _crowd(s, "PROP_Household_Crowd_Choir_02", (5, 0, -13), rows=2, cols=2, spacing=1.1, robes=praise_robes, hands_raised=True)
    # The porter's lad waiting in the gate court (beside the Watchman).
    _household_figure(s, "PROP_Household_Porter_Lad", (-5, 0, 18), robe=(0.4, 0.42, 0.5), h=1.45, rot=(0, 0, 0))
    # Peacocks strolling the cypress avenue; a loyal house-dog by the hearth.
    for i, (x, z) in enumerate([(-5, 11), (5, 8)], 1):
        _bird(s, "PROP_Fauna_Peacock_%02d" % i, (x, 0, z), kind="peacock", rot=(0, -40 + i * 80, 0))
    _fauna(s, "PROP_Sheep_HouseDog", (-12, 0, -7), kind="dog")
    # Doves perched along the garden wall / gate banners.
    for i, (x, z, y) in enumerate([(-4, 22, 8.0), (4, 22, 8.0), (-9, 18, 2.2), (9, 18, 2.2)], 1):
        _bird(s, "PROP_Dove_Court_%02d" % i, (x, y, z), kind="dove", rot=(0, i * 50, 0))


def _dress_humiliation(s):
    """A scorched battlefield ringed with black rock teeth, embers and ruin."""
    import math as _m
    for i in range(1, 11):
        ang = _m.radians(i * 36)
        x = round(_m.cos(ang) * 16, 1)
        z = round(-6 + _m.sin(ang) * 15, 1)
        h = 3.0 + (i % 4)
        s.composite("PROP_Rock_Tooth_%02d" % i, [
            {"kind": "cone", "radius": 1.0 + (i % 3) * 0.3, "height": h,
             "color": (0.16, 0.15, 0.17), "pos": (0, h / 2, 0), "sides": 6}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-10, -2), (10, -8), (-6, -16), (7, -14), (-12, -10),
                                (12, -2), (0, -22), (-4, 2)], 1):
        s.composite("PROP_Ember_Field_%02d" % i, [
            {"kind": "sphere", "radius": 0.35, "color": (1.0, 0.35, 0.12),
             "pos": (0, 0.25, 0), "emissive": (0.95, 0.28, 0.06), "segs": 8, "rings": 5}], pos=(x, 0, z))
    for i, (x, z, r) in enumerate([(-9, 4, 60), (9, 6, -50), (-7, -20, 80), (6, -18, 30)], 1):
        s.composite("PROP_Decor_BrokenWeapon_%02d" % i, [
            {"kind": "cylinder", "radius": 0.06, "height": 2.6, "color": (0.4, 0.34, 0.26),
             "pos": (0, 1.0, 0), "rot": (0, 0, r), "sides": 5},
            {"kind": "box", "size": (0.5, 0.5, 0.08), "color": (0.5, 0.5, 0.54),
             "pos": (0, 2.0, 0), "rot": (0, 0, r), "metallic": 0.8, "roughness": 0.5}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-13, 8, ), (13, 10), (-11, -22), (11, -24)], 1):
        s.composite("PROP_Foliage_Charred_%02d" % i, [
            {"kind": "cylinder", "radius": 0.18, "height": 3.0, "color": (0.12, 0.11, 0.1),
             "pos": (0, 1.5, 0), "sides": 6}], pos=(x, 0, z))
    _ridge(s, "PROP_Ridge_Brood", (0, 0, -44),
           [(-20, 22, 10), (0, 26, 13), (20, 22, 11)], (0.16, 0.14, 0.16))
    # --- 住满世界 (austere): only carrion birds dare this field ---
    for i, (x, y, z) in enumerate([(-6, 11, -6), (6, 12, -10), (0, 13, -2)], 1):
        _bird(s, "PROP_Crow_Vulture_%02d" % i, (x, y, z), kind="raptor", rot=(0, i * 80, 0))
    _fauna(s, "PROP_Crow_Carrion_01", (12, 2.0, -10), kind="bird")


def _dress_shadow(s):
    """A deeper, jagged chasm: rock teeth on the walls, snags, guiding wisps."""
    for i, (x, z, h) in enumerate([(5.2, 20, 4), (-5.2, 12, 5), (5.2, 2, 4.5),
                                   (-5.2, -8, 5), (5.2, -18, 4), (-5.2, -28, 4.5),
                                   (5.0, -34, 3.6)], 1):
        s.composite("PROP_Rock_Tooth_%02d" % i, [
            {"kind": "cone", "radius": 0.8, "height": h, "color": (0.06, 0.06, 0.1),
             "pos": (0, h / 2, 0), "sides": 6}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(3.4, 16), (-3.4, 6), (3.2, -4), (-3.2, -14),
                                (3.0, -24), (-3.0, -32)], 1):
        s.composite("PROP_Foliage_Snag_%02d" % i, [
            {"kind": "cylinder", "radius": 0.12, "height": 2.4, "color": (0.1, 0.1, 0.12),
             "pos": (0, 1.1, 0), "rot": (0, 0, 18 if x > 0 else -18), "sides": 5}], pos=(x, 0, z))
    # Faint guiding wisps just off the path (cool emissive).
    for i, z in enumerate([18, 4, -10, -22, -34], 1):
        s.composite("PROP_Flower_Wisp_%02d" % i, [
            {"kind": "sphere", "radius": 0.22, "color": (0.5, 0.62, 0.85),
             "pos": (0, 0.4, 0), "emissive": (0.4, 0.52, 0.8), "segs": 8, "rings": 5}],
            pos=(1.6 if i % 2 else -1.6, 0, z))
    # Taller broken ridgelines above the chasm walls.
    _ridge(s, "PROP_Ridge_ChasmL", (-9, 0, 0), [(0, 10, 14), (0, 8, 10)], (0.05, 0.05, 0.08))
    _ridge(s, "PROP_Ridge_ChasmR", (9, 0, 0), [(0, 10, 14), (0, 8, 10)], (0.05, 0.05, 0.08))
    # --- 住满世界 (austere): unseen things in the dark — restraint, not a zoo ---
    # A couple of bats flitting high against the chasm; nothing on the path.
    for i, (x, y, z) in enumerate([(-5, 7.0, 6), (5, 8.0, -18)], 1):
        s.composite("PROP_Critter_Bat_%02d" % i, [
            {"kind": "sphere", "radius": 0.1, "color": (0.06, 0.06, 0.08), "pos": (0, 0, 0), "segs": 6, "rings": 4},
            {"kind": "box", "size": (0.7, 0.03, 0.22), "color": (0.05, 0.05, 0.07), "pos": (0, 0, 0), "rot": (0, 0, 22)}],
            pos=(x, y, z), rot=(0, i * 60, 0))
    # Faint watching eyes peering from clefts in the valley walls (just off-path).
    for i, (x, z) in enumerate([(6.2, 2), (-6.2, -14), (6.0, -30)], 1):
        s.composite("PROP_Fauna_Eyes_%02d" % i, [
            {"kind": "sphere", "radius": 0.05, "color": (0.95, 0.75, 0.2), "pos": (-0.12, 0, 0), "segs": 5, "rings": 3, "emissive": (0.85, 0.6, 0.12)},
            {"kind": "sphere", "radius": 0.05, "color": (0.95, 0.75, 0.2), "pos": (0.12, 0, 0), "segs": 5, "rings": 3, "emissive": (0.85, 0.6, 0.12)}],
            pos=(x, 1.6, z))


def _dress_vanity(s):
    """A teeming fairground: extra booths, bunting, lanterns, wares, more crowd."""
    palette = [(0.9, 0.2, 0.3), (0.95, 0.78, 0.2), (0.3, 0.7, 0.5), (0.6, 0.3, 0.75),
               (0.2, 0.66, 0.74), (0.92, 0.5, 0.16)]
    for i, (x, z) in enumerate([(-15, 12), (15, 12), (-17, 4), (17, 4),
                                (-15, -4), (15, -4), (-13, 18), (13, 18)], 1):
        c = palette[i % len(palette)]
        s.composite("PROP_Decor_Booth_%02d" % i, [
            {"kind": "box", "size": (2.6, 2.2, 2.6), "color": _shade(c, 0.8), "pos": (0, 1.1, 0)},
            {"kind": "pyramid", "size": (3.2, 3.2), "height": 1.0, "color": c, "pos": (0, 2.7, 0)}], pos=(x, 0, z))
    # Bunting garlands strung on poles along the street.
    for i, z in enumerate([16, 8, 0, -8], 1):
        flags = []
        for k in range(-3, 4):
            flags.append({"kind": "box", "size": (0.5, 0.5, 0.08),
                          "color": palette[(k + i) % len(palette)],
                          "pos": (k * 0.9, 4.4 - abs(k) * 0.12, 0),
                          "emissive": (0.12, 0.1, 0.04)})
        s.composite("PROP_Banner_Bunting_%02d" % i, [
            {"kind": "cylinder", "radius": 0.08, "height": 5.0, "color": (0.4, 0.36, 0.3), "pos": (-3.4, 2.5, 0), "sides": 6},
            {"kind": "cylinder", "radius": 0.08, "height": 5.0, "color": (0.4, 0.36, 0.3), "pos": (3.4, 2.5, 0), "sides": 6}] + flags, pos=(0, 0, z))
    for i, (x, z) in enumerate([(-3.5, 14), (3.5, 14), (-3.5, 2), (3.5, 2)], 1):
        _lantern(s, "PROP_Lantern_Fair_%02d" % i, (x, 0, z), (1.0, 0.78, 0.4))
    for i, (x, z) in enumerate([(-10, 9), (10, 9), (-12, -1), (12, -1)], 1):
        s.composite("PROP_Decor_Wares_%02d" % i, [
            {"kind": "box", "size": (1.0, 1.0, 1.0), "color": (0.5, 0.36, 0.24), "pos": (0, 0.5, 0)},
            {"kind": "box", "size": (0.8, 0.8, 0.8), "color": (0.56, 0.4, 0.26), "pos": (0.3, 1.3, 0.1), "rot": (0, 20, 0)},
            {"kind": "sphere", "radius": 0.4, "color": palette[i % len(palette)], "pos": (-0.3, 1.2, 0.2), "segs": 8, "rings": 5}], pos=(x, 0, z))
    _crowd2 = [part for x in (-1, 0, 1) for z in (0, 1)
               for part in (
                   {"kind": "cylinder", "radius": 0.32, "height": 1.5,
                    "color": (0.4, 0.34, 0.42), "pos": (x * 0.95, 0.75, z * 1.05), "sides": 7},
                   {"kind": "sphere", "radius": 0.25, "color": (0.72, 0.6, 0.52),
                    "pos": (x * 0.95, 1.66, z * 1.05), "segs": 7, "rings": 4})]
    for i, (x, z) in enumerate([(-13, 6), (13, 6), (-8, 16), (8, 16)], 1):
        s.composite("PROP_Crowd_Extra_%02d" % i, _crowd2, pos=(x, 0, z))


def _dress_doubting(s):
    """A grim castle ground: dead garden, gravestones, ravens; lush By-Path meadow."""
    for i, (x, z) in enumerate([(-9, -2), (9, -6), (-11, -14), (10, -16), (-7, -20),
                                (8, 0)], 1):
        s.composite("PROP_Foliage_DeadOak_%02d" % i, [
            {"kind": "cylinder", "radius": 0.26, "height": 3.6, "color": (0.16, 0.14, 0.12),
             "pos": (0, 1.8, 0), "sides": 6},
            {"kind": "cylinder", "radius": 0.1, "height": 1.8, "color": (0.16, 0.14, 0.12),
             "pos": (0.7, 3.0, 0), "rot": (0, 0, 50), "sides": 4},
            {"kind": "cylinder", "radius": 0.1, "height": 1.6, "color": (0.16, 0.14, 0.12),
             "pos": (-0.6, 2.7, 0.1), "rot": (0, 0, -46), "sides": 4}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-6, -4), (6, -10), (-8, -16), (7, -18)], 1):
        s.composite("PROP_Rock_Grave_%02d" % i, [
            {"kind": "box", "size": (0.7, 1.1, 0.2), "color": (0.3, 0.3, 0.33),
             "pos": (0, 0.55, 0), "rot": (4, 0, i * 3 - 6)}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-3, -8), (3, -12), (-2, 1)], 1):
        s.composite("PROP_Crow_Yard_%02d" % i, [
            {"kind": "sphere", "radius": 0.16, "color": (0.05, 0.05, 0.07), "pos": (0, 0, 0), "segs": 7, "rings": 4},
            {"kind": "cone", "radius": 0.1, "height": 0.3, "color": (0.05, 0.05, 0.07), "pos": (0, 0.1, 0.18), "sides": 5}], pos=(x, 1.1, z))
    # The By-Path meadow (behind spawn) deceptively soft and green.
    for i, (x, z) in enumerate([(-9, 22), (9, 24), (-12, 18), (12, 20)], 1):
        _bush(s, "PROP_Bush_Bypath_%02d" % i, (x, 0, z), 0.8, (0.32, 0.46, 0.28))
    for i, (x, z) in enumerate([(-5, 26), (5, 28), (-3, 22)], 1):
        _flower(s, "PROP_Flower_Bypath_%02d" % i, (x, 0, z), (0.9, 0.85, 0.4))
    _ridge(s, "PROP_Ridge_Storm", (0, 0, -34), [(-20, 22, 11), (2, 26, 14), (22, 20, 10)], (0.14, 0.14, 0.18))
    # --- 住满世界: grim castle fauna vs. the By-Path meadow's false sweetness ---
    # Vultures wheeling over the bailey; toads hunched in the dank corners.
    for i, (x, y, z) in enumerate([(-4, 12.5, -8), (5, 13.5, -10), (0, 14.0, -4)], 1):
        _bird(s, "PROP_Crow_Vulture_%02d" % i, (x, y, z), kind="raptor", rot=(0, i * 70, 0))
    for i, (x, z) in enumerate([(-9, -4), (9, -14)], 1):
        _critter(s, "PROP_Critter_Toad_%02d" % i, (x, 0.2, z), kind="toad", rot=(0, i * 90, 0))
    # The By-Path meadow (behind, z>18) looks deceptively lovely: larks, bright
    # butterflies, a hare — beauty that lures the weary off the King's highway.
    _bird(s, "PROP_Fauna_Lark_01", (-8, 1.0, 24), kind="lark", rot=(0, 40, 0))
    _bird(s, "PROP_Fauna_Lark_02", (8, 1.0, 22), kind="lark", rot=(0, -50, 0))
    for i, (x, z) in enumerate([(-5, 26), (5, 28), (-3, 22)], 1):
        _critter(s, "PROP_Butterfly_Bypath_%02d" % i, (x, 1.4, z), kind="butterfly",
                 rot=(0, i * 70, 0), col=(0.95, 0.75, 0.3))
    _critter(s, "PROP_Critter_Hare_01", (7, 0, 20), kind="hare", rot=(0, -30, 0))


def _dress_delectable(s):
    """Abundant high pasture: groves, flocks, wildflowers, dry-stone walls, peaks."""
    for i, (x, z, h) in enumerate([(-18, -4, 5.2), (-15, -10, 4.6), (16, -2, 5.4),
                                   (18, -12, 4.8), (-20, 6, 5.0), (20, 8, 5.2),
                                   (14, 14, 4.4)], 1):
        _tree(s, "PROP_Foliage_Pasture_%02d" % i, (x, 0, z), h, (0.22, 0.48, 0.27), (0.36, 0.26, 0.16))
    for i, (x, z) in enumerate([(-4, 14), (-1, 16), (-6, 13), (3, 18), (6, 15),
                                (1, 12), (-8, -6), (8, -8), (4, -4)], 1):
        s.composite("PROP_Sheep_Flock_%02d" % i, [
            {"kind": "sphere", "radius": 0.46, "color": (0.92, 0.92, 0.88), "pos": (0, 0.6, 0), "segs": 8, "rings": 5},
            {"kind": "sphere", "radius": 0.2, "color": (0.3, 0.28, 0.28), "pos": (0, 0.72, 0.46), "segs": 7, "rings": 4}], pos=(x, 0, z))
    for i, (x, z, c) in enumerate([(-3, 4, (0.95, 0.85, 0.4)), (3, 6, (0.9, 0.5, 0.7)),
                                   (-5, 0, (0.7, 0.6, 0.95)), (5, -2, (0.95, 0.6, 0.4)),
                                   (-2, 8, (0.95, 0.8, 0.45)), (4, 2, (0.85, 0.5, 0.75))], 1):
        _flower(s, "PROP_Flower_Pasture_%02d" % i, (x, 0, z), c)
    # A dry-stone boundary wall stepping across the pasture.
    for i, (x, z) in enumerate([(-13, 2), (-10, 2), (-7, 2)], 1):
        s.box("PROP_Rock_Wall_%02d" % i, (3.0, 1.0, 0.7), (0.6, 0.58, 0.5), (x, 0.5, z))
    _ridge(s, "PROP_Ridge_SnowPeaks", (0, 0, -46),
           [(-24, 24, 15), (-4, 28, 19), (16, 26, 16), (32, 20, 12)], (0.62, 0.66, 0.74))


def _dress_enchanted(s):
    """A drowsy enchanted wood: glowing blooms, drooping willows, fireflies, mist."""
    for i, (x, z) in enumerate([(-8, 20), (8, 14), (-10, 4), (9, -2), (-7, -12),
                                (8, -22), (-9, -30), (7, 24)], 1):
        # Drooping willow: low wide canopy.
        h = 4.6
        s.composite("PROP_Foliage_Willow_%02d" % i, [
            {"kind": "cylinder", "radius": 0.22, "height": h * 0.6, "color": (0.36, 0.3, 0.2), "pos": (0, h * 0.3, 0), "sides": 6},
            {"kind": "sphere", "radius": 2.0, "color": (0.4, 0.56, 0.36), "pos": (0, h * 0.7, 0), "segs": 10, "rings": 6},
            {"kind": "sphere", "radius": 1.3, "color": (0.46, 0.62, 0.4), "pos": (1.2, h * 0.55, 0.4), "segs": 9, "rings": 5}], pos=(x, 0, z))
    blooms = [(0.98, 0.6, 0.82), (0.82, 0.72, 0.98), (0.7, 0.95, 0.8), (0.98, 0.82, 0.6)]
    for i, (x, z) in enumerate([(-4, 22), (4, 18), (-5, 10), (5, 6), (-3, -2), (4, -8),
                                (-4, -16), (5, -24), (-3, -32), (3, 26)], 1):
        c = blooms[i % len(blooms)]
        _flower(s, "PROP_Flower_Dream_%02d" % i, (x, 0, z), c, (c[0]*0.55, c[1]*0.5, c[2]*0.6))
    # Luminous mushroom rings and fireflies.
    for i, (x, z) in enumerate([(-6, 16), (6, 2), (-7, -18), (6, -28)], 1):
        s.composite("PROP_Flower_Mushroom_%02d" % i, [
            {"kind": "cylinder", "radius": 0.12, "height": 0.5, "color": (0.85, 0.85, 0.78), "pos": (0, 0.25, 0), "sides": 6},
            {"kind": "sphere", "radius": 0.34, "color": (0.7, 0.9, 0.7), "pos": (0, 0.6, 0), "emissive": (0.4, 0.6, 0.45), "segs": 8, "rings": 5}], pos=(x, 0, z))
    for i in range(1, 9):
        x = round(((i * 3) % 11) - 5, 1)
        z = round(28 - i * 7, 1)
        s.composite("PROP_Flower_Firefly_%02d" % i, [
            {"kind": "sphere", "radius": 0.1, "color": (0.95, 0.95, 0.6),
             "pos": (0, 0, 0), "emissive": (0.9, 0.88, 0.4), "segs": 6, "rings": 4}], pos=(x, 1.6, z))
    _ridge(s, "PROP_Ridge_DreamWood", (0, 0, -48), [(-20, 22, 8), (2, 24, 10), (20, 20, 8)], (0.38, 0.42, 0.34))
    # --- 住满世界: drowsy dream-fauna (keep the sleepy, dangerous hush) ---
    # A deer standing half-asleep in the soft field; an owl on the dream-arbor.
    _critter(s, "PROP_Fauna_Deer_01", (7, 0, -12), kind="deer", rot=(0, -120, 0))
    _bird(s, "PROP_Fauna_Owl_01", (-8.8, 3.1, -8), kind="owl", rot=(0, 60, 0))
    # Pale moths drifting among the soporific dream-blooms (cool, dreamy tints).
    moth = [(0.85, 0.86, 0.95), (0.95, 0.86, 0.7), (0.82, 0.92, 0.86)]
    for i, (x, z) in enumerate([(-5, 18), (5, 6), (-7, -2), (7, -18), (-4, -32)], 1):
        _critter(s, "PROP_Butterfly_Moth_%02d" % i, (x, 1.5, z), kind="butterfly",
                 rot=(0, i * 58, 0), col=moth[i % len(moth)])
    # A few more fireflies sparking low over the field.
    for i in range(1, 5):
        x = round(((i * 4) % 9) - 4, 1)
        _critter(s, "PROP_Firefly_Extra_%02d" % i, (x, 1.5, 24 - i * 12), kind="midges")
    # A hare folded in the soft grass patch.
    _critter(s, "PROP_Critter_Hare_01", (-6, 0.1, -5), kind="hare", rot=(0, 40, 0))


def _dress_river(s):
    """Reedy near shore, lilypads, and the radiant far City shore with spires."""
    for i, (x, z) in enumerate([(-12, 16), (12, 14), (-16, 20), (16, 18), (-10, 12)], 1):
        _reedclump(s, "PROP_Reeds_Shore_%02d" % i, (x, 0, z), (0.34, 0.44, 0.32), 1.9)
    for i, (x, z) in enumerate([(-14, 18), (14, 20)], 1):
        s.composite("PROP_Foliage_Willow_%02d" % i, [
            {"kind": "cylinder", "radius": 0.22, "height": 2.6, "color": (0.34, 0.28, 0.2), "pos": (0, 1.3, 0), "sides": 6},
            {"kind": "sphere", "radius": 1.8, "color": (0.36, 0.5, 0.34), "pos": (0, 3.0, 0), "segs": 10, "rings": 6}], pos=(x, 0, z))
    # Lilypads drifting on the dark water (non-solid).
    for i, (x, z) in enumerate([(-5, 2), (5, -4), (-3, -10), (4, 6), (-6, -16), (6, -12)], 1):
        s.composite("PROP_Flower_Lily_%02d" % i, [
            {"kind": "cylinder", "radius": 0.5, "height": 0.06, "color": (0.2, 0.4, 0.3), "pos": (0, 0.05, 0), "sides": 8},
            {"kind": "sphere", "radius": 0.16, "color": (0.95, 0.92, 0.8), "pos": (0.1, 0.16, 0), "emissive": (0.4, 0.38, 0.3), "segs": 7, "rings": 4}], pos=(x, 0.02, z))
    # The far celestial shore: a row of glowing spires beyond the far bank.
    for i, (x, h) in enumerate([(-12, 9), (-6, 13), (0, 11), (6, 15), (12, 10)], 1):
        s.composite("PROP_Distant_Spire_%02d" % i, [
            {"kind": "cone", "radius": 1.0, "height": h, "color": (0.98, 0.92, 0.72),
             "pos": (0, h / 2, 0), "emissive": (0.8, 0.72, 0.46), "sides": 8}], pos=(x, 0, -42))
    for i, (x, z) in enumerate([(-4, -30), (4, -30)], 1):
        _lantern(s, "PROP_Lantern_FarBank_%02d" % i, (x, 0, z), (1.0, 0.92, 0.66))
    # --- 住满世界: river life (all walk-through; clear of the central wade) ---
    # Herons stalking the reedy near shallows; one mid-shore sentinel.
    for i, (x, z) in enumerate([(-11, 15), (12, 17), (-15, 12), (14, 13)], 1):
        _bird(s, "PROP_Fauna_Heron_%02d" % i, (x, 0, z), kind="heron",
              rot=(0, 90 if x < 0 else -90, 0))
    # Ducks paddling the near calm water, swans gliding the far calm water.
    for i, (x, z) in enumerate([(-6, 10), (7, 8), (-8, 6)], 1):
        _bird(s, "PROP_Fauna_Duck_%02d" % i, (x, 0.9, z), kind="duck", rot=(0, i * 40, 0))
    for i, (x, z) in enumerate([(-7, -24), (8, -26), (-5, -28)], 1):
        _bird(s, "PROP_Fauna_Swan_%02d" % i, (x, 0.85, z), kind="swan", rot=(0, -120 + i * 40, 0))
    # A kingfisher flashing on a near reed; songbirds on the bank.
    _bird(s, "PROP_Fauna_Kingfisher_01", (-12, 1.3, 16), kind="kingfisher")
    for i, (x, z) in enumerate([(13, 14), (-14, 19)], 1):
        _bird(s, "PROP_Fauna_Lark_%02d" % i, (x, 1.1, z), kind="songbird")
    # Dragonflies skimming the surface; fish breaking it (to the sides).
    for i, (x, z) in enumerate([(-6, 4), (6, -2), (-5, -12), (7, 2), (-7, -18)], 1):
        _critter(s, "PROP_Critter_Dragonfly_%02d" % i, (x, 1.25, z), kind="dragonfly", rot=(0, i * 55, 0))
    for i, (x, z) in enumerate([(-8, 0), (8, -8), (-6, -16)], 1):
        _critter(s, "PROP_Critter_Fish_%02d" % i, (x, 0.97, z), kind="fish")
    # Marsh flora threading both banks.
    for i, (x, z, k) in enumerate([(-13, 18, "fern"), (13, 19, "fern"), (-10, 13, "flower"),
                                   (11, 12, "flower"), (-12, -28, "fern"), (12, -30, "flower")], 1):
        _flora(s, "PROP_Flower_Bank_%02d" % i, (x, 0, z), kind=k, n=5)
    # Doves rising before the radiant far shore (toward the Celestial City).
    for i in range(1, 5):
        _bird(s, "PROP_Dove_FarShore_%02d" % i, (round((i - 2.5) * 2.2, 1), 3.0 + (i % 2) * 0.7, -34),
              kind="dove", rot=(0, i * 30, 0))


def _dress_celestial(s):
    """A radiant golden approach: pillared avenue, blossom, statues, more spires."""
    for i, (x, z) in enumerate([(-5, 12), (5, 12), (-5, 4), (5, 4), (-5, -4), (5, -4)], 1):
        s.composite("PROP_Decor_Pillar_%02d" % i, [
            {"kind": "cylinder", "radius": 0.5, "height": 5.5, "color": (0.95, 0.9, 0.74),
             "pos": (0, 2.75, 0), "emissive": (0.4, 0.36, 0.24), "sides": 12},
            {"kind": "sphere", "radius": 0.55, "color": (1.0, 0.95, 0.7), "pos": (0, 5.7, 0),
             "emissive": (0.85, 0.78, 0.5), "segs": 10, "rings": 6}], pos=(x, 0, z))
    for i, (x, z) in enumerate([(-7, 14), (7, 14), (-7, 0), (7, 0)], 1):
        _tree(s, "PROP_Foliage_Blossom_%02d" % i, (x, 0, z), 4.2, (0.95, 0.8, 0.86), (0.5, 0.4, 0.3))
    # Gilded welcoming statues flanking the stair.
    for i, x in enumerate([-6, 6], 1):
        s.composite("PROP_Decor_Statue_%02d" % i, [
            {"kind": "box", "size": (1.4, 0.8, 1.4), "color": (0.9, 0.84, 0.66), "pos": (0, 0.4, 0)},
            {"kind": "cylinder", "radius": 0.4, "height": 2.4, "color": (0.96, 0.9, 0.66),
             "pos": (0, 1.9, 0), "emissive": (0.5, 0.44, 0.28), "sides": 10},
            {"kind": "sphere", "radius": 0.4, "color": (0.98, 0.92, 0.7), "pos": (0, 3.3, 0),
             "emissive": (0.6, 0.54, 0.34), "segs": 9, "rings": 5}], pos=(x, 0, -8))
    # Doves rising before the gate.
    for i in range(1, 6):
        s.composite("PROP_Crow_Dove_%02d" % i, [
            {"kind": "sphere", "radius": 0.13, "color": (0.98, 0.96, 0.92),
             "pos": (0, 0, 0), "emissive": (0.4, 0.4, 0.38), "segs": 7, "rings": 4}],
            pos=(round((i - 3) * 1.6, 1), 3.4 + (i % 2) * 0.6, -10))
    # Extra spires of the City rising beyond the wall.
    for i, (x, h) in enumerate([(-13, 14), (13, 16), (-7, 19), (7, 21)], 1):
        s.composite("PROP_Distant_Spire_%02d" % i, [
            {"kind": "cone", "radius": 1.1, "height": h, "color": (0.97, 0.9, 0.66),
             "pos": (0, h / 2, 0), "emissive": (0.7, 0.62, 0.38), "sides": 8}], pos=(x, 0, -34))


def _dress_wilderness(s):
    """The waste, but living: hardy roadside trees, wildflowers and small animals
    soften the barren in-between road. Clutter to the verges, the road kept clear."""
    # Hardy living trees + windswept scrub pines clinging to the verges.
    for i, (x, z, h) in enumerate([(-8, 18, 4.2), (9, 8, 4.6), (-10, -8, 3.8),
                                   (10, -26, 4.4), (-7, -34, 3.6)], 1):
        _tree(s, "PROP_Foliage_ScrubTree_%02d" % i, (x, 0, z), h,
              (0.34, 0.42, 0.24), (0.36, 0.28, 0.18))
    for i, (x, z, h) in enumerate([(11, -2, 4.8), (-11, -20, 4.4)], 1):
        _pine(s, "PROP_Foliage_ScrubPine_%02d" % i, (x, 0, z), h, (0.22, 0.36, 0.24))
    # Hardy roadside wildflowers + dry grass tussocks.
    for i, (x, z, c) in enumerate([(-4, 12, (0.95, 0.82, 0.4)), (4, 4, (0.9, 0.7, 0.85)),
                                   (-5, -2, (0.95, 0.6, 0.4)), (5, -16, (0.92, 0.86, 0.5)),
                                   (-4, -28, (0.85, 0.6, 0.8)), (4, 22, (0.95, 0.8, 0.45))], 1):
        _flora(s, "PROP_Flower_Wayside_%02d" % i, (x, 0, z), kind="flower", n=6)
    for i, (x, z) in enumerate([(-6, 6), (6, -6), (-7, -24), (7, 16)], 1):
        _flora(s, "PROP_Grass_Waste_%02d" % i, (x, 0, z), kind="grass", n=4)
    # Small animals: a fox, hares, larks, butterflies, and crows over the waste.
    _critter(s, "PROP_Fauna_Fox_01", (9, 0, 4), kind="fox", rot=(0, -120, 0))
    for i, (x, z) in enumerate([(-5, -4), (5, 26), (-6, -30)], 1):
        _critter(s, "PROP_Critter_Hare_%02d" % i, (x, 0, z), kind="hare", rot=(0, i * 80, 0))
    for i, (x, z) in enumerate([(-7, 14), (8, -10)], 1):
        _bird(s, "PROP_Fauna_Lark_%02d" % i, (x, 1.0, z), kind="lark", rot=(0, i * 60, 0))
    for i, (x, z) in enumerate([(-4, 12), (4, 4), (5, -16)], 1):
        _critter(s, "PROP_Butterfly_Waste_%02d" % i, (x, 1.3, z), kind="butterfly",
                 rot=(0, i * 70, 0), col=(0.95, 0.78, 0.35))
    _fauna(s, "PROP_Crow_Waste_01", (7, 4.0, -20), kind="bird")
    _bird(s, "PROP_Crow_Wheeling_01", (-3, 8.0, -10), kind="raptor", rot=(0, 40, 0))


_DRESSERS = {
    "wilderness_road": _dress_wilderness,
    "slough_of_despond": _dress_slough,
    "wicket_gate": _dress_wicket,
    "cross_and_tomb": _dress_cross,
    "interpreter_house": _dress_interpreter,
    "hill_difficulty": _dress_hill,
    "palace_beautiful": _dress_palace,
    "valley_humiliation": _dress_humiliation,
    "valley_shadow_death": _dress_shadow,
    "vanity_fair": _dress_vanity,
    "doubting_castle": _dress_doubting,
    "delectable_mountains": _dress_delectable,
    "enchanted_ground": _dress_enchanted,
    "river_of_death": _dress_river,
    "celestial_city": _dress_celestial,
}


def _build_dressed(cid):
    s = _BASE_SCENES[cid]()
    dresser = _DRESSERS.get(cid)
    if dresser is not None:
        dresser(s)
    return s


SCENES = {cid: (lambda cid=cid: _build_dressed(cid)) for cid in _BASE_SCENES}
