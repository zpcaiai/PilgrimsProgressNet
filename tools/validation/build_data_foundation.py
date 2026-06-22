"""Phase 0-1 data-foundation builder (reproducible, idempotent).

Brings the res://data tree up to the Batch 1-4 schema WITHOUT discarding the
existing, already-coherent chapter/quest content:

  * adds `imported_scene_path` to every chapter JSON (only field they lacked),
  * writes the three route files (full / mvp / vertical-slice),
  * creates placeholder JSON for the data categories that did not exist yet
    (spiritual_events, interactables, hazards, items, companions) and a missing
    enemy, only when a file is absent (never clobbers hand-authored data).

Run:  python3 tools/validation/build_data_foundation.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "data"))


def _read(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write("\n")


def _write_if_absent(path, obj):
    if os.path.exists(path):
        return False
    _write(path, obj)
    return True


CHAPTER_ORDER = [
    "city_of_destruction", "wilderness_road", "slough_of_despond", "wicket_gate",
    "cross_and_tomb", "interpreter_house", "hill_difficulty", "palace_beautiful",
    "valley_humiliation", "valley_shadow_death", "vanity_fair", "doubting_castle",
    "delectable_mountains", "enchanted_ground", "river_of_death", "celestial_city",
]


# ---------------------------------------------------------------------------
def add_imported_scene_paths():
    changed = []
    for cid in CHAPTER_ORDER:
        path = os.path.join(DATA, "chapters", cid + ".json")
        if not os.path.exists(path):
            continue
        data = _read(path)
        want = "res://assets/imported_scenes/%s.glb" % cid
        if data.get("imported_scene_path") != want:
            data["imported_scene_path"] = want
            _write(path, data)
            changed.append(cid)
    return changed


def write_routes():
    systems = [
        "EventBus", "GameState", "ChapterManager", "DialogueManager",
        "SpiritualStateManager", "QuestManager", "SaveManager", "DataValidator",
    ]
    _write(os.path.join(DATA, "route", "full_route.json"), {
        "id": "full_route",
        "title": "Burden Fallen: Full Pilgrim Route",
        "start_chapter": "city_of_destruction",
        "end_chapter": "celestial_city",
        "completion_flag": "journey_completed",
        "chapters": CHAPTER_ORDER,
        "required_global_systems": systems,
    })
    _write(os.path.join(DATA, "route", "mvp_route.json"), {
        "id": "mvp_route",
        "title": "Burden Fallen Demo Route",
        "start_chapter": "city_of_destruction",
        "end_chapter": "cross_and_tomb",
        "completion_flag": "mvp_completed",
        "chapters": CHAPTER_ORDER[:5],
        "required_global_systems": systems,
    })
    _write(os.path.join(DATA, "route", "vertical_slice_route.json"), {
        "id": "vertical_slice_route",
        "title": "Burden Fallen Vertical Slice Route",
        "start_chapter": "city_of_destruction",
        "end_chapter": "valley_shadow_death",
        "completion_flag": "completed_vertical_slice",
        "chapters": CHAPTER_ORDER[:10],
        "required_global_systems": systems,
    })
    return ["full_route", "mvp_route", "vertical_slice_route"]


ITEMS = {
    "burden": ("Burden", "story_state", "The weight of conviction carried until the Cross.", True),
    "scroll": ("Scroll", "story_item", "Assurance received at the Cross.", False),
    "seal": ("Seal", "story_item", "A mark of belonging set on the forehead.", False),
    "new_garment": ("New Garment", "equipment", "Clean raiment given in place of rags.", True),
    "armor": ("Armor", "equipment", "Preparation for accusation, fear, and conflict.", True),
    "sword": ("Sword", "equipment", "The Word, answered against the accuser.", True),
    "shield": ("Shield", "equipment", "Faith that quenches the fiery darts.", True),
    "promise_key": ("Promise Key", "key_item", "A remembered promise that opens despair's prison.", False),
    "shepherd_map": ("Shepherd Map", "guidance_item", "Keeps the pilgrim watchful through sleepy ground.", False),
    "final_seal": ("Final Seal", "story_state", "The token of arrival at the Celestial City.", False),
    "promise_stone": ("Promise Stone", "consumable_interactable", "A stone bearing a line of hope; single use.", False),
}

COMPANIONS = {
    "hopeful": {
        "id": "hopeful", "display_name": "Hopeful", "type": "companion",
        "join_flag": "hopeful_joined", "leave_flag": "",
        "special_state": "has_companion_hopeful", "core_effects": {"hope": 5},
        "abilities": ["encourage_in_despair", "testimony_dialogue",
                      "wake_player_in_enchanted_ground", "support_river_crossing"],
        "interventions": [
            {"id": "doubting_castle_despair",
             "trigger": {"chapter": "doubting_castle", "despair_min": 70},
             "dialogue_id": "hopeful_cell_encouragement",
             "effects": {"hope": 10, "despair": -10}},
            {"id": "enchanted_ground_sleep",
             "trigger": {"chapter": "enchanted_ground", "sleepiness_min": 80},
             "dialogue_id": "hopeful_keep_awake",
             "effects": {"watchfulness": 10, "hope": 5}},
            {"id": "river_fear",
             "trigger": {"chapter": "river_of_death", "fear_min": 70},
             "dialogue_id": "river_memory_recall",
             "effects": {"hope": 10, "fear": -10}},
        ],
    },
    "faithful": {
        "id": "faithful", "display_name": "Faithful", "type": "companion",
        "join_flag": "faithful_witnessed", "leave_flag": "faithful_lost",
        "special_state": "remembered_faithful", "core_effects": {},
        "abilities": ["witness_at_vanity"], "interventions": [],
    },
    "pliable": {
        "id": "pliable", "display_name": "Pliable", "type": "companion",
        "join_flag": "pliable_joined", "leave_flag": "pliable_left",
        "special_state": "walked_with_pliable", "core_effects": {},
        "abilities": ["shallow_enthusiasm"], "interventions": [],
    },
}

HAZARDS = {
    "mud_zone_shallow": {"type": "mud", "movement_multiplier": 0.7,
                         "effects_per_tick": {"despair": 1, "weariness": 1}},
    "mud_zone_deep": {"type": "mud", "movement_multiplier": 0.45,
                      "effects_per_tick": {"despair": 2, "fear": 1, "hope": -1},
                      "collapse_threshold": {"despair": 100}},
    "false_ground": {"type": "false_ground", "effects_on_enter": {"despair": 8, "fear": 5}},
    "arrow_pressure_zone": {"type": "projectile_pressure",
                            "effects_per_tick": {"fear": 5, "shame": 3}},
    "cage_fear_zone": {"type": "fear_zone", "effects_per_tick": {"fear": 2, "watchfulness": 1}},
    "arbor_sleep_zone": {"type": "sleep_zone", "sleepiness_delta": 5,
                         "effects_per_tick": {"weariness": -2, "watchfulness": -3, "deception": 1}},
    "shame_field_zone": {"type": "shame_zone", "effects_per_tick": {"shame": 3, "hope": -1}},
    "despair_flame_zone": {"type": "despair_zone", "effects_per_tick": {"despair": 3, "fear": 2}},
    "shadow_fear_zone": {"type": "fear_zone", "effects_per_tick": {"fear": 2, "hope": -1}},
    "false_voice_zone": {"type": "fear_zone", "effects_per_tick": {"deception": 2, "fear": 2}},
    "vanity_applause_zone": {"type": "temptation_zone", "vanity_pressure_delta": 5,
                             "effects_per_tick": {"pride": 2, "deception": 1}},
    "comfort_tent_zone": {"type": "temptation_zone",
                          "effects_per_tick": {"weariness": -2, "watchfulness": -2, "deception": 1}},
    "crowd_pressure_zone": {"type": "fear_zone", "effects_per_tick": {"fear": 2, "shame": 1}},
    "despair_cell_zone": {"type": "despair_zone", "tick_interval": 5.0,
                          "effects_per_tick": {"despair": 2, "shame": 1, "hope": -1}},
    "sleep_zone_enchanted_ground": {"type": "sleep_zone", "sleepiness_delta": 5,
                                    "effects_per_tick": {"watchfulness": -2, "deception": 1}},
    "river_deep_zone": {"type": "river_fear_zone", "effects_per_tick": {"fear": 2, "weariness": 1}},
}

SPIRITUAL_EVENTS = {
    "receive_burden": {"title": "The Burden Appears", "trigger": "read_book",
                       "effects": {"despair": 10, "fear": 5, "humility": 5},
                       "special": {}, "flags": {"read_book": True, "received_burden": True}},
    "accepted_help": {"title": "Lifted from the Mire", "trigger": "accept_help",
                      "effects": {"humility": 10, "hope": 10, "despair": -20},
                      "special": {}, "flags": {"accepted_help": True, "rescued_from_slough": True}},
    "spiritual_collapse_despond": {"title": "Collapsed in Despond", "trigger": "despair_100",
                                   "conditions": {"despair_min": 100},
                                   "effects": {"humility": 5, "hope": -5},
                                   "repentance_prompt": True,
                                   "message": "You sink beneath the weight of despair, yet the way back is not closed."},
    "cross_grace": {"title": "The Burden Falls", "trigger": "approach_cross",
                    "effects": {"faith": 30, "hope": 30, "humility": 10,
                                "despair": -100, "shame": -100, "fear": -80},
                    "special": {"remove_burden": True, "grant_scroll": True,
                                "grant_seal": True, "grant_new_garment": True},
                    "flags": {"burden_removed": True, "cross_grace_received": True, "mvp_completed": True}},
    "complete_interpreter_house": {"title": "Rooms Understood", "trigger": "all_interpreter_rooms_complete",
                                   "conditions": {"required_flags": ["saw_dust_room", "saw_fire_wall",
                                                                     "saw_cage_vision", "saw_narrow_room"]},
                                   "effects": {"discernment": 15, "watchfulness": 10, "humility": 5},
                                   "flags": {"completed_interpreter_house": True}},
    "palace_rest": {"title": "Rested at Palace Beautiful", "trigger": "rest_at_palace",
                    "effects": {"weariness": -30, "fear": -10, "despair": -10, "hope": 10},
                    "flags": {"rested_at_palace": True}},
    "apollyon_victory": {"title": "Apollyon Defeated", "trigger": "boss_defeated_apollyon",
                         "effects": {"faith": 15, "perseverance": 15, "hope": 10,
                                     "fear": -30, "shame": -30, "despair": -10},
                         "flags": {"defeated_apollyon": True, "stood_against_accuser": True}},
    "survive_shadow_valley": {"title": "Survived the Dark Valley", "trigger": "shadow_valley_exit",
                              "effects": {"watchfulness": 15, "faith": 10, "fear": -20, "perseverance": 10},
                              "flags": {"survived_shadow_valley": True, "completed_vertical_slice": True}},
    "faithful_witness_event": {"title": "Faithful's Witness", "trigger": "vanity_trial",
                               "effects": {"faith": 10, "perseverance": 8},
                               "flags": {"faithful_witnessed": True, "faithful_lost": True}},
    "promise_key_escape": {"title": "Escaped by Promise", "trigger": "use_promise_key",
                           "effects": {"faith": 10, "hope": 15, "despair": -30, "shame": -20},
                           "special": {"grant_promise_key": True},
                           "flags": {"found_promise_key": True, "escaped_doubting_castle": True}},
    "shepherd_map_received": {"title": "The Shepherds' Map", "trigger": "receive_shepherd_map",
                              "effects": {"watchfulness": 10, "discernment": 5},
                              "special": {"grant_shepherd_map": True},
                              "flags": {"received_shepherd_warning": True, "has_shepherd_map": True}},
    "enchanted_ground_survived": {"title": "Stayed Awake", "trigger": "enchanted_ground_exit",
                                  "effects": {"watchfulness": 20, "perseverance": 10, "hope": 10, "weariness": -10},
                                  "flags": {"survived_enchanted_ground": True}},
    "river_crossed": {"title": "The River Crossed", "trigger": "river_exit",
                      "effects": {"faith": 20, "hope": 20, "fear": -100,
                                  "despair": -100, "shame": -100, "weariness": -100},
                      "flags": {"crossed_river": True}},
    "journey_completed": {"title": "Journey Completed", "trigger": "enter_celestial_city",
                          "effects": {"faith": 100, "hope": 100, "fear": -100,
                                      "despair": -100, "shame": -100, "weariness": -100},
                          "special": {"grant_final_seal": True, "show_journey_review": True, "show_credits": True},
                          "flags": {"entered_celestial_city": True, "journey_completed": True}},
}

INTERACTABLES = {
    "prop_book": {"display_name": "Warning Book", "type": "story_event",
                  "interaction_prompt": "Read", "trigger_spiritual_event": "receive_burden",
                  "set_flags_on_interact": {"read_book": True}},
    "promise_stone_hope_01": {"display_name": "Promise Stone", "type": "promise_stone",
                              "interaction_prompt": "Remember",
                              "effects": {"hope": 8, "despair": -12}, "single_use": True,
                              "set_flags_on_interact": {"used_promise_stone_hope_01": True}},
    "wicket_gate": {"display_name": "Wicket Gate", "type": "gate",
                    "dialogue_id": "wicket_gate_knock", "interaction_prompt": "Knock",
                    "required_flags": ["left_slough"],
                    "set_flags_on_interact": {"reached_wicket_gate": True}},
    "cross": {"display_name": "Cross", "type": "story_event",
              "interaction_prompt": "Approach", "required_flags": ["passed_wicket_gate"],
              "trigger_spiritual_event": "cross_grace",
              "set_flags_on_interact": {"approached_cross": True}},
    "armor_stand": {"display_name": "Armor Stand", "type": "equipment",
                    "interaction_prompt": "Take up the armor", "item_id": "armor"},
    "promise_key": {"display_name": "Promise Key", "type": "story_event",
                    "interaction_prompt": "Remember", "trigger_spiritual_event": "promise_key_escape",
                    "set_flags_on_interact": {"found_promise_key": True}},
    "shepherd_map": {"display_name": "Shepherd Map", "type": "equipment",
                     "interaction_prompt": "Receive the map", "item_id": "shepherd_map"},
    "celestial_gate": {"display_name": "Celestial Gate", "type": "gate",
                       "dialogue_id": "final_gate_entry", "interaction_prompt": "Enter",
                       "required_flags": ["crossed_river"]},
}

ENEMIES_EXTRA = {
    "shadow_whisper": {"id": "shadow_whisper", "display_name": "Shadow Whisper",
                       "enemy_type": "deception", "influence": 40, "move_speed": 2.4,
                       "attack_range": 2.0, "attack_cooldown": 3.0,
                       "weaknesses": {"prayer": 1.4, "promise": 1.2},
                       "attack_effects": {"fear": 4, "deception": 3}},
}


def write_category(category, mapping, wrap=None):
    created = []
    for cid, body in mapping.items():
        if wrap is not None:
            obj = wrap(cid, body)
        else:
            obj = body
        path = os.path.join(DATA, category, cid + ".json")
        if _write_if_absent(path, obj):
            created.append(cid)
    return created


def main():
    report = {}
    report["chapters_imported_scene_path"] = add_imported_scene_paths()
    report["routes"] = write_routes()
    report["items"] = write_category("items", ITEMS, wrap=lambda i, b: {
        "id": i, "display_name": b[0], "type": b[1], "description": b[2],
        "visible_on_player": b[3], "effects": {}, "special": {}})
    report["companions"] = write_category("companions", COMPANIONS)
    report["hazards"] = write_category("hazards", HAZARDS, wrap=lambda i, b: dict(
        {"id": i, "tick_interval": b.get("tick_interval", 2.0), "nonlethal": True}, **b))
    report["spiritual_events"] = write_category("spiritual_events", SPIRITUAL_EVENTS,
        wrap=lambda i, b: dict({"id": i}, **b))
    report["interactables"] = write_category("interactables", INTERACTABLES,
        wrap=lambda i, b: dict({"id": i}, **b))
    report["enemies"] = write_category("enemies", ENEMIES_EXTRA)

    print("Data foundation build report")
    print("=" * 50)
    for k, v in report.items():
        print("%-28s %s" % (k, ("+%d %s" % (len(v), v)) if v else "(no change)"))


if __name__ == "__main__":
    main()
