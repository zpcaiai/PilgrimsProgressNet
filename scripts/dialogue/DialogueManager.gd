extends Node
## DialogueManager
## Loads branching dialogue from res://data/dialogues and drives it node-by-node.
## Choices apply spiritual effects, flags, items, and quest actions.
## Autoloaded as "DialogueManager".

const DIALOGUE_DIR := "res://data/dialogues/"

var _current_dialogue: Dictionary = {}
var _current_dialogue_id: String = ""
var _current_node_id: String = ""
var _active: bool = false


func is_active() -> bool:
	return _active


func load_dialogue(dialogue_id: String) -> Dictionary:
	var path := DIALOGUE_DIR + dialogue_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("DialogueManager: missing dialogue " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("DialogueManager: failed to parse " + path)
	return {}


func start_dialogue(dialogue_id: String, start_node: String = "start") -> void:
	if _active:
		return
	var data := load_dialogue(dialogue_id)
	if data.is_empty() or not data.has("nodes"):
		return
	_current_dialogue = data
	_current_dialogue_id = dialogue_id
	_current_node_id = start_node
	_active = true
	EventBus.player_control_locked.emit(true)
	EventBus.dialogue_started.emit(dialogue_id)
	_emit_current_node()


func get_current_node() -> Dictionary:
	var nodes: Dictionary = _current_dialogue.get("nodes", {})
	return nodes.get(_current_node_id, {})


## Returns choices the player is currently allowed to pick (conditions met).
func get_available_choices() -> Array:
	var node := get_current_node()
	var result: Array = []
	for choice in node.get("choices", []):
		if _choice_conditions_met(choice):
			result.append(choice)
	return result


func _choice_conditions_met(choice: Dictionary) -> bool:
	var cond: Dictionary = choice.get("conditions", {})
	if cond.is_empty():
		return true
	for key in cond.keys():
		if key.ends_with("_min"):
			var state_name: String = key.substr(0, key.length() - 4)
			if SpiritualStateManager.get_state(state_name) < int(cond[key]):
				return false
		elif key.ends_with("_max"):
			var state_name: String = key.substr(0, key.length() - 4)
			if SpiritualStateManager.get_state(state_name) > int(cond[key]):
				return false
		elif key == "requires_flag":
			if not GameState.has_flag(String(cond[key])):
				return false
		elif key == "requires_item":
			if not GameState.has_inventory_item(String(cond[key])):
				return false
	return true


func select_choice(choice_id: String) -> void:
	if not _active:
		return
	var node := get_current_node()
	for choice in node.get("choices", []):
		if String(choice.get("id", "")) == choice_id:
			EventBus.choice_selected.emit(choice_id)
			_apply_choice(choice)
			var next: String = String(choice.get("next", ""))
			if next == "" or next == "end":
				end_dialogue()
			else:
				_current_node_id = next
				_emit_current_node()
			return


func _apply_choice(choice: Dictionary) -> void:
	# Spiritual effects / flags / items
	var effects: Dictionary = {}
	for key in choice.keys():
		if SpiritualStateManager.NUMERIC_STATES.has(key):
			effects[key] = choice[key]
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	if choice.has("effects"):
		SpiritualStateManager.apply_effects(choice["effects"])
	if choice.has("flags"):
		for k in (choice["flags"] as Dictionary).keys():
			GameState.set_flag(String(k), choice["flags"][k])
	if choice.has("items"):
		for k in (choice["items"] as Dictionary).keys():
			GameState.add_inventory_item(String(k), int(choice["items"][k]))
	if choice.has("special"):
		SpiritualStateManager._apply_special(choice["special"])
	# Quest hooks
	if choice.has("start_quest"):
		QuestManager.start_quest(String(choice["start_quest"]))
	if choice.has("complete_quest"):
		QuestManager.complete_quest(String(choice["complete_quest"]))
	# Re-evaluate active quests in case a flag was set.
	for q in QuestManager.get_active_quests().duplicate():
		QuestManager.update_quest_progress(q)


func _emit_current_node() -> void:
	var node := get_current_node()
	if bool(node.get("end", false)):
		end_dialogue()
		return
	# Auto-apply node-level on_enter effects (optional).
	if node.has("on_enter"):
		SpiritualStateManager.apply_effects(node["on_enter"])
	EventBus.dialogue_node_changed.emit(node)


func end_dialogue() -> void:
	if not _active:
		return
	var ended_id := _current_dialogue_id
	_active = false
	_current_dialogue = {}
	_current_dialogue_id = ""
	_current_node_id = ""
	EventBus.dialogue_ended.emit(ended_id)
	EventBus.player_control_locked.emit(false)
