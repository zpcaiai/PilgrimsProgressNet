"""Coverage + structural validation for the generated chapter GLBs.

For every chapter it checks that each name from the spec's "Technical Objects"
list is present as a node, then re-parses the GLB container (magic, chunks,
accessors) to confirm it is well-formed. Exit code is non-zero on any failure so
this can gate CI.

    python3 tools/scene_gen/verify_scenes.py
"""

import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene_defs import SCENES  # noqa: E402

OUT_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "assets", "imported_scenes"))

# Canonical "Technical Objects" names from Batch 1 + Batch 2 specs.
EXPECTED = {
    "city_of_destruction": [
        "SPAWN_Player_Start", "ENV_City_Ground", "ENV_City_Road_Main",
        "ENV_City_TownSquare", "ENV_City_OuterRoad", "PROP_PlayerHouse",
        "PROP_Book", "PROP_CityGate", "PROP_House_01", "PROP_House_02",
        "PROP_House_03", "PROP_House_04", "PROP_House_05", "PROP_House_06",
        "PROP_WarningBell", "NPC_Wife", "NPC_Children", "NPC_Evangelist",
        "NPC_Obstinate", "NPC_Pliable", "TRIGGER_ReadBook",
        "TRIGGER_ObstinateConfrontation", "TRIGGER_PliableJoin",
        "TRIGGER_Exit_WildernessRoad", "VFX_SmokeColumn_01",
        "VFX_SmokeColumn_02", "VFX_DistantRedGlow", "LIGHT_DistantWarningRed",
        "LIGHT_CityDimMain", "CAM_CityOverview", "CAM_BookCloseup",
        "CAM_CityGateExit"],
    "wilderness_road": [
        "SPAWN_Player_Start", "ENV_Wilderness_Ground",
        "ENV_Wilderness_NarrowRoad", "ENV_Wilderness_RoadBend",
        "ENV_Wilderness_RoadSlope", "PROP_Berm_Left", "PROP_Berm_Right",
        "PROP_CityBackdrop", "PROP_DistantLightMarker",
        "PROP_Signpost_WicketGate", "PROP_WaysideStone", "PROP_RockCluster_01",
        "PROP_RockCluster_02", "PROP_RockCluster_03", "PROP_DeadTree_01",
        "PROP_DeadTree_02", "PROP_DeadTree_03", "PROP_BrokenFence_01",
        "PROP_DryBrush_01", "PROP_DryBrush_02", "NPC_Pliable", "NPC_Obstinate",
        "TRIGGER_ObstinateReturns", "TRIGGER_PliableRoadDialogue",
        "TRIGGER_CityVoices", "TRIGGER_FixEyesOnLight",
        "TRIGGER_Exit_SloughOfDespond", "VFX_WindDust_01",
        "VFX_DistantLightGlow", "VFX_CityEmberSmoke", "LIGHT_DistantGateGlow",
        "LIGHT_CityEmberRed", "LIGHT_WildernessMain", "CAM_WildernessOverview",
        "CAM_CityBehindView", "CAM_SloughReveal"],
    "slough_of_despond": [
        "SPAWN_Player_Start", "ENV_Slough_Ground", "ENV_Slough_MudBasin",
        "ENV_Slough_SafeStonePath", "ENV_Slough_ExitSlope", "PROP_BrokenPlank_01",
        "PROP_BrokenPlank_02", "PROP_DeadReeds_01", "PROP_DeadReeds_02",
        "PROP_PromiseStone_Hope_01", "PROP_PromiseStone_Faith_01",
        "PROP_PromiseStone_Perseverance_01", "NPC_Pliable", "NPC_Help",
        "TRIGGER_PliableLeaves", "TRIGGER_HelpAppears", "TRIGGER_Exit_WicketGate",
        "COL_MudZone_Shallow_01", "COL_MudZone_Shallow_02", "COL_MudZone_Deep_01",
        "COL_MudZone_Deep_02", "COL_FalseGround_01", "VFX_FogVolume_Main",
        "VFX_MudBubbles_01", "VFX_MudBubbles_02", "VFX_PromiseGlow_01",
        "LIGHT_SloughDimMain", "LIGHT_PromiseStoneGlow_01",
        "LIGHT_PromiseStoneGlow_02", "CAM_SloughOverview", "CAM_PliableLeaves",
        "CAM_HelpAppears", "CAM_ExitReveal"],
    "wicket_gate": [
        "SPAWN_Player_Start", "ENV_Wicket_Path", "ENV_Wicket_CliffEdges",
        "ENV_Wicket_GatePlatform", "PROP_WicketGate", "PROP_StonePost_Left",
        "PROP_StonePost_Right", "PROP_GateDoor", "NPC_Goodwill",
        "TRIGGER_GateKnock", "TRIGGER_Exit_CrossAndTomb", "COL_ArrowPressureZone",
        "VFX_ArrowEmitter_01", "VFX_ArrowEmitter_02", "VFX_GateGlow",
        "LIGHT_GateWarmLight", "LIGHT_WicketDimMain", "CAM_WicketGateOverview",
        "CAM_GateKnockCloseup", "CAM_GoodwillPull"],
    "cross_and_tomb": [
        "SPAWN_Player_Start", "ENV_Cross_Ground", "ENV_Cross_HillPath",
        "ENV_Cross_Hilltop", "ENV_Cross_TombSlope", "PROP_Cross", "PROP_Tomb",
        "PROP_RollingBurden", "PROP_NewGarmentMarker", "PROP_ScrollMarker",
        "PROP_SealMarker", "TRIGGER_CrossEvent", "TRIGGER_DemoEnd",
        "PATH_BurdenRoll_Start", "PATH_BurdenRoll_Mid", "PATH_BurdenRoll_End",
        "VFX_CrossLight", "VFX_BurdenDust", "VFX_NewGarmentGlow", "VFX_SkyClear",
        "LIGHT_CrossSunrise", "LIGHT_CrossEventGlow", "CAM_CrossOverview",
        "CAM_BurdenFall", "CAM_TombRoll", "CAM_DemoEnd"],
    "interpreter_house": [
        "SPAWN_Player_Start", "ENV_InterpreterHouse_Floor",
        "ENV_InterpreterHouse_MainHall", "ENV_InterpreterHouse_DustRoom",
        "ENV_InterpreterHouse_FireRoom", "ENV_InterpreterHouse_CageRoom",
        "ENV_InterpreterHouse_NarrowRoom", "ENV_InterpreterHouse_ExitHall",
        "NPC_Interpreter", "PROP_DustRoom_Broom", "PROP_DustRoom_WaterBowl",
        "PROP_DustRoom_DustCloud", "PROP_FireWall_Fire", "PROP_FireWall_HiddenOil",
        "PROP_CagedMan_Cage", "PROP_CagedMan_Figure", "PROP_NarrowRoom_Door_Left",
        "PROP_NarrowRoom_Door_Right", "PROP_NarrowRoom_CenterLight",
        "TRIGGER_DustRoomStart", "TRIGGER_FireRoomStart", "TRIGGER_CageRoomStart",
        "TRIGGER_NarrowRoomStart", "TRIGGER_Exit_HillDifficulty",
        "COL_DustCloudZone", "COL_CageFearZone", "COL_FalseDoor_Left",
        "COL_FalseDoor_Right", "VFX_DustCloud", "VFX_FireHiddenGlow",
        "VFX_CageColdMist", "VFX_NarrowRoomLight", "LIGHT_InterpreterMainWarm",
        "LIGHT_DustRoomDim", "LIGHT_FireRoomGlow", "LIGHT_CageRoomCold",
        "CAM_InterpreterHallOverview", "CAM_DustRoom", "CAM_FireBehindWall",
        "CAM_CagedMan", "CAM_NarrowRoom"],
    "hill_difficulty": [
        "SPAWN_Player_Start", "ENV_Hill_Base", "ENV_Hill_DifficultyPath",
        "ENV_Hill_DangerPath", "ENV_Hill_DestructionPath", "ENV_Hill_Summit",
        "PROP_PathSign_Difficulty", "PROP_PathSign_Danger",
        "PROP_PathSign_Destruction", "PROP_ArborBench", "PROP_SummitMarker",
        "PROP_DistantPalaceSilhouette", "NPC_Timorous", "NPC_Mistrust",
        "TRIGGER_PathChoiceFork", "TRIGGER_DangerPathReturn",
        "TRIGGER_DestructionPathCollapse", "TRIGGER_ArborRest",
        "TRIGGER_Exit_PalaceBeautiful", "COL_FalsePath_Danger",
        "COL_FalsePath_Destruction", "COL_SteepSlopeZone_01",
        "COL_SteepSlopeZone_02", "COL_ArborSleepZone",
        "VFX_FalsePathShimmer_Danger", "VFX_FalsePathShimmer_Destruction",
        "VFX_SummitLight", "VFX_ArborSleepMist", "LIGHT_HillMain",
        "LIGHT_SummitGold", "CAM_HillForkOverview", "CAM_HillClimb",
        "CAM_ArborRest", "CAM_SummitReveal"],
    "palace_beautiful": [
        "SPAWN_Player_Start", "ENV_Palace_Ground", "ENV_Palace_GateCourt",
        "ENV_Palace_MainHall", "ENV_Palace_RestRoom", "ENV_Palace_ArmorRoom",
        "ENV_Palace_Balcony", "PROP_PalaceGate", "PROP_DiningTable", "PROP_Bed",
        "PROP_ArmorStand", "PROP_Sword", "PROP_Shield", "PROP_ValleyView",
        "NPC_Watchman", "NPC_Discretion", "NPC_Prudence", "NPC_Piety",
        "NPC_Charity", "TRIGGER_PalaceDoorExamination", "TRIGGER_RestAtPalace",
        "TRIGGER_ReceiveArmor", "TRIGGER_Exit_ValleyHumiliation",
        "VFX_HearthWarmth", "VFX_ArmorGlow", "VFX_BalconyValleyMist",
        "LIGHT_PalaceWarmMain", "LIGHT_ArmorRoomGlow", "CAM_PalaceExterior",
        "CAM_DoorExamination", "CAM_MainHall", "CAM_ArmorRoom",
        "CAM_ValleyReveal"],
    "valley_humiliation": [
        "SPAWN_Player_Start", "ENV_Humiliation_DescentPath",
        "ENV_Humiliation_ValleyFloor", "ENV_Humiliation_BossArena",
        "ENV_Humiliation_ExitPath", "PROP_BattleStone_01", "PROP_BattleStone_02",
        "PROP_BrokenSpear_01", "PROP_ArmorLightMarker", "NPC_Apollyon",
        "ENEMY_ApollyonBoss", "TRIGGER_ApollyonIntro", "TRIGGER_BossStart",
        "TRIGGER_BossVictory", "TRIGGER_Exit_ShadowValley", "COL_BossArenaBounds",
        "COL_DespairFlameZone", "COL_ShameFieldZone", "VFX_ApollyonEntrance",
        "VFX_FearRoarWave", "VFX_AccusationBolt", "VFX_DespairFlame",
        "VFX_VictoryLight", "LIGHT_HumiliationMain", "LIGHT_BossRed",
        "LIGHT_VictoryGold", "CAM_ValleyDescent", "CAM_ApollyonIntro",
        "CAM_BossFightWide", "CAM_BossVictory"],
    "valley_shadow_death": [
        "SPAWN_Player_Start", "ENV_ShadowValley_Ground",
        "ENV_ShadowValley_NarrowPath", "ENV_ShadowValley_LeftWall",
        "ENV_ShadowValley_RightWall", "ENV_ShadowValley_ExitSlope",
        "PROP_FaintPathMarker_01", "PROP_FaintPathMarker_02",
        "PROP_FaintPathMarker_03", "PROP_FaintPathMarker_04",
        "PROP_BrokenSkullRock_01", "PROP_DeadBranch_01", "TRIGGER_PrayerPrompt",
        "TRIGGER_FalseVoice_Left", "TRIGGER_FalseVoice_Right",
        "TRIGGER_ShadowCollapseCheck", "TRIGGER_Exit_VerticalSliceEnd",
        "COL_FearZone_01", "COL_FearZone_02", "COL_FalseVoiceZone_Left",
        "COL_FalseVoiceZone_Right", "COL_NarrowCliffEdge", "COL_DarknessDeepZone",
        "VFX_DarkFog_Main", "VFX_Whisper_Left", "VFX_Whisper_Right",
        "VFX_PrayerLight", "VFX_ExitDawn", "LIGHT_PlayerSmallLight",
        "LIGHT_PrayerLight", "LIGHT_ExitDawn", "CAM_ShadowValleyEntry",
        "CAM_DarkPath", "CAM_FalseVoice", "CAM_ExitDawnReveal"],
    "vanity_fair": [
        "SPAWN_Player_Start", "ENV_VanityFair_Ground", "ENV_VanityFair_MainStreet",
        "ENV_VanityFair_MarketSquare", "ENV_VanityFair_TrialSquare",
        "ENV_VanityFair_ExitRoad", "PROP_Stall_Applause", "PROP_Stall_Comfort",
        "PROP_Stall_Influence", "PROP_Banner_Red_01", "PROP_Banner_Gold_01",
        "PROP_TrialPlatform", "PROP_CrowdCluster_01", "PROP_CrowdCluster_02",
        "PROP_BrokenPilgrimSign", "NPC_Faithful", "NPC_Hopeful",
        "NPC_Merchant_Applause", "NPC_Merchant_Comfort", "NPC_Merchant_Influence",
        "NPC_TrialJudge", "TRIGGER_EnterVanityFair", "TRIGGER_FaithfulTrial",
        "TRIGGER_FaithfulLost", "TRIGGER_HopefulJoins", "TRIGGER_Exit_DoubtingCastle",
        "COL_VanityApplauseZone", "COL_ComfortTentZone", "COL_InfluenceStageZone",
        "COL_CrowdPressureZone", "VFX_VanityGlitter", "VFX_CrowdNoisePulse",
        "VFX_TrialSpotlight", "VFX_HopefulJoinLight", "LIGHT_VanityFairMain",
        "LIGHT_TrialSpotlight", "LIGHT_HopefulJoin", "CAM_VanityEntrance",
        "CAM_MarketWide", "CAM_TrialScene", "CAM_FaithfulLost", "CAM_HopefulJoins"],
    "doubting_castle": [
        "SPAWN_Player_Start", "ENV_Doubting_ByPathMeadow", "ENV_Doubting_CastleExterior",
        "ENV_Doubting_Cell", "ENV_Doubting_DarkHall", "ENV_Doubting_EscapePath",
        "PROP_CellDoor", "PROP_CellChains", "PROP_ScrollMemory", "PROP_PromiseKey",
        "PROP_CastleGate", "PROP_StormCloudMarker", "NPC_Hopeful", "NPC_GiantDespair",
        "NPC_Diffidence", "TRIGGER_ByPathChoice", "TRIGGER_Capture",
        "TRIGGER_CellDespairStart", "TRIGGER_FindPromiseKey", "TRIGGER_UsePromiseKey",
        "TRIGGER_Exit_DelectableMountains", "COL_DespairCellZone", "COL_ShameWhisperZone",
        "COL_CastleDarkHall", "VFX_StormRain", "VFX_CellDarkness", "VFX_PromiseKeyGlow",
        "VFX_CastleDoorUnlock", "LIGHT_CellCold", "LIGHT_PromiseKeyGlow",
        "CAM_ByPathMeadow", "CAM_Capture", "CAM_CellAwake", "CAM_PromiseKeyReveal",
        "CAM_Escape"],
    "delectable_mountains": [
        "SPAWN_Player_Start", "ENV_Mountains_Pasture", "ENV_Mountains_ShepherdCamp",
        "ENV_Mountains_ViewpointPath", "ENV_Mountains_CelestialView",
        "ENV_Mountains_ExitPath", "PROP_ShepherdTent", "PROP_ShepherdMap",
        "PROP_Viewpoint_CelestialCity", "PROP_Viewpoint_ErrorCliff",
        "PROP_Viewpoint_ShortcutGrave", "PROP_DistantCelestialCity",
        "PROP_PastureStone_01", "PROP_PastureTree_01", "NPC_Shepherd_Knowledge",
        "NPC_Shepherd_Experience", "NPC_Shepherd_Watchful", "NPC_Shepherd_Sincere",
        "NPC_Hopeful", "TRIGGER_CelestialView", "TRIGGER_ErrorCliffView",
        "TRIGGER_ShortcutGraveView", "TRIGGER_ReceiveShepherdMap",
        "TRIGGER_Exit_EnchantedGround", "COL_ErrorCliffWarningZone",
        "VFX_CelestialCityDistantGlow", "VFX_MountainWind", "VFX_MapGlow",
        "LIGHT_MountainSun", "LIGHT_CelestialDistantGlow", "CAM_MountainEntrance",
        "CAM_CelestialView", "CAM_ErrorCliff", "CAM_ShepherdWarning",
        "CAM_ExitToEnchantedGround"],
    "enchanted_ground": [
        "SPAWN_Player_Start", "ENV_Enchanted_Ground", "ENV_Enchanted_MainPath",
        "ENV_Enchanted_SoftField", "ENV_Enchanted_ExitSlope", "PROP_DreamFlower_01",
        "PROP_DreamFlower_02", "PROP_SoftGrassPatch_01", "PROP_AwakeStone_01",
        "PROP_AwakeStone_02", "PROP_ShepherdMapUsePoint", "PROP_TestimonyMarker_Cross",
        "PROP_TestimonyMarker_Slough", "PROP_TestimonyMarker_Castle", "NPC_Hopeful",
        "NPC_Ignorance_Optional", "TRIGGER_EnterEnchantedGround",
        "TRIGGER_TestimonyConversation", "TRIGGER_HopefulWake", "TRIGGER_Exit_RiverOfDeath",
        "COL_SleepZone_01", "COL_SleepZone_02", "COL_DreamFlowerZone",
        "COL_SoftGrassRestZone", "VFX_SleepMist", "VFX_DreamPollen", "VFX_AwakeStoneGlow",
        "LIGHT_EnchantedSoftMain", "LIGHT_AwakeStoneGlow", "CAM_EnchantedEntrance",
        "CAM_DrowsyField", "CAM_TestimonyWalk", "CAM_ExitToRiver"],
    "river_of_death": [
        "SPAWN_Player_Start", "ENV_River_NearBank", "ENV_River_WaterPlane",
        "ENV_River_DeepChannel", "ENV_River_FarBank", "ENV_River_CityApproach",
        "PROP_RiverStone_01", "PROP_RiverStone_02", "PROP_FarBankLight",
        "PROP_DistantCelestialGate", "NPC_Hopeful", "NPC_ShiningOne_01",
        "NPC_ShiningOne_02", "TRIGGER_EnterRiver", "TRIGGER_MidRiverFear",
        "TRIGGER_RiverMemoryRecall", "TRIGGER_Exit_CelestialCity", "COL_RiverFearZone",
        "COL_RiverDeepZone", "COL_RiverMemoryPromptZone", "VFX_RiverMist",
        "VFX_CityGlowAcrossRiver", "VFX_MemoryLight_Cross", "VFX_MemoryLight_Key",
        "VFX_WaterShallowing", "LIGHT_RiverMoon", "LIGHT_CelestialAcrossRiver",
        "CAM_RiverApproach", "CAM_MidRiver", "CAM_HopefulEncouragement", "CAM_FarBank"],
    "celestial_city": [
        "SPAWN_Player_Start", "ENV_Celestial_FarBank", "ENV_Celestial_ApproachRoad",
        "ENV_Celestial_GatePlatform", "ENV_Celestial_CityInteriorHint",
        "PROP_CelestialGate", "PROP_GateArch_Left", "PROP_GateArch_Right",
        "PROP_CityLightPillar_01", "PROP_CityLightPillar_02", "PROP_JourneyReviewMarker",
        "NPC_Hopeful", "NPC_ShiningOne_01", "NPC_ShiningOne_02", "NPC_Gatekeeper",
        "TRIGGER_JourneyReview", "TRIGGER_EnterCelestialCity", "TRIGGER_EndCredits",
        "VFX_CelestialGateGlow", "VFX_CityLightRays", "VFX_FinalWelcomeParticles",
        "LIGHT_CelestialMain", "LIGHT_GateGlow", "LIGHT_CityInteriorGlow",
        "CAM_CelestialApproach", "CAM_GateOpen", "CAM_JourneyReview", "CAM_FinalEntry",
        "CAM_EndCredits"],
}


