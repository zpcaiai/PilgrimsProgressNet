extends Node
## SaveManager
## Serializes GameState + SpiritualState + QuestManager to user://saves.
## Autoloaded as "SaveManager".

const SAVE_DIR := "user://saves/"
const VERSION := "0.1.0"


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _slot_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + ".json"


func has_save(slot_id: String = "slot_1") -> bool:
	return FileAccess.file_exists(_slot_path(slot_id))


func save_game(slot_id: String = "slot_1", announce: bool = true) -> void:
	_ensure_dir()
	var payload := {
		"version": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": GameState.to_dict(),
		"spiritual_state": SpiritualStateManager.to_dict(),
		"quest_state": QuestManager.to_dict(),
	}
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write save " + slot_id)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.save_completed.emit(slot_id)
	if announce:
		EventBus.toast("Game saved.")


func load_game(slot_id: String = "slot_1") -> bool:
	if not has_save(slot_id):
		EventBus.toast("No save found.")
		return false
	var text := FileAccess.get_file_as_string(_slot_path(slot_id))
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveManager: corrupt save " + slot_id)
		return false
	var data: Dictionary = parsed
	GameState.from_dict(data.get("game_state", {}))
	SpiritualStateManager.from_dict(data.get("spiritual_state", {}))
	QuestManager.from_dict(data.get("quest_state", {}))
	EventBus.load_completed.emit(slot_id)
	EventBus.toast("Game loaded.")
	return true


func delete_save(slot_id: String = "slot_1") -> void:
	if has_save(slot_id):
		DirAccess.remove_absolute(_slot_path(slot_id))


func get_save_summary(slot_id: String = "slot_1") -> Dictionary:
	if not has_save(slot_id):
		return {}
	var text := FileAccess.get_file_as_string(_slot_path(slot_id))
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return {
			"chapter": String((parsed.get("game_state", {}) as Dictionary).get("current_chapter_id", "")),
			"timestamp": String(parsed.get("timestamp", "")),
		}
	return {}
