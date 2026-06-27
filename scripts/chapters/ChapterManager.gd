extends Node
## ChapterManager
## Owns the linear pilgrimage route, loads chapter data JSON, and swaps the
## active chapter scene. Autoloaded as "ChapterManager".

const CHAPTER_DIR := "res://data/chapters/"

const CHAPTER_TITLE_ZH := {
	"city_of_destruction": "灭亡城",
	"wilderness_road": "旷野之路",
	"slough_of_despond": "绝望泥潭",
	"wicket_gate": "窄门",
	"cross_and_tomb": "十字架与空墓",
	"interpreter_house": "释经者之家",
	"hill_difficulty": "艰难山",
	"palace_beautiful": "美宫",
	"valley_humiliation": "谦卑谷",
	"valley_shadow_death": "死荫谷",
	"vanity_fair": "虚华市集",
	"doubting_castle": "怀疑城堡",
	"delectable_mountains": "可悦山",
	"enchanted_ground": "迷睡之地",
	"river_of_death": "死河",
	"celestial_city": "天城",
}

# Full canonical pilgrimage route.
const CANONICAL_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
	"interpreter_house",
	"hill_difficulty",
	"palace_beautiful",
	"valley_humiliation",
	"valley_shadow_death",
	"vanity_fair",
	"doubting_castle",
	"delectable_mountains",
	"enchanted_ground",
	"river_of_death",
	"celestial_city",
]

const MVP_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
]

const VERTICAL_SLICE_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
	"interpreter_house",
	"hill_difficulty",
	"palace_beautiful",
	"valley_humiliation",
]

# The shipped build now plays the full canonical pilgrimage to the Celestial City.
var route: Array = CANONICAL_ROUTE
var _data_cache: Dictionary = {}
var _world_root: Node = null
var _current_scene_instance: Node = null
var current_chapter_id: String = ""


func _ready() -> void:
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(func(_loc): _data_cache.clear())


func set_world_root(node: Node) -> void:
	_world_root = node


func get_route() -> Array:
	return route