def validate_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, total = struct.unpack("<III", data[:12])
    assert magic == 0x46546C67, "bad GLB magic"
    assert ver == 2, "bad GLB version"
    assert total == len(data), "GLB length mismatch"
    off = 12
    jlen, jtype = struct.unpack("<II", data[off:off + 8])
    off += 8
    assert jtype == 0x4E4F534A, "first chunk must be JSON"
    gltf = json.loads(data[off:off + jlen])
    off += jlen
    blen, btype = struct.unpack("<II", data[off:off + 8])
    off += 8
    assert btype == 0x004E4942, "second chunk must be BIN"
    assert blen == len(data) - off, "BIN chunk length mismatch"
    for a in gltf["accessors"]:
        assert "bufferView" in a
        if a.get("type") == "VEC3":
            assert "min" in a and "max" in a, "POSITION accessor needs min/max"
    return gltf


def main():
    fails = 0
    for cid, fn in SCENES.items():
        scene = fn()
        names = set(scene.node_names())
        expected = EXPECTED.get(cid, [])
        missing = [n for n in expected if n not in names]
        path = os.path.join(OUT_DIR, cid + ".glb")
        status = "OK"
        detail = ""
        if missing:
            status = "MISSING"
            detail = " missing=" + ",".join(missing)
            fails += 1
        try:
            if os.path.exists(path):
                gltf = validate_glb(path)
                detail += " (glb nodes=%d meshes=%d)" % (
                    len(gltf["nodes"]), len(gltf["meshes"]))
            else:
                status = "NO_FILE"
                fails += 1
        except Exception as e:  # noqa: BLE001
            status = "BAD_GLB"
            detail += " " + str(e)
            fails += 1
        print("%-24s %-8s %3d/%3d names%s"
              % (cid, status, len(expected) - len(missing), len(expected), detail))
    print("-" * 60)
    if fails:
        print("FAIL: %d chapter(s) with problems" % fails)
        sys.exit(1)
    print("PASS: all %d chapters cover their Technical Objects and parse."
          % len(SCENES))


if __name__ == "__main__":
    main()
