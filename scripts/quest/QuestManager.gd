extends Node
## QuestManager
## Loads quest definitions from res://data/quests and tracks progress.
## Step completion is driven by GameState flags. Autoloaded as "QuestManager".

const QUEST_DIR := "res://data/quests/"

var _definitions: Dictionary = {}     # quest_id -> definition dict
var active_quests: Array[String] = []
var completed: Array[String] = []


func _ready() -> void:
	_load_all_definitions()
	# React to flag changes by re-evaluating quests.
	EventBus.spiritual_state_changed.connect(_on_state_changed)


func _on_state_changed(_n: String, _o: int, _v: int) -> void:
	# Flags often change alongside effects; cheap to re-check active quests.
	for q in active_quests.duplicate():
		update_quest_progress(q)


func _load_all_definitions() -> void:
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_warning("QuestManager: quest dir not found: " + QUEST_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data := _read_json(QUEST_DIR + file_name)
			if data.has("id"):
				_definitions[String(data["id"])] = data
		file_name = dir.get_next()
	dir.list_dir_end()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("QuestManager: failed to parse " + path)
	return {}


func get_definition(quest_id: String) -> Dictionary:
	return _definitions.get(quest_id, {})


func start_quest(quest_id: String) -> void:
	if quest_id == "" or completed.has(quest_id) or active_quests.has(quest_id):
		return
	if not _definitions.has(quest_id):
		push_warning("QuestManager: unknown quest " + quest_id)
		return
	active_quests.append(quest_id)
	EventBus.quest_started.emit(quest_id)
	update_quest_progress(quest_id)


func update_quest_progress(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	var def := get_definition(quest_id)
	var steps: Array = def.get("steps", [])
	var all_done := true
	for step in steps:
		var flag: String = String(step.get("required_flag", ""))
		if flag != "" and not GameState.has_flag(flag):
			all_done = false
			break
	EventBus.quest_updated.emit(quest_id)
	if all_done and not steps.is_empty():
		complete_quest(quest_id)


func complete_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	active_quests.erase(quest_id)
	if not completed.has(quest_id):
		completed.append(quest_id)
	GameState.mark_quest_completed(quest_id)
	var def := get_definition(quest_id)
	var rewards: Dictionary = def.get("rewards", {})
	if not rewards.is_empty():
		SpiritualStateManager.apply_effects(rewards)
	EventBus.quest_completed.emit(quest_id)
	EventBus.toast("Quest complete: " + String(def.get("title", quest_id)))


func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed.has(quest_id)


func get_active_quests() -> Array[String]:
	return active_quests


func get_primary_active_quest() -> Dictionary:
	if active_quests.is_empty():
		return {}
	return get_definition(active_quests[0])


func get_next_incomplete_step_text(quest_id: String) -> String:
	var def := get_definition(quest_id)
	for step in def.get("steps", []):
		var flag: String = String(step.get("required_flag", ""))
		if flag != "" and not GameState.has_flag(flag):
			return String(step.get("description", ""))
	return ""


# --- Serialization ---
func to_dict() -> Dictionary:
	return {
		"active": active_quests.duplicate(),
		"completed": completed.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	active_quests.clear()
	for q in data.get("active", []):
		active_quests.append(String(q))
	completed.clear()
	for q in data.get("completed", []):
		completed.append(String(q))


func reset_for_new_game() -> void:
	active_quests.clear()
	completed.clear()
