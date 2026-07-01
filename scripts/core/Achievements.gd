extends Node
## Achievements — journey milestones, virtues and collectibles, autoloaded as
## `Achievements`. Data lives in data/achievements.json; unlocked state persists
## to user://achievements.cfg. Fully event-driven (hooks EventBus), so it needs
## no changes elsewhere to start tracking.

const DATA_PATH := "res://data/achievements.json"
const SAVE_PATH := "user://achievements.cfg"

# chapter_id (on completion) -> achievement id
const CHAPTER_ACH := {
	"city_of_destruction": "left_city",
	"wicket_gate": "through_gate",
	"cross_and_tomb": "burden_fallen",
	"interpreter_house": "rooms_understood",
	"hill_difficulty": "climbed_hill",
	"palace_beautiful": "armed_for_war",
	"valley_humiliation": "overcame_apollyon",
	"valley_shadow_death": "through_shadow",
	"vanity_fair": "refused_vanity",
	"doubting_castle": "escaped_despair",
	"delectable_mountains": "shepherds_sight",
	"river_of_death": "crossed_river",
	"celestial_city": "entered_city",
}

var _defs: Array = []
var _by_id: Dictionary = {}
var _unlocked: Dictionary = {}
var _cards_seen: Dictionary = {}


func _ready() -> void:
	_load_defs()
	_load_state()
	EventBus.game_started.connect(func(): unlock("first_step"))
	EventBus.chapter_completed.connect(_on_chapter_completed)
	EventBus.burden_removed.connect(func(): unlock("burden_fallen"))
	EventBus.repentance_completed.connect(func(): unlock("turned_back"))
	EventBus.cross_grace_applied.connect(func(): unlock("burden_fallen"))
	EventBus.scripture_card_received.connect(_on_card)
	EventBus.demo_completed.connect(func(): unlock("pilgrim_complete"))


func _load_defs() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary and parsed.has("achievements"):
		_defs = (parsed as Dictionary)["achievements"]
		for a in _defs:
			if a is Dictionary:
				_by_id[String((a as Dictionary).get("id", ""))] = a


func _load_state() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	if cf.has_section("unlocked"):
		for id in cf.get_section_keys("unlocked"):
			_unlocked[id] = true
	for c in cf.get_value("progress", "cards", []):
		_cards_seen[String(c)] = true


func _save_state() -> void:
	var cf := ConfigFile.new()
	for id in _unlocked.keys():
		cf.set_value("unlocked", String(id), true)
	cf.set_value("progress", "cards", _cards_seen.keys())
	cf.save(SAVE_PATH)


func unlock(id: String) -> void:
	if id == "" or not _by_id.has(id) or _unlocked.has(id):
		return
	_unlocked[id] = true
	_save_state()
	var title := label(_by_id[id], "title")
	EventBus.toast("🏆 " + LocaleManager.t("ach.unlocked", "成就解锁：") + title)
	AudioManager.play_sfx("quest_complete")


func _on_chapter_completed(chapter_id: String) -> void:
	if CHAPTER_ACH.has(chapter_id):
		unlock(String(CHAPTER_ACH[chapter_id]))
	# Whole-journey badge: every mapped chapter completed.
	var all_done := true
	for cid in CHAPTER_ACH.keys():
		if not _unlocked.has(String(CHAPTER_ACH[cid])):
			all_done = false
			break
	if all_done:
		unlock("pilgrim_complete")


func _on_card(card_id: String) -> void:
	if card_id == "" or _cards_seen.has(card_id):
		return
	_cards_seen[card_id] = true
	_save_state()
	var n := _cards_seen.size()
	if n >= 1:
		unlock("word_hidden_1")
	if n >= 5:
		unlock("word_hidden_5")
	if n >= 10:
		unlock("word_hidden_10")


# --- queries used by the Achievements panel ---
func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)

func unlocked_count() -> int:
	return _unlocked.size()

func total() -> int:
	return _defs.size()

func all_defs() -> Array:
	return _defs

func label(a: Dictionary, field: String) -> String:
	var zh := String(a.get(field + "_zh", ""))
	var en := String(a.get(field + "_en", a.get(field, "")))
	return zh if (LocaleManager.is_zh() and zh != "") else LocaleManager.bilingual(zh, en)
