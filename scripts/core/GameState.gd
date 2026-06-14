extends Node
## GameState
## Global runtime state: flags, inventory, companions, progress.
## All persistent story booleans live in `flags`. Autoloaded as "GameState".

var current_chapter_id: String = ""
var current_scene_path: String = ""
var checkpoint_id: String = "start"
var player_position: Vector3 = Vector3.ZERO

# "standard" (full difficulty) or "child" (gentler journey for ~10-year-olds)
var difficulty: String = "standard"

var flags: Dictionary = {}
var inventory: Dictionary = {}
var companions: Dictionary = {}
var completed_quests: Array[String] = []
var visited_chapters: Array[String] = []


func is_child_mode() -> bool:
	return difficulty == "child"


func reset_for_new_game() -> void:
	current_chapter_id = ""
	current_scene_path = ""
	checkpoint_id = "start"
	player_position = Vector3.ZERO
	# difficulty is set by the title screen after reset; default to standard.
	difficulty = "standard"
	flags.clear()
	inventory.clear()
	companions.clear()
	completed_quests.clear()
	visited_chapters.clear()


# --- Flags ---
func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default_value: Variant = false) -> Variant:
	return flags.get(key, default_value)


func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))


# --- Inventory ---
func add_inventory_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount


func has_inventory_item(item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0


func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


# --- Companions ---
func add_companion(companion_id: String) -> void:
	companions[companion_id] = true


func remove_companion(companion_id: String) -> void:
	companions.erase(companion_id)


func has_companion(companion_id: String) -> bool:
	return companions.has(companion_id)


# --- Progress ---
func mark_chapter_visited(chapter_id: String) -> void:
	if not visited_chapters.has(chapter_id):
		visited_chapters.append(chapter_id)


func mark_quest_completed(quest_id: String) -> void:
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)


# --- Serialization ---
func to_dict() -> Dictionary:
	return {
		"current_chapter_id": current_chapter_id,
		"current_scene_path": current_scene_path,
		"checkpoint_id": checkpoint_id,
		"difficulty": difficulty,
		"flags": flags.duplicate(true),
		"inventory": inventory.duplicate(true),
		"companions": companions.duplicate(true),
		"completed_quests": completed_quests.duplicate(),
		"visited_chapters": visited_chapters.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	current_chapter_id = String(data.get("current_chapter_id", ""))
	current_scene_path = String(data.get("current_scene_path", ""))
	checkpoint_id = String(data.get("checkpoint_id", "start"))
	difficulty = String(data.get("difficulty", "standard"))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	inventory = (data.get("inventory", {}) as Dictionary).duplicate(true)
	companions = (data.get("companions", {}) as Dictionary).duplicate(true)
	completed_quests.clear()
	for q in data.get("completed_quests", []):
		completed_quests.append(String(q))
	visited_chapters.clear()
	for c in data.get("visited_chapters", []):
		visited_chapters.append(String(c))
