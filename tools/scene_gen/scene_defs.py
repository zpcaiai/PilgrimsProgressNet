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
def _road(s, name, length, z_center, width=6.0, color=(0.30, 0.26, 0.22)):
    s.box(name, (width, 0.12, length), color, (0, 0.06, z_center))


def _wall(s, name, size, pos, color=(0.46, 0.42, 0.38)):
    s.box(name, size, color, pos)


def _cottage(s, name, pos, size=(5, 3.2, 5), wall=(0.5, 0.43, 0.4),
             roof=(0.33, 0.23, 0.17)):
    w, h, d = size
    s.composite(name, [
        {"kind": "box", "size": size, "color": wall, "pos": (0, h / 2, 0)},
        {"kind": "pyramid", "size": (w + 0.5, d + 0.5),
         "height": 1.7, "color": roof, "pos": (0, h + 0.85, 0)},
        # plank door + two warm-lit windows on the +Z face
        {"kind": "box", "size": (1.0, 1.9, 0.18), "color": (0.28, 0.2, 0.14),
         "pos": (0, 0.95, d / 2 + 0.03)},
        {"kind": "box", "size": (0.8, 0.8, 0.14), "color": (0.96, 0.86, 0.56),
         "pos": (-w / 2 + 0.95, h * 0.62, d / 2 + 0.03),
         "emissive": (0.4, 0.34, 0.18)},
        {"kind": "box", "size": (0.8, 0.8, 0.14), "color": (0.96, 0.86, 0.56),
         "pos": (w / 2 - 0.95, h * 0.62, d / 2 + 0.03),
         "emissive": (0.4, 0.34, 0.18)},
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


# ===========================================================================
# CHAPTER 1 - City of Destruction
# ===========================================================================
def build_city_of_destruction():
    s = Scene("city_of_destruction")
    gray = (0.28, 0.25, 0.22)
    s.ground("ENV_City_Ground", (44, 74), gray)
    _road(s, "ENV_City_Road_Main", 60, -2, 6, (0.22, 0.19, 0.17))
    s.box("ENV_City_TownSquare", (14, 0.1, 14), (0.30, 0.27, 0.24), (0, 0.05, 12))
    _road(s, "ENV_City_OuterRoad", 16, -27, 5, (0.20, 0.17, 0.15))

    _cottage(s, "PROP_PlayerHouse", (-7, 0, 6), (5, 3.2, 5),
             (0.52, 0.44, 0.42), (0.34, 0.24, 0.18))
    _cottage(s, "PROP_House_01", (9, 0, 8))
    _cottage(s, "PROP_House_02", (10, 0, -2), (4.5, 3.0, 4.5))
    _cottage(s, "PROP_House_03", (-10, 0, -4), (4.5, 3.2, 4.5))
    _cottage(s, "PROP_House_04", (12, 0, 14), (4.2, 2.8, 4.2))
    _cottage(s, "PROP_House_05", (-12, 0, 12), (4.2, 3.0, 4.2))
    _cottage(s, "PROP_House_06", (11, 0, -10), (4.6, 3.1, 4.6))

    s.composite("PROP_Book", [
        {"kind": "box", "size": (0.6, 0.9, 0.6), "color": (0.3, 0.22, 0.16),
         "pos": (0, 0.45, 0)},
        {"kind": "box", "size": (0.7, 0.12, 0.5), "color": (0.85, 0.8, 0.7),
         "pos": (0, 0.96, 0), "emissive": (0.2, 0.18, 0.12)},
    ], pos=(1.4, 0, 4))

    s.composite("PROP_CityGate", [
        {"kind": "box", "size": (2, 6, 2), "color": (0.4, 0.38, 0.35),
         "pos": (-4, 3, 0)},
        {"kind": "box", "size": (2, 6, 2), "color": (0.4, 0.38, 0.35),
         "pos": (4, 3, 0)},
        {"kind": "box", "size": (10.5, 1.2, 1.6), "color": (0.34, 0.31, 0.28),
         "pos": (0, 6.4, 0)},
    ], pos=(0, 0, -19))

    s.composite("PROP_WarningBell", [
        {"kind": "box", "size": (0.25, 4.0, 0.25), "color": (0.35, 0.3, 0.25),
         "pos": (0, 2.0, 0)},
        {"kind": "cone", "radius": 0.6, "height": 0.9, "color": (0.6, 0.5, 0.25),
         "pos": (0, 4.2, 0), "emissive": (0.15, 0.12, 0.05)},
    ], pos=(6, 0, 2))
    s.box("PROP_Crate_01", (1.0, 1.0, 1.0), (0.42, 0.34, 0.24), (4.5, 0.5, 6))
    s.cylinder("PROP_Barrel_01", 0.6, 1.2, (0.36, 0.28, 0.2), (-4, 0.6, 7))

    s.marker("NPC_Wife", (-3.0, 0, 5.0))
    s.marker("NPC_Children", (-3.8, 0, 5.6))
    s.marker("NPC_Evangelist", (0, 0, -4))
    s.marker("NPC_Obstinate", (3, 0, -13))
    s.marker("NPC_Pliable", (-3, 0, -13))

    s.zone("TRIGGER_ReadBook", (3, 3, 3), (1.4, 1.5, 4))
    s.zone("TRIGGER_ObstinateConfrontation", (8, 3, 4), (3, 1.5, -13))
    s.zone("TRIGGER_PliableJoin", (8, 3, 4), (-3, 1.5, -13))
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
         "pos": (0, 5, 0), "emissive": (0.9, 0.82, 0.55)},
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

    # Rocks, dead trees, broken fence, dry brush -- the parched in-between land.
    s.composite("PROP_RockCluster_01", [
        {"kind": "box", "size": (1.6, 1.2, 1.4), "color": (0.5, 0.47, 0.42), "pos": (0, 0.6, 0)},
        {"kind": "box", "size": (1.0, 0.8, 1.0), "color": (0.45, 0.42, 0.38), "pos": (1.0, 0.4, 0.4)},
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
    s.ground("ENV_Slough_Ground", (40, 96), (0.22, 0.26, 0.22))
    s.box("ENV_Slough_MudBasin", (26, 0.3, 50), (0.2, 0.24, 0.2), (0, -0.1, -18))
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

    s.box("PROP_StonePost_Left", (1.4, 5, 1.4), (0.45, 0.43, 0.4), (-2.4, 2.5, -8))
    s.box("PROP_StonePost_Right", (1.4, 5, 1.4), (0.45, 0.43, 0.4), (2.4, 2.5, -8))
    s.composite("PROP_WicketGate", [
        {"kind": "box", "size": (5.6, 1.0, 1.0), "color": (0.4, 0.34, 0.26),
         "pos": (0, 5.2, 0)},
    ], pos=(0, 0, -8))
    s.box("PROP_GateDoor", (3.0, 4.2, 0.3), (0.5, 0.38, 0.24), (0, 2.1, -8),
          emissive=(0.18, 0.12, 0.05))

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
    s.ground("ENV_Cross_Ground", (44, 60), (0.4, 0.46, 0.34))
    # Flat ground -> gentle flush ramp -> low hilltop, all continuously walkable.
    s.ramp("ENV_Cross_HillPath", 8, 12, 1.0, (0.5, 0.46, 0.34), (0, 0, -2))
    s.box("ENV_Cross_Hilltop", (22, 1.0, 16), (0.42, 0.48, 0.36), (0, 0.5, -22))
    s.box("ENV_Cross_TombSlope", (10, 0.1, 7), (0.4, 0.42, 0.34), (-7, 1.05, -18))

    s.composite("PROP_Cross", [
        {"kind": "box", "size": (0.5, 5.0, 0.5), "color": (0.45, 0.34, 0.22),
         "pos": (0, 2.5, 0)},
        {"kind": "box", "size": (2.6, 0.5, 0.5), "color": (0.45, 0.34, 0.22),
         "pos": (0, 3.6, 0)},
    ], pos=(0, 1.0, -20))
    s.composite("PROP_Tomb", [
        {"kind": "box", "size": (4, 3, 4), "color": (0.5, 0.5, 0.52),
         "pos": (0, 1.5, 0)},
        {"kind": "cylinder", "radius": 1.2, "height": 0.5, "color": (0.4, 0.4, 0.42),
         "pos": (1.6, 0.6, 1.6), "rot": (90, 0, 0)},
    ], pos=(-7, 1.0, -18))
    s.box("PROP_RollingBurden", (1.2, 1.1, 1.2), (0.3, 0.26, 0.22),
          (0, 1.6, -18.5))
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
    s.box("ENV_InterpreterHouse_MainHall", (12, 0.1, 12), (0.36, 0.3, 0.24),
          (0, 0.06, 0))
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
    _wall(s, "ENV_InterpreterHouse_WallN", (40, 4, 0.4), (0, 2, -22), wall)
    _wall(s, "ENV_InterpreterHouse_WallS", (40, 4, 0.4), (0, 2, 14), wall)

    s.marker("NPC_Interpreter", (0, 0, -3))
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
    s.zone("TRIGGER_Exit_HillDifficulty", (5, 4, 2), (0, 1.5, -23))
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
    s.cone("PROP_SummitMarker", 0.6, 2.4, (0.9, 0.8, 0.4), (0, 3.2, -29),
           emissive=(0.6, 0.55, 0.25))
    s.box("PROP_DistantPalaceSilhouette", (16, 9, 2), (0.3, 0.3, 0.4),
          (0, 12, -46))

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
    s.box("ENV_Palace_GateCourt", (16, 0.1, 12), (0.5, 0.47, 0.42), (0, 0.06, 16))
    s.box("ENV_Palace_MainHall", (18, 0.1, 16), (0.5, 0.46, 0.4), (0, 0.06, 0))
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
        {"kind": "box", "size": (5, 0.3, 1.6), "color": (0.4, 0.3, 0.2),
         "pos": (0, 1.0, 0)}], pos=(0, 0, 0))
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
    s.ground("ENV_Humiliation_ValleyFloor", (54, 70), (0.34, 0.36, 0.3))
    s.box("ENV_Humiliation_DescentPath", (8, 0.12, 18), (0.4, 0.4, 0.34), (0, 0.06, 22))
    s.box("ENV_Humiliation_BossArena", (34, 0.1, 34), (0.32, 0.3, 0.28),
          (0, 0.06, -6))
    s.box("ENV_Humiliation_ExitPath", (8, 0.12, 14), (0.36, 0.36, 0.32), (0, 0.06, -30))

    s.composite("PROP_BattleStone_01", [
        {"kind": "box", "size": (2.2, 1.6, 2.0), "color": (0.46, 0.44, 0.4),
         "pos": (0, 0.8, 0)}], pos=(-12, 0, -4))
    s.composite("PROP_BattleStone_02", [
        {"kind": "box", "size": (2.4, 1.8, 2.2), "color": (0.46, 0.44, 0.4),
         "pos": (0, 0.9, 0)}], pos=(12, 0, -10))
    s.cylinder("PROP_BrokenSpear_01", 0.08, 2.6, (0.4, 0.34, 0.26),
               (-6, 0.5, 2), rot=(0, 0, 70))
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

    for i, z in enumerate((24, 8, -8, -24), start=1):
        s.composite("PROP_FaintPathMarker_%02d" % i, [
            {"kind": "cylinder", "radius": 0.3, "height": 0.5,
             "color": (0.6, 0.62, 0.7), "pos": (0, 0.25, 0),
             "emissive": (0.3, 0.32, 0.4)}], pos=(0, 0, z))
    s.composite("PROP_BrokenSkullRock_01", [
        {"kind": "box", "size": (1.2, 1.0, 1.2), "color": (0.3, 0.3, 0.32),
         "pos": (0, 0.5, 0)}], pos=(4, 0, 12))
    s.composite("PROP_DeadBranch_01", [
        {"kind": "cylinder", "radius": 0.12, "height": 2.4,
         "color": (0.2, 0.18, 0.16), "pos": (0, 1.0, 0), "rot": (0, 0, 40)}],
        pos=(-4, 0, -6))

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
    s.ground("ENV_VanityFair_Ground", (50, 70), (0.4, 0.3, 0.34))
    _road(s, "ENV_VanityFair_MainStreet", 60, 0, 6, (0.5, 0.4, 0.45))
    s.box("ENV_VanityFair_MarketSquare", (24, 0.1, 16), (0.5, 0.42, 0.5), (0, 0.06, 6))
    s.box("ENV_VanityFair_TrialSquare", (16, 0.1, 14), (0.45, 0.4, 0.48), (0, 0.06, -14))
    _road(s, "ENV_VanityFair_ExitRoad", 14, -28, 5, (0.4, 0.34, 0.38))

    s.composite("PROP_Stall_Applause", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.8, 0.7, 0.2), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.9, 0.2, 0.3), "pos": (0, 3.0, 0)}], pos=(-8, 0, 8))
    s.composite("PROP_Stall_Comfort", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.6, 0.4, 0.7), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.4, 0.3, 0.7), "pos": (0, 3.0, 0)}], pos=(8, 0, 8))
    s.composite("PROP_Stall_Influence", [
        {"kind": "box", "size": (3, 2.4, 3), "color": (0.3, 0.7, 0.4), "pos": (0, 1.2, 0)},
        {"kind": "pyramid", "size": (3.6, 3.6), "height": 1.2, "color": (0.2, 0.6, 0.5), "pos": (0, 3.0, 0)}], pos=(0, 0, 12))
    s.box("PROP_Banner_Red_01", (0.2, 4, 1.6), (0.8, 0.15, 0.2), (-11, 2.5, 2), emissive=(0.3, 0.05, 0.08))
    s.box("PROP_Banner_Gold_01", (0.2, 4, 1.6), (0.85, 0.7, 0.2), (11, 2.5, 2), emissive=(0.3, 0.25, 0.06))
    s.box("PROP_TrialPlatform", (8, 1.0, 6), (0.45, 0.4, 0.4), (0, 0.5, -14))
    # Crowd figures: a robed body (cylinder) topped with a head (sphere).
    _crowd = [part
              for x in (-1, 0, 1) for z in (0, 1)
              for part in (
                  {"kind": "cylinder", "radius": 0.34, "height": 1.5,
                   "color": (0.42, 0.36, 0.42), "pos": (x * 1.0, 0.75, z * 1.1)},
                  {"kind": "sphere", "radius": 0.26, "color": (0.72, 0.6, 0.52),
                   "pos": (x * 1.0, 1.68, z * 1.1)})]
    s.composite("PROP_CrowdCluster_01", _crowd, pos=(-6, 0, -10))
    s.composite("PROP_CrowdCluster_02", _crowd, pos=(6, 0, -10))
    s.composite("PROP_BrokenPilgrimSign", [
        {"kind": "box", "size": (0.2, 1.4, 0.2), "color": (0.4, 0.34, 0.24), "pos": (0, 0.7, 0), "rot": (0, 0, 20)}], pos=(10, 0, 18))

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
    _wall(s, "ENV_Doubting_CellWallL", (0.5, 4, 10), (-5, 2, -8), stone)
    _wall(s, "ENV_Doubting_CellWallR", (0.5, 4, 10), (5, 2, -8), stone)

    s.box("PROP_CellDoor", (3, 3.4, 0.3), (0.4, 0.34, 0.2), (0, 1.7, -3), emissive=(0.1, 0.08, 0.04))
    s.composite("PROP_CellChains", [
        {"kind": "cylinder", "radius": 0.06, "height": 1.6, "color": (0.2, 0.2, 0.22), "pos": (0, 0.8, 0)}], pos=(-3, 0, -10))
    s.box("PROP_ScrollMemory", (0.5, 0.12, 0.4), (0.85, 0.8, 0.7), (2, 0.4, -10), emissive=(0.25, 0.22, 0.16))
    s.composite("PROP_PromiseKey", [
        {"kind": "box", "size": (0.16, 0.6, 0.16), "color": (0.95, 0.85, 0.4), "pos": (0, 0.3, 0), "emissive": (0.7, 0.6, 0.2)}], pos=(0, 0.5, -10))
    _merlons = [{"kind": "box", "size": (0.9, 0.9, 1.7), "color": stone,
                 "pos": (dx, 9.3, 0)} for dx in (-3.5, -1.75, 0, 1.75, 3.5)]
    s.composite("PROP_CastleGate", [
        {"kind": "box", "size": (1.4, 8, 1.4), "color": stone, "pos": (-3.5, 4, 0)},
        {"kind": "box", "size": (1.4, 8, 1.4), "color": stone, "pos": (3.5, 4, 0)},
        {"kind": "box", "size": (8.4, 1.4, 1.6), "color": stone, "pos": (0, 8.4, 0)},
    ] + _merlons, pos=(0, 0, 4))
    s.marker("PROP_StormCloudMarker", (0, 12, 14))

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
    s.box("PROP_DistantCelestialCity", (18, 8, 2), (0.85, 0.85, 0.7), (0, 10, -40), emissive=(0.5, 0.5, 0.4))
    s.composite("PROP_PastureStone_01", [
        {"kind": "box", "size": (1.4, 1.0, 1.2), "color": (0.5, 0.5, 0.46), "pos": (0, 0.5, 0)}], pos=(8, 0, 6))
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

    s.cone("PROP_DreamFlower_01", 0.5, 1.0, (0.95, 0.6, 0.8), (-5, 0.5, 18), emissive=(0.4, 0.25, 0.35))
    s.cone("PROP_DreamFlower_02", 0.5, 1.0, (0.8, 0.7, 0.95), (5, 0.5, 6), emissive=(0.35, 0.3, 0.45))
    s.box("PROP_SoftGrassPatch_01", (4, 0.1, 4), (0.55, 0.7, 0.45), (-6, 0.1, -6))
    s.cylinder("PROP_AwakeStone_01", 0.5, 0.5, (0.7, 0.72, 0.8), (0, 0.25, 10), emissive=(0.35, 0.36, 0.42))
    s.cylinder("PROP_AwakeStone_02", 0.5, 0.5, (0.7, 0.72, 0.8), (0, 0.25, -16), emissive=(0.35, 0.36, 0.42))
    s.marker("PROP_ShepherdMapUsePoint", (0, 1.0, 2))
    s.box("PROP_TestimonyMarker_Cross", (0.4, 1.4, 0.4), (0.8, 0.7, 0.4), (-3, 0.7, 0))
    s.box("PROP_TestimonyMarker_Slough", (0.4, 1.4, 0.4), (0.6, 0.6, 0.4), (3, 0.7, -10))
    s.box("PROP_TestimonyMarker_Castle", (0.4, 1.4, 0.4), (0.5, 0.5, 0.55), (-3, 0.7, -22))

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

    s.composite("PROP_RiverStone_01", [
        {"kind": "box", "size": (1.4, 0.6, 1.4), "color": (0.4, 0.42, 0.44), "pos": (0, 0.3, 0)}], pos=(-3, 0, 4))
    s.composite("PROP_RiverStone_02", [
        {"kind": "box", "size": (1.4, 0.6, 1.4), "color": (0.4, 0.42, 0.44), "pos": (0, 0.3, 0)}], pos=(3, 0, -14))
    s.cone("PROP_FarBankLight", 1.0, 3.0, (1.0, 0.95, 0.75), (0, 1.5, -30), emissive=(0.9, 0.85, 0.6))
    s.box("PROP_DistantCelestialGate", (12, 9, 2), (0.95, 0.9, 0.75), (0, 6, -44), emissive=(0.7, 0.66, 0.5))

    s.marker("NPC_Hopeful", (1.5, 0, 14))
    s.marker("NPC_ShiningOne_01", (-2, 0, -30))
    s.marker("NPC_ShiningOne_02", (2, 0, -30))

    s.zone("TRIGGER_EnterRiver", (10, 4, 3), (0, 2, 12))
    s.zone("TRIGGER_MidRiverFear", (12, 4, 4), (0, 2, -6))
    s.zone("TRIGGER_RiverMemoryRecall", (12, 4, 4), (0, 2, -12))
    s.zone("TRIGGER_Exit_CelestialCity", (10, 4, 2), (0, 1.5, -36))
    s.zone("COL_RiverFearZone", (24, 4, 10), (0, 2, 2), color=(0.1, 0.12, 0.25, 0.4))
    s.zone("COL_RiverDeepZone", (24, 4, 10), (0, 2, -10), color=(0.05, 0.07, 0.2, 0.5))
    s.zone("COL_RiverMemoryPromptZone", (24, 4, 6), (0, 2, -14), color=(0.2, 0.2, 0.35, 0.3))

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
    s.box("ENV_Celestial_FarBank", (40, 1.0, 14), (0.5, 0.5, 0.45), (0, 0.0, 20))
    _road(s, "ENV_Celestial_ApproachRoad", 40, 0, 8, (0.85, 0.82, 0.7))
    s.box("ENV_Celestial_GatePlatform", (16, 0.3, 12), (0.9, 0.88, 0.78), (0, 0.1, -16))
    s.box("ENV_Celestial_CityInteriorHint", (30, 16, 3), (0.95, 0.93, 0.8), (0, 8, -26), emissive=(0.7, 0.68, 0.55))

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
    s.marker("PROP_JourneyReviewMarker", (0, 1.5, 0))

    s.marker("NPC_Hopeful", (1.6, 0, 6))
    s.marker("NPC_ShiningOne_01", (-2, 0, -8))
    s.marker("NPC_ShiningOne_02", (2, 0, -8))
    s.marker("NPC_Gatekeeper", (0, 0, -16))

    s.zone("TRIGGER_JourneyReview", (8, 4, 4), (0, 2, 0))
    s.zone("TRIGGER_EnterCelestialCity", (8, 4, 3), (0, 2, -16))
    s.zone("TRIGGER_EndCredits", (10, 4, 3), (0, 2, -22))

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
SCENES = {
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