# --- Data loading ---
func load_chapter_data(chapter_id: String) -> Dictionary:
	if _data_cache.has(chapter_id):
		return _data_cache[chapter_id]
	var path := CHAPTER_DIR + chapter_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("ChapterManager: missing chapter data " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data := _localize_chapter_data(chapter_id, parsed)
		_data_cache[chapter_id] = data
		return data
	push_warning("ChapterManager: failed to parse " + path)
	return {}


func _localize_chapter_data(chapter_id: String, data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var title_zh := String(out.get("title_zh", CHAPTER_TITLE_ZH.get(chapter_id, "")))
	var title_en := String(out.get("title", chapter_id))
	out["title"] = LocaleManager.bilingual(title_zh, title_en) if not LocaleManager.is_zh() else (title_zh if title_zh != "" else LocaleManager.zh_or_mixed(title_en))
	for field in ["subtitle", "spiritual_theme", "core_mechanic"]:
		var zh := String(out.get(field + "_zh", ""))
		var en := String(out.get(field, ""))
		out[field] = LocaleManager.bilingual(zh, en) if not LocaleManager.is_zh() else (zh if zh != "" else LocaleManager.zh_or_mixed(en))
	if out.has("intro"):
		var intro: Array = out.get("intro", [])
		var intro_zh: Array = out.get("intro_zh", [])
		var localized: Array = []
		for i in range(intro.size()):
			var en_line := String(intro[i])
			var zh_line := String(intro_zh[i]) if i < intro_zh.size() else ""
			localized.append(LocaleManager.bilingual(zh_line, en_line) if not LocaleManager.is_zh() else (zh_line if zh_line != "" else LocaleManager.zh_or_mixed(en_line)))
		out["intro"] = localized
	return out


func get_current_chapter_data() -> Dictionary:
	return load_chapter_data(current_chapter_id)


# --- Route helpers ---
func get_chapter_index(chapter_id: String) -> int:
	return route.find(chapter_id)


func get_next_chapter_id(chapter_id: String) -> String:
	var data := load_chapter_data(chapter_id)
	if data.has("next_chapter_id"):
		return String(data["next_chapter_id"])
	var idx := get_chapter_index(chapter_id)
	if idx >= 0 and idx + 1 < route.size():
		return route[idx + 1]
	return ""


func get_previous_chapter_id(chapter_id: String) -> String:
	var idx := get_chapter_index(chapter_id)
	if idx > 0:
		return route[idx - 1]
	return ""


func can_enter_chapter(chapter_id: String) -> bool:
	var data := load_chapter_data(chapter_id)
	for flag in data.get("required_flags", []):
		if not GameState.has_flag(String(flag)):
			return false
	return true


# --- Lifecycle ---
func start_chapter(chapter_id: String) -> void:
	var data := load_chapter_data(chapter_id)
	if data.is_empty():
		push_error("ChapterManager: cannot start unknown chapter " + chapter_id)
		return
	current_chapter_id = chapter_id
	GameState.current_chapter_id = chapter_id
	GameState.current_scene_path = String(data.get("scene_path", ""))
	GameState.mark_chapter_visited(chapter_id)
	GameState.set_flag(String(data.get("id", chapter_id)) + "_started", true)
	apply_chapter_entry_effects(chapter_id)
	# Clean up stragglers: complete the quests of every EARLIER chapter in the
	# route, so the objective tracker always reflects the current chapter instead
	# of an old, partly-finished one (e.g. leave_city lingering into later chapters
	# when the player left without reading the book or facing Obstinate).
	var idx := get_chapter_index(chapter_id)
	for i in range(maxi(0, idx)):
		for pq in load_chapter_data(route[i]).get("quests", []):
			QuestManager.complete_quest(String(pq))
	# Start the chapter's quests.
	for q in data.get("quests", []):
		QuestManager.start_quest(String(q))
	load_chapter_scene(chapter_id)
	EventBus.chapter_started.emit(chapter_id)
	# Autosave on entry so "Continue" always resumes at the latest chapter.
	SaveManager.save_game("slot_1", false)


func apply_chapter_entry_effects(chapter_id: String) -> void:
	# Apply entry effects only once per chapter, so reloading or re-entering a
	# chapter does not stack them on top of the already-saved state.
	var guard := chapter_id + "_entry_applied"
	if GameState.has_flag(guard):
		return
	var data := load_chapter_data(chapter_id)
	var effects: Dictionary = data.get("entry_effects", {})
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	for k in (data.get("on_start_flags", {}) as Dictionary).keys():
		GameState.set_flag(String(k), data["on_start_flags"][k])
	GameState.set_flag(guard, true)


func apply_chapter_completion_effects(chapter_id: String) -> void:
	var data := load_chapter_data(chapter_id)
	var effects: Dictionary = data.get("completion_effects", {})
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	for k in (data.get("on_complete_flags", {}) as Dictionary).keys():
		GameState.set_flag(String(k), data["on_complete_flags"][k])


func evaluate_completion_conditions(chapter_id: String) -> bool:
	var data := load_chapter_data(chapter_id)
	var conditions: Array = data.get("completion_conditions", [])
	if conditions.is_empty():
		return true
	for cond in conditions:
		if String(cond.get("type", "flag")) == "flag":
			var key: String = String(cond.get("key", ""))
			var want: Variant = cond.get("value", true)
			if GameState.get_flag(key, null) != want:
				return false
	return true


func complete_chapter(chapter_id: String) -> void:
	apply_chapter_completion_effects(chapter_id)
	GameState.set_flag(chapter_id + "_completed", true)
	EventBus.chapter_completed.emit(chapter_id)


func go_to_next_chapter() -> void:
	var next_id := get_next_chapter_id(current_chapter_id)
	complete_chapter(current_chapter_id)
	if next_id == "":
		# End of route: signal the game-complete flow.
		EventBus.toast("这段朝圣路已经完成。")
		return
	start_chapter(next_id)


func load_chapter_scene(chapter_id: String) -> void:
	if _world_root == null:
		push_error("ChapterManager: no world root set")
		return
	var data := load_chapter_data(chapter_id)
	var scene_path: String = String(data.get("scene_path", ""))
	# Free previous chapter.
	if is_instance_valid(_current_scene_instance):
		_current_scene_instance.queue_free()
		_current_scene_instance = null
	var instance: Node = null
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		if packed != null:
			instance = packed.instantiate()
	if instance == null:
		push_warning("ChapterManager: scene_path missing, using empty Node3D for " + chapter_id)
		instance = Node3D.new()
		instance.name = "EmptyChapter_" + chapter_id
	_current_scene_instance = instance
	_world_root.add_child(instance)
	EventBus.chapter_scene_loaded.emit(chapter_id)


func get_current_scene_instance() -> Node:
	return _current_scene_instance
