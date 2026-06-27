"""Embed a per-chapter `design` block into every data/chapters/<id>.json.

Reconstruction of the 16 scenes from the attachment *合并重构天路历程* (Skills 15-46:
the 7-step rhythm Arrival -> Orientation -> Encounter -> Temptation -> Choice ->
Consequence -> Grace, the chapel-cross verse system, the temptation engine and the
repentance/restoration system) applied to the EXISTING Godot game without changing
its structure, scene list, ordering, or any field the loader/validators already read.

Design principle: the engine already implements the systems, so we do NOT rename or
re-invent them. The attachment's stat vocabulary is *mapped* onto the game's real
stat keys (see STAT_MAP below); flags/items use the game's `has_*` tokens; temptation
`type` values use the engine's recognized set. The block is added as a new top-level
`design` key, which the chapter loader and tools/validation/validate_data.py both
ignore for behaviour but which documents and grounds each scene's reconstruction
(and is available to any future objective/HUD panel).

    python3 tools/data_gen/enrich_chapter_design.py        # write blocks
    python3 tools/data_gen/enrich_chapter_design.py --check # report only, no write

Idempotent: re-running overwrites the `design` key and leaves every other field and
its order untouched.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CHAPTERS = os.path.join(ROOT, "data", "chapters")

# Attachment stat -> engine stat key. Engine numeric stats (the ONLY legal keys):
#   POSITIVE: faith hope humility discernment perseverance watchfulness
#   NEGATIVE: despair shame fear pride deception weariness
# vigilance->watchfulness | courage,witness->perseverance | love->humility
# doubt->despair | worldliness->deception | accusation->shame | sleepiness->weariness
# burden(numeric)-> not a stat; modelled by the has_burden token + remove_burden special.
STAT_MAP = {
    "vigilance": "watchfulness", "courage": "perseverance", "witness": "perseverance",
    "love": "humility", "doubt": "despair", "worldliness": "deception",
    "accusation": "shame", "sleepiness": "weariness",
}

# Engine temptation types (verbatim, from SpiritualStateManager): return_to_city,
# despair, comfort_shortcut, vanity, shame, doubt, sleep, false_teaching,
# self_reliance, fear.

DESIGN = {
    # ------------------------------------------------------------------ Ch1
    "city_of_destruction": {
        "provenance": "Attachment Ch1 灭亡城与觉醒 (Skill 15).",
        "spiritual_layer": "Narrative + Temptation + Redemption",
        "seven_beats": {
            "arrival": "Wake before dawn, burdened and slow, in a grey doomed city under a distant firelight and a faint bell.",
            "orientation": "A ruined chapel leans with its tilted cross; the open book names the coming judgement.",
            "encounter": "Evangelist points past the wall to the far light and the narrow gate; Obstinate mocks; Pliable offers to come.",
            "temptation": "The fear of leaving the familiar — 'to leave all you know is to lose all you have.'",
            "choice": "Heed the call and flee / argue with Obstinate / linger at home / pray at the ruined chapel.",
            "consequence": "Heeding lifts faith and resolve; arguing breeds pride; lingering deepens fear and shame.",
            "grace": "Pass the city gate toward the wilderness, the burden still on your back but your face now turned to life.",
        },
        "chapel": {"verse_zh": "醒来吧，你这睡着的人，从死里复活。", "verse_en": "Awake, O sleeper, and arise from the dead.",
                   "hint_zh": "朝远处的光走，寻找窄门。", "restore_faith": 5, "type": "ruined"},
        "primary_temptation": {"type": "return_to_city", "hook_zh": "为了书卷上几句话，就要离开熟悉的一切吗？",
                                "resisted_by": {"faith_min": 30, "perseverance_min": 20, "or_item": "has_scroll"}},
        "repentance": {"at": "ruined chapel prayer", "restores": {"faith": 5, "humility": 5}},
        "key_choices": [
            {"id": "accept_evangelist_call", "text_zh": "我愿意离开这城", "effects": {"faith": 12, "perseverance": 8, "fear": -4}},
            {"id": "argue_with_obstinate", "text_zh": "与顽固争辩", "effects": {"pride": 10, "watchfulness": -5}},
            {"id": "read_warning_scroll", "text_zh": "读警醒的书卷", "effects": {"watchfulness": 8, "discernment": 5}},
        ],
        "stat_arc_note": "Opens with despair/shame/fear high and has_burden true; heeding the call begins to lift faith/perseverance.",
    },
    # ------------------------------------------------------------------ bridge
    "wilderness_road": {
        "provenance": "Original bridging scene (between attachment Ch1 and Ch2) — kept as-is; barren by design.",
        "spiritual_layer": "Narrative + Temptation",
        "seven_beats": {
            "arrival": "The road doglegs down out of the city; the sky behind still smoulders.",
            "orientation": "A signpost and a wayside stone; the distant light holds steady ahead — no chapel here, only resolve.",
            "encounter": "Obstinate turns back; Pliable wavers at your side as the city voices call after you.",
            "temptation": "The pull of the city behind — voices urging a reasonable return.",
            "choice": "Answer Obstinate without pride / steady Pliable without flattery / fix your eyes on the light.",
            "consequence": "Fixing the eyes forward steadies perseverance; trading words breeds pride or fear.",
            "grace": "Keep the light ahead until the ground begins to fail at the edge of the Slough.",
        },
        "chapel": None,
        "primary_temptation": {"type": "return_to_city", "hook_zh": "回头吧，这条路只属于疯子。",
                                "resisted_by": {"perseverance_min": 20, "or_item": "has_scroll"}},
        "repentance": {"at": "none (fix eyes on the distant light)", "restores": {"perseverance": 5}},
        "key_choices": [
            {"id": "fix_eyes_on_light", "text_zh": "定睛远处的光", "effects": {"perseverance": 6, "watchfulness": 4}},
            {"id": "answer_obstinate_calmly", "text_zh": "平静回应顽固", "effects": {"humility": 5, "pride": -3}},
        ],
        "stat_arc_note": "Transitional: small perseverance gain; the burden is still carried.",
        "kept_original": "No chapel — austere by design; not one of the attachment's 16 core scenes.",
    },
    # ------------------------------------------------------------------ Ch2a
    "slough_of_despond": {
        "provenance": "Attachment Ch2 沮丧泥潭 (Skill 16). Added a half-sunken chapel-cross landmark this pass.",
        "spiritual_layer": "Temptation + Redemption",
        "seven_beats": {
            "arrival": "A cold mire under low fog; the mud drags at every step and floating words — guilt, fear, shame — drift on the slime.",
            "orientation": "Promise-stones give footing; across the bog a half-sunken chapel still lifts its cross above the muck.",
            "encounter": "Pliable sinks, despairs and turns back to the city; Help comes for the one who cries out.",
            "temptation": "Despair pressing you to give up and go back — the heavier the burden, the deeper you sink.",
            "choice": "Press on by the stones / cry out for Help / consider returning to the city.",
            "consequence": "Crying for help lowers despair and lifts humble hope; turning back deepens despair and shame.",
            "grace": "Help lifts the humble out of the mire and sets the feet toward the narrow gate.",
        },
        "chapel": {"verse_zh": "我从深处向你求告。", "verse_en": "Out of the depths I cry to you, O LORD.",
                   "hint_zh": "呼求帮助，不要独自陷在泥潭里。", "restore_faith": 8, "type": "ruined (half-sunken)"},
        "primary_temptation": {"type": "despair", "hook_zh": "回去吧，你永远走不出这片泥。",
                                "resisted_by": {"hope_min": 25, "faith_min": 20, "or_item": "has_scroll"}},
        "repentance": {"at": "cry for Help (the cry from the depths)", "restores": {"humility": 10, "hope": 8, "despair": -8}},
        "key_choices": [
            {"id": "keep_moving_on_stones", "text_zh": "踏着应许之石前行", "effects": {"faith": 8, "hope": 5, "despair": -5}},
            {"id": "call_for_help", "text_zh": "向帮助呼求", "effects": {"humility": 10, "hope": 8, "despair": -8}},
            {"id": "consider_returning", "text_zh": "想要回头", "effects": {"despair": 8, "shame": 5}},
        ],
        "stat_arc_note": "Despair spikes in the mud, then falls sharply when the humble cry for Help.",
    },
    # ------------------------------------------------------------------ Ch2b
    "wicket_gate": {
        "provenance": "Attachment Ch2 窄门 (Skill 16). Added a gate prayer-chapel this pass.",
        "spiritual_layer": "Narrative + Redemption",
        "seven_beats": {
            "arrival": "A narrow cliff path; arrows of accusation hiss from behind, urging a backward glance.",
            "orientation": "The small narrow gate stands ahead with a cross carved over it; a gate chapel waits just inside.",
            "encounter": "You knock, and Goodwill takes your hand and draws you through.",
            "temptation": "Shame whispering that the gate will never open for one like you.",
            "choice": "Knock and ask / press through the arrows / look back toward the city.",
            "consequence": "Knocking lifts faith and quiets fear and despair; looking back deepens shame.",
            "grace": "Goodwill admits you to the true way; kneel and give thanks at the gate chapel.",
        },
        "chapel": {"verse_zh": "你们要进窄门。", "verse_en": "Enter through the narrow gate.",
                   "hint_zh": "叩门，门就给你们开。", "restore_faith": 12, "type": "gate"},
        "primary_temptation": {"type": "shame", "hook_zh": "你这样的人，门岂会为你开？",
                                "resisted_by": {"faith_min": 20, "or_flag": "knocked_at_gate"}},
        "repentance": {"at": "gate chapel prayer", "restores": {"faith": 8, "hope": 5}},
        "key_choices": [
            {"id": "knock_and_ask", "text_zh": "叩门求进", "effects": {"faith": 10, "hope": 10, "fear": -5}},
            {"id": "press_through_arrows", "text_zh": "顶着箭雨前行", "effects": {"perseverance": 8, "fear": -5}},
            {"id": "look_back", "text_zh": "回望灭亡城", "effects": {"shame": 8, "despair": 5}},
        ],
        "stat_arc_note": "Faith rises and fear/despair fall as the gate opens to the asking.",
    },
    # ------------------------------------------------------------------ Ch4 (cross)
    "cross_and_tomb": {
        "provenance": "Attachment Ch4 十架山与赦罪 (Skill 18). Burden release runs through the existing cross_grace event.",
        "spiritual_layer": "Narrative + Redemption (the climax of justification)",
        "seven_beats": {
            "arrival": "An uphill path under a sky turning from storm to dawn; the weight grows heavier as you climb.",
            "orientation": "The cross is revealed through parting clouds, an empty tomb behind it and an open-air chapel beside.",
            "encounter": "No one bars the way — the cross itself is the meeting.",
            "temptation": "No assault; the only trial is the weight, and the quiet question of whether grace is for you.",
            "choice": "Kneel silently / confess your need aloud / ask whether this grace is for you — posture, not whether you are forgiven.",
            "consequence": "However you kneel, the burden's strap breaks and it rolls into the empty tomb.",
            "grace": "Burdened becomes forgiven: you receive the scroll of assurance, the seal, and a new garment.",
        },
        "chapel": {"verse_zh": "他的重担在十字架前脱落。", "verse_en": "There at the cross the burden fell from his back.",
                   "hint_zh": "跪在十字架前，不再背负你不能除去的重担。", "restore_faith": 25, "type": "calvary"},
        "primary_temptation": {"type": "doubt", "hook_zh": "这恩典岂是为你存留的？",
                                "resisted_by": {"faith_min": 1, "note": "answered by kneeling, not by a stat gate"}},
        "repentance": {"at": "kneel at the cross (the definitive repentance)",
                        "restores": {"faith": 25, "hope": 25, "despair": -30, "shame": -30},
                        "special": ["remove_burden", "grant_scroll", "grant_seal", "grant_new_garment"]},
        "key_choices": [
            {"id": "kneel_silently", "text_zh": "默然跪下", "effects": {"humility": 12, "faith": 10}},
            {"id": "confess_need", "text_zh": "承认自己的需要", "effects": {"humility": 18, "faith": 12, "despair": -10}},
            {"id": "ask_grace_for_me", "text_zh": "问这恩典是否为我", "effects": {"hope": 15, "faith": 8, "despair": -15}},
        ],
        "stat_arc_note": "has_burden -> false here for the whole game; faith/hope rise steeply, despair/shame collapse. Identity: forgiven.",
        "kept_original": "Release stays wired through the existing cross_grace spiritual_event, not duplicated in chapter effects.",
    },
    # ------------------------------------------------------------------ Ch3 (interpreter)
    "interpreter_house": {
        "provenance": "Attachment Ch3 讲解者之家 (Skill 17). Engine keeps it AFTER the cross; see kept_original.",
        "spiritual_layer": "Narrative + Redemption (discipleship & discernment)",
        "seven_beats": {
            "arrival": "An interior larger than it looked, lit low, a quiet mystic hymn.",
            "orientation": "The Interpreter welcomes you; six symbolic rooms wait, and a small chapel for prayer.",
            "encounter": "He teaches by picture, dust, hidden fire, a palace battle, the iron cage, and a dream of judgement.",
            "temptation": "The iron-caged man — a warning against despising grace until the heart hardens.",
            "choice": "Read each room rightly, discerning the true meaning under the picture.",
            "consequence": "Each lesson sharpens faith, humility, watchfulness and discernment.",
            "grace": "The Interpreter points your longing onward to the cross and the road ahead.",
        },
        "chapel": {"verse_zh": "求你开我的眼睛，使我看出你律法中的奇妙。", "verse_en": "Open my eyes, that I may behold wondrous things out of your law.",
                   "hint_zh": "完成每个房间的功课，再继续上路。", "restore_faith": 10, "type": "gate"},
        "primary_temptation": {"type": "false_teaching", "hook_zh": "你看见的，未必是它真正的意思。",
                                "resisted_by": {"discernment_min": 20, "or_item": "has_scroll"}},
        "repentance": {"at": "interpreter chapel prayer", "restores": {"faith": 8, "discernment": 8}},
        "key_choices": [
            {"id": "lesson_dust_room", "text_zh": "尘土房间的功课", "effects": {"humility": 10, "discernment": 5}},
            {"id": "lesson_fire_room", "text_zh": "火焰房间的隐密恩典", "effects": {"hope": 10, "faith": 10}},
            {"id": "lesson_iron_cage", "text_zh": "铁笼之人的警戒", "effects": {"watchfulness": 12, "humility": 8}},
        ],
        "stat_arc_note": "Burden does not drop here (it already fell at the cross); discernment/watchfulness climb before the hill.",
        "kept_original": "Bunyan/attachment place Interpreter BEFORE the cross; the engine wires it after (burden_fallen gate). Order kept to preserve the flag chain.",
    },
    # ------------------------------------------------------------------ Ch5
    "hill_difficulty": {
        "provenance": "Attachment Ch5 艰难山 + bypass-path system (Skills 23-24).",
        "spiritual_layer": "Narrative + Temptation + Redemption (sanctification)",
        "seven_beats": {
            "arrival": "The foot of a steep hill where three paths fork.",
            "orientation": "Difficulty climbs narrow and steep; Danger and Destruction spread broad and pretty; a hill chapel keeps its cross.",
            "encounter": "Timorous and Mistrust flee downhill, warning of lions ahead.",
            "temptation": "The easy bypath — why suffer the climb when a gentler road runs alongside?",
            "choice": "Take the steep true path / slip onto a bypath / sleep carelessly at the rest arbor.",
            "consequence": "The true path costs perseverance but keeps you; bypaths drain watchfulness; sleeping loses the scroll.",
            "grace": "Pass the chained lions by faith and reach the lights of the Palace at the summit.",
        },
        "chapel": {"verse_zh": "进入神的国，必须经历许多艰难。", "verse_en": "Through many tribulations we must enter the kingdom of God.",
                   "hint_zh": "不要走旁路，走窄而陡的正路。", "restore_faith": 12, "type": "pilgrim"},
        "primary_temptation": {"type": "comfort_shortcut", "hook_zh": "走这条平缓的近路吧，何必受苦？",
                                "resisted_by": {"watchfulness_min": 40, "perseverance_min": 30}},
        "repentance": {"at": "return from the bypath, pray at the hill chapel", "restores": {"humility": 10, "watchfulness": 8}},
        "key_choices": [
            {"id": "choose_difficulty_path", "text_zh": "走艰难正路", "effects": {"faith": 8, "perseverance": 8, "watchfulness": 5}},
            {"id": "choose_bypath", "text_zh": "走平缓旁路", "effects": {"watchfulness": -12, "despair": 6, "deception": 5}},
            {"id": "sleep_at_arbor", "text_zh": "在凉亭沉睡", "effects": {"watchfulness": -20, "despair": 8}},
            {"id": "pass_lions_by_faith", "text_zh": "凭信走过狮子之间", "effects": {"faith": 12, "perseverance": 12, "fear": -10}},
        ],
        "stat_arc_note": "Perseverance is the currency here; carelessness can lose has_scroll, gating the Palace until recovered.",
    },
    # ------------------------------------------------------------------ Ch6 (+Ch7 armory)
    "palace_beautiful": {
        "provenance": "Attachment Ch6 美宫 + Ch7 神圣军装厅 (Skills 25-26) — the armory is folded into this scene.",
        "spiritual_layer": "Narrative + Redemption (fellowship & equipping)",
        "seven_beats": {
            "arrival": "Watchful the porter halts you at the gate and asks who you are and why you come so late.",
            "orientation": "A cross-crowned tower, a fellowship hall, a rest room, the armoury door, and a chapel.",
            "encounter": "Discretion, Prudence, Piety and Charity welcome and examine you; you tell your story.",
            "temptation": "Self-reliant boasting — to make much of how far YOU have come.",
            "choice": "Rest with thanksgiving / review the journey in prayer / boast of your progress.",
            "consequence": "Thanksgiving restores hope; boasting swells pride and dulls watchfulness.",
            "grace": "Take up the whole armour of God before descending into the Valley of Humiliation.",
        },
        "chapel": {"verse_zh": "你们要彼此接待，如同基督接待你们。", "verse_en": "Welcome one another as Christ has welcomed you.",
                   "hint_zh": "在团契中安息，并预备穿上军装。", "restore_faith": 15, "type": "pilgrim"},
        "primary_temptation": {"type": "self_reliance", "hook_zh": "看你走了多远，你已经够刚强了。",
                                "resisted_by": {"humility_min": 40, "watchfulness_min": 35}},
        "repentance": {"at": "review the journey in prayer", "restores": {"humility": 12, "watchfulness": 8}},
        "armory": {"symbol": "Eph 6 — the whole armour of God", "grants": ["has_armor", "has_sword", "has_shield"],
                    "pieces": [
                        {"piece": "belt_of_truth 真理带", "guards": "truth / discerning true from false"},
                        {"piece": "breastplate_of_righteousness 公义护心镜", "guards": "standing not on one's own merit"},
                        {"piece": "shoes_of_gospel_peace 平安福音鞋", "guards": "steady footing, readiness of the gospel"},
                        {"piece": "shield_of_faith 信德盾牌", "guards": "quenching the fiery darts"},
                        {"piece": "helmet_of_salvation 救恩头盔", "guards": "the mind, the assurance of salvation"},
                        {"piece": "sword_of_spirit 圣灵宝剑", "guards": "the Word — the one offensive weapon"},
                    ]},
        "key_choices": [
            {"id": "rest_with_thanksgiving", "text_zh": "带着感恩安息", "effects": {"hope": 15, "faith": 8, "perseverance": 5}},
            {"id": "review_in_prayer", "text_zh": "在祷告中回顾旅程", "effects": {"humility": 12, "watchfulness": 8, "faith": 8}},
            {"id": "boast_of_progress", "text_zh": "夸耀自己的进步", "effects": {"pride": 15, "humility": -8, "watchfulness": -6}},
        ],
        "stat_arc_note": "Rest restores hope/weariness; the armoury sets has_armor/has_sword/has_shield for the warfare arc.",
    },
    # ------------------------------------------------------------------ Ch8 prelude + Ch9 Apollyon
    "valley_humiliation": {
        "provenance": "Attachment Ch8 降卑谷前置 + Ch9 亚玻伦之战 (Skills 27, 32-33). Boss = ApollyonBoss.gd.",
        "spiritual_layer": "Temptation + Redemption + Combat",
        "seven_beats": {
            "arrival": "The road bends downward — the armour is for standing in humility, not for marching in pride.",
            "orientation": "A low stone chapel, a humility stream, and ahead a scorched circle of ground.",
            "encounter": "Apollyon bars the road, claiming you were once his servant.",
            "temptation": "Accusation and fear: he recalls your past failures by name and tests your shield with fiery darts.",
            "choice": "Stand in the armour / answer every lie with the promise / pray for light — never boast.",
            "consequence": "Faith and resolve rise and fear/shame fall on victory; pride after victory undoes it.",
            "grace": "His claim breaks; give thanks humbly (not boastfully) to leave the valley floor.",
        },
        "chapel": {"verse_zh": "神阻挡骄傲的人，赐恩给谦卑的人。", "verse_en": "God opposes the proud but gives grace to the humble.",
                   "hint_zh": "不要凭骄傲迎战，要用信德的盾牌和圣灵的宝剑站立。", "restore_faith": 18, "type": "pilgrim"},
        "primary_temptation": {"type": "self_reliance", "hook_zh": "换了一件衣服，拿了一把剑，就不再是我的仆人吗？",
                                "resisted_by": {"humility_min": 45, "or_item": "has_armor"}},
        "repentance": {"at": "give thanks humbly after victory", "restores": {"humility": 15, "faith": 10, "pride": -10}},
        "boss": {"id": "apollyon", "phases": ["accusation", "fire_darts", "close_combat", "final_accusation"],
                  "counters": {"fiery_darts": "has_shield (raise shield)", "accusation": "has_scroll / breastplate (read assurance)",
                               "memory_accusation": "has_sword (scripture strike)", "dark_roar": "helmet (hold salvation)"},
                  "note": "Accusation recalls past-failure flags; defeat is NOT game over — repent and stand. Must give thanks, not boast, to progress."},
        "key_choices": [
            {"id": "stand_in_faith", "text_zh": "凭信站立", "effects": {"faith": 10, "perseverance": 8, "fear": -8}},
            {"id": "answer_with_promises", "text_zh": "用应许回应控告", "effects": {"faith": 8, "discernment": 8, "shame": -10}},
            {"id": "give_thanks_humbly", "text_zh": "谦卑感恩", "effects": {"humility": 15, "faith": 10, "pride": -10}},
        ],
        "stat_arc_note": "First real use of the armour; accusation maps to shame, fear stays fear; humble thanks gates the exit.",
    },
    # ------------------------------------------------------------------ Ch10
    "valley_shadow_death": {
        "provenance": "Attachment Ch10 死荫谷 + darkness/prayer-path system (Skills 34-35).",
        "spiritual_layer": "Temptation + Redemption (faith without sight)",
        "seven_beats": {
            "arrival": "A pitch-black valley mouth straight after Apollyon.",
            "orientation": "An extremely narrow path with a ditch on the left and a quag on the right, a glimmer of a white cross ahead.",
            "encounter": "Disembodied whispers from the fog: 'you are cast off; no one hears your prayer.'",
            "temptation": "Fear and despair, luring you to stop, turn, or stray off the narrow track.",
            "choice": "Enter in prayer / rush in confidently / hesitate in fear.",
            "consequence": "Praying steadies faith and resolve; rushing breeds pride and loses watchfulness; hesitating feeds fear.",
            "grace": "A pulse of prayer lights the next step; dawn breaks after the dark — give thanks.",
        },
        "chapel": {"verse_zh": "我虽然行过死荫的幽谷，也不怕遭害，因为你与我同在。",
                   "verse_en": "Though I walk through the valley of the shadow of death, I will fear no evil, for you are with me.",
                   "hint_zh": "不要偏左，也不要偏右，用祷告的微光看清下一步。", "restore_faith": 16, "type": "ruined"},
        "primary_temptation": {"type": "despair", "hook_zh": "你已经被丢弃了，你的祷告没有人听见。",
                                "resisted_by": {"faith_min": 55, "hope_min": 45, "watchfulness_min": 50, "or_item": "has_sword"}},
        "repentance": {"at": "prayer-pulse / shadow chapel prayer", "restores": {"faith": 8, "fear": -5, "watchfulness": 3}},
        "key_choices": [
            {"id": "enter_in_prayer", "text_zh": "祷告着进入", "effects": {"faith": 8, "perseverance": 8, "fear": -8}},
            {"id": "rush_in", "text_zh": "自信冲入", "effects": {"pride": 8, "watchfulness": -8, "fear": 5}},
            {"id": "thanksgiving_after", "text_zh": "出谷后感恩", "effects": {"faith": 12, "hope": 12, "humility": 8, "fear": -15}},
        ],
        "stat_arc_note": "Not a boss — holding fast in darkness. Straying left/right (the ditch/quag hazards) costs hp + fear/despair.",
    },
    # ------------------------------------------------------------------ Ch11 + Ch12 trial/martyrdom
    "vanity_fair": {
        "provenance": "Attachment Ch11 虚华市 + Ch12 忠信受审与殉道 (Skills 36-39). Faithful's trial/martyrdom folded in.",
        "spiritual_layer": "Temptation + Redemption + Witness",
        "seven_beats": {
            "arrival": "Faithful meets you at the gate; the fair blares with fame, wealth, comfort and power.",
            "orientation": "Gaudy stalls and a stage; a chapel half-hidden behind the market signage.",
            "encounter": "Merchants hawk glory; the mocking crowd jeers; you are called to public witness.",
            "temptation": "Buy the fair's wares — a badge of fame, a silver coin, a soft bed; and worldliness creeps in by the minute.",
            "choice": "'We buy the truth' / stay silent to avoid trouble / make a compromise / let Faithful answer.",
            "consequence": "Bold witness lifts faith and resolve; compromise feeds deception and dulls watchfulness.",
            "grace": "Arrest with Faithful leads to his trial and martyrdom; Hopeful, stirred by the witness, joins you — grace succeeds grace.",
        },
        "chapel": {"verse_zh": "不要爱世界和世界上的事。", "verse_en": "Do not love the world or the things in the world.",
                   "hint_zh": "不是所有发光的，都来自真光。", "restore_faith": 12, "type": "trial"},
        "primary_temptation": {"type": "vanity", "hook_zh": "买下名声吧，全城都会认识你。",
                                "resisted_by": {"watchfulness_min": 50, "humility_min": 45, "or_item": "has_armor"}},
        "repentance": {"at": "hidden chapel prayer / public witness", "restores": {"watchfulness": 10, "humility": 8}},
        "trial": {"judge": "Lord Hate-good", "jury": ["Envy", "Superstition", "Pickthank"],
                   "outcome": "Faithful martyred; standing with him lets Hopeful join (companion succession)."},
        "key_choices": [
            {"id": "we_buy_the_truth", "text_zh": "我们买真理", "effects": {"perseverance": 18, "faith": 10, "deception": -10}},
            {"id": "stand_with_faithful", "text_zh": "与忠信同站", "effects": {"faith": 8, "humility": 8, "perseverance": 12}},
            {"id": "compromise", "text_zh": "折中妥协", "effects": {"deception": 12, "watchfulness": -8}},
            {"id": "buy_fame", "text_zh": "买下名声徽章", "effects": {"deception": 20, "pride": 12, "humility": -15}},
        ],
        "stat_arc_note": "Worldliness maps to deception; bold witness maps to perseverance/faith. Hopeful joins after the martyrdom.",
    },
    # ------------------------------------------------------------------ Ch13
    "doubting_castle": {
        "provenance": "Attachment Ch13 疑惑堡与绝望巨人 + promise-key system (Skills 41-42). Boss = GiantDespair.gd.",
        "spiritual_layer": "Temptation + Redemption (despair & the Promise)",
        "seven_beats": {
            "arrival": "Weary on the rough true road, travelling with Hopeful.",
            "orientation": "A soft meadow looks easier than the hard road; a small warning cross stands at the fork.",
            "encounter": "You stray into the meadow; a storm loses the road; Giant Despair seizes you into Doubting Castle.",
            "temptation": "Despair editing the truth in the cell — Darkthought whispers your past failures back at you.",
            "choice": "Listen to the accusations / let Hopeful encourage you / remember the Promise.",
            "consequence": "The cell raises despair and shame the longer you stay; Hopeful's word lifts hope.",
            "grace": "Remember the key of Promise in your own breast, unlock the door, escape — and leave a warning for others.",
        },
        "chapel": None,
        "cross_markers": ["a cross scratched on the cell wall", "a dawn cross at the escape gate"],
        "primary_temptation": {"type": "despair", "hook_zh": "你已经走偏了；若你真有信心，怎会被关在这里？",
                                "resisted_by": {"hope_min": 30, "faith_min": 25, "or_item": "has_promise_key"}},
        "repentance": {"at": "remember the Promise (after Hopeful's encouragement)",
                        "restores": {"hope": 25, "faith": 15, "despair": -30}, "special": ["grant_promise_key"]},
        "key_choices": [
            {"id": "stay_on_true_road", "text_zh": "留在正路上", "effects": {"watchfulness": 12, "faith": 8, "perseverance": 5}},
            {"id": "enter_bypath_meadow", "text_zh": "走进近便的草场", "effects": {"watchfulness": -15, "despair": 8}},
            {"id": "remember_promise", "text_zh": "想起应许之钥", "effects": {"hope": 25, "faith": 15, "despair": -30}},
            {"id": "leave_warning", "text_zh": "为后人留下警戒", "effects": {"humility": 10, "perseverance": 8, "watchfulness": 8}},
        ],
        "stat_arc_note": "Entry spikes despair / drains hope; the Promise (has_promise_key) reverses it. No chapel — only faint crosses, by design.",
        "kept_original": "No formal chapel, matching the attachment — despair must be answered by the remembered Promise, not a save room.",
    },
    # ------------------------------------------------------------------ Ch14a
    "delectable_mountains": {
        "provenance": "Attachment Ch14 可喜山与牧人 (Skill 43).",
        "spiritual_layer": "Narrative + Redemption (restoration & sight)",
        "seven_beats": {
            "arrival": "A high mountain after the castle — air of recovery and rest.",
            "orientation": "A shepherds' camp and chapel; four shepherds — Knowledge, Experience, Watchful, Sincere.",
            "encounter": "They explain why you strayed, show the City through the glass, and warn of the Enchanted Ground.",
            "temptation": "A quiet doubt that the City is simply too far to reach.",
            "choice": "Look with hope / look but doubt the distance / look together with Hopeful.",
            "consequence": "Looking in hope lifts hope and lowers despair; doubting the distance keeps despair flickering.",
            "grace": "Receive the shepherds' map and warning, and carry that sight into the last trials.",
        },
        "chapel": {"verse_zh": "他使我躺卧在青草地上，领我在可安歇的水边。",
                   "verse_en": "He makes me lie down in green pastures; he leads me beside still waters.",
                   "hint_zh": "听牧人的警戒，带着地图进入魔睡地。", "restore_faith": 20, "type": "pilgrim"},
        "primary_temptation": {"type": "despair", "hook_zh": "天城那么远，你真能走到吗？",
                                "resisted_by": {"hope_min": 45, "faith_min": 40}},
        "repentance": {"at": "shepherd chapel prayer / Sincere's honesty about weakness", "restores": {"hope": 10, "humility": 5}},
        "key_choices": [
            {"id": "look_with_hope", "text_zh": "满怀盼望地眺望", "effects": {"hope": 20, "faith": 10, "despair": -15}},
            {"id": "look_but_doubt", "text_zh": "眺望却疑惑路远", "effects": {"hope": 5, "despair": 8}},
            {"id": "receive_shepherd_map", "text_zh": "领受牧人的地图", "effects": {"watchfulness": 15, "hope": 10, "humility": 5}},
        ],
        "stat_arc_note": "Recovery beat: hope/weariness mend; receiving has_shepherd_map equips against the next scene's sleep.",
    },
    # ------------------------------------------------------------------ Ch14b
    "enchanted_ground": {
        "provenance": "Attachment Ch14 魔睡地 + sleepwalk system (Skill 44).",
        "spiritual_layer": "Temptation + Redemption (watchfulness)",
        "seven_beats": {
            "arrival": "A beautiful, quiet, soft field.",
            "orientation": "Sleep-flowers everywhere; the longer you linger the drowsier you grow; a watchfulness chapel waits.",
            "encounter": "Drowsiness rises and the risk of sleepwalking with it; Hopeful walks at your side.",
            "temptation": "Comfortable forgetfulness — to sit, close your eyes, and let desire for the City fade.",
            "choice": "Talk with Hopeful to stay awake (remember Calvary / remember Faithful / speak of the City) / use the shepherds' map / pray.",
            "consequence": "Conversation and prayer restore watchfulness; lingering silently drifts you into a sleepwalk.",
            "grace": "Stay awake through fellowship and reach the borders of Beulah.",
        },
        "chapel": {"verse_zh": "总要警醒祷告，免得入了迷惑。", "verse_en": "Watch and pray, that you enter not into temptation.",
                   "hint_zh": "不要独自沉默前行，要与盼望彼此提醒。", "restore_faith": 14, "type": "pilgrim"},
        "primary_temptation": {"type": "sleep", "hook_zh": "歇一歇吧，闭上眼睛，这里很安全。",
                                "resisted_by": {"watchfulness_min": 60, "or_item": "has_shepherd_map"}},
        "repentance": {"at": "wake via Hopeful's talk / chapel prayer / the map", "restores": {"watchfulness": 15, "hope": 12}},
        "key_choices": [
            {"id": "remember_calvary", "text_zh": "彼此提说十字架", "effects": {"faith": 8, "hope": 8, "watchfulness": 8}},
            {"id": "speak_of_city", "text_zh": "谈论前面的天城", "effects": {"hope": 12, "faith": 6, "watchfulness": 6}},
            {"id": "drift_in_sleepwalk", "text_zh": "陷入梦游漂移", "effects": {"watchfulness": -10, "despair": 5, "weariness": 10}},
        ],
        "stat_arc_note": "Sleepiness maps to weariness; silence drains watchfulness, fellowship restores it. SleepinessSystem drives the drift.",
    },
    # ------------------------------------------------------------------ Ch15
    "river_of_death": {
        "provenance": "Attachment Ch15 美地与死河 (Skill 45). Depth driven by RiverDepthSystem.",
        "spiritual_layer": "Narrative + Temptation + Redemption (death & dependence)",
        "seven_beats": {
            "arrival": "The calm bright borders of Beulah; the City stands near, but across the river.",
            "orientation": "No bridge and no boat — the river of death is unavoidable; a river chapel keeps its cross.",
            "encounter": "You step in, and the water's depth rises with fear and falls with faith.",
            "temptation": "The fear of death itself — 'the water is over your head; you are sinking.'",
            "choice": "Enter with faith / cross together with Hopeful / fear and delay / pray before entering.",
            "consequence": "Faith and hope make the water shallow; fear and despair make it deep and slow.",
            "grace": "Hopeful steadies you — 'the far light is near' — and the far bank holds your feet.",
        },
        "chapel": {"verse_zh": "我已将这些事告诉你们，是要叫你们在我里面有平安。",
                   "verse_en": "These things I have spoken to you, that in me you may have peace.",
                   "hint_zh": "河必须经过，但不是独自经过。", "restore_faith": 25, "type": "river"},
        "primary_temptation": {"type": "fear", "hook_zh": "水漫过你的头，你要沉下去了。",
                                "resisted_by": {"faith_min": 70, "hope_min": 65, "or_item": "has_scroll"}},
        "repentance": {"at": "pray before the river / turn your eyes to the far light", "restores": {"faith": 12, "hope": 12, "fear": -8}},
        "key_choices": [
            {"id": "enter_with_faith", "text_zh": "凭信下水", "effects": {"faith": 15, "perseverance": 10, "fear": -10}},
            {"id": "cross_with_hopeful", "text_zh": "与盼望同过", "effects": {"hope": 18, "humility": 8, "faith": 8}},
            {"id": "fear_and_delay", "text_zh": "惧怕而迟疑", "effects": {"fear": 15, "despair": 8, "hope": -5}},
            {"id": "pray_before_river", "text_zh": "下水前先祷告", "effects": {"faith": 12, "hope": 12, "fear": -8, "humility": 5}},
        ],
        "stat_arc_note": "River depth rises with fear/despair, falls with faith/hope; Hopeful's presence steadies. Not a game over — the final faith trial.",
    },
    # ------------------------------------------------------------------ Ch16
    "celestial_city": {
        "provenance": "Attachment Ch16 天城 + ending/journey-review (Skills 46-47). Review = JourneyReviewScreen.",
        "spiritual_layer": "Narrative + Redemption (glory & grace remembered)",
        "seven_beats": {
            "arrival": "Ashore from the river into glory and white robes.",
            "orientation": "Your old gear is shown as witness, not weapons; crown-of-life imagery; a gate chapel.",
            "encounter": "The Shining One greets you and opens the Book of the Journey.",
            "temptation": "None — not a score-screen but a grace-review.",
            "choice": "Review the journey / open the gate / enter the final worship.",
            "consequence": "Every step is marked by grace, not merit; the false names, the fear and the burden cannot cross.",
            "grace": "The gate opens, you enter, and the whole road gathers into praise. Identity: glorified.",
        },
        "chapel": {"verse_zh": "那美好的仗我已经打过了，当跑的路我已经跑尽了。",
                   "verse_en": "I have fought the good fight, I have finished the race, I have kept the faith.",
                   "hint_zh": "回顾这一路，不是你自己走到了这里，而是恩典带你到这里。", "restore_faith": 30, "type": "celestial"},
        "primary_temptation": None,
        "repentance": {"at": "none needed — the journey review remembers grace, not merit", "restores": {}},
        "key_choices": [
            {"id": "open_journey_review", "text_zh": "翻开旅程之书", "effects": {"faith": 20, "hope": 20, "fear": -30, "despair": -30}},
            {"id": "enter_the_gate", "text_zh": "进入天城之门", "effects": {"hope": 20, "faith": 20}, "special": ["grant_final_seal", "show_journey_review", "show_credits"]},
        ],
        "stat_arc_note": "The review gathers grace from beginning to end; identity -> glorified; grant_final_seal closes the journey.",
    },
}


def main():
    check_only = "--check" in sys.argv
    written = 0
    problems = []
    for cid, block in DESIGN.items():
        path = os.path.join(CHAPTERS, cid + ".json")
        if not os.path.isfile(path):
            problems.append("missing chapter file: %s.json" % cid)
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Validate every numeric effect key against the engine's legal stat keys.
        legal = {"faith", "hope", "humility", "discernment", "perseverance", "watchfulness",
                 "despair", "shame", "fear", "pride", "deception", "weariness"}
        for ch in block.get("key_choices", []):
            for k in ch.get("effects", {}):
                if k not in legal:
                    problems.append("%s: illegal stat key '%s' in choice '%s'" % (cid, k, ch.get("id")))
        if check_only:
            continue
        data["design"] = block
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        written += 1
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  - " + p)
        sys.exit(1)
    if check_only:
        print("CHECK OK: %d design blocks, all effect keys legal." % len(DESIGN))
    else:
        print("Wrote design blocks into %d chapter files." % written)


if __name__ == "__main__":
    main()
