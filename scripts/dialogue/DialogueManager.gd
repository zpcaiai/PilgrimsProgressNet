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
			result.append(_localize_choice(choice))
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
		elif key == "temptation":
			# {"type":"comfort_shortcut","difficulty":40} — wise choice only if you can resist that temptation.
			var t: Dictionary = cond[key]
			if not SpiritualStateManager.can_resist_temptation(String(t.get("type", "")), int(t.get("difficulty", 0))):
				return false
	return true


## Plain-text signed summary of a choice's spiritual effects (for a HUD hint), e.g. "信+10 惧-5".
func get_choice_effect_hint(choice: Dictionary) -> String:
	var eff: Dictionary = {}
	for key in choice.keys():
		if SpiritualStateManager.NUMERIC_STATES.has(key):
			eff[key] = int(eff.get(key, 0)) + int(choice[key])
	if choice.has("effects") and choice["effects"] is Dictionary:
		for k in (choice["effects"] as Dictionary).keys():
			if SpiritualStateManager.NUMERIC_STATES.has(k):
				eff[k] = int(eff.get(k, 0)) + int(choice["effects"][k])
	var names := {"faith":"信","hope":"望","humility":"谦","discernment":"辨","perseverance":"毅","watchfulness":"警","despair":"绝","shame":"羞","fear":"惧","pride":"傲","deception":"欺","weariness":"乏"}
	var parts: Array = []
	for k in eff.keys():
		var v := int(eff[k])
		if v != 0:
			parts.append("%s%+d" % [names.get(k, k), v])
	return " ".join(PackedStringArray(parts))

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
		for k in (choice["effects"] as Dictionary).keys():
			if SpiritualStateManager.NUMERIC_STATES.has(k):
				effects[k] = int(effects.get(k, 0)) + int(choice["effects"][k])
	var value_feedback := ScriptureMemory.choice_feedback(effects)
	if value_feedback != "":
		EventBus.toast(value_feedback)
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
	# Node-level flags: reaching a node reliably sets story flags even if the
	# player leaves before picking a flag-bearing choice (prevents soft-locks).
	if node.has("set_flags"):
		for fk in (node["set_flags"] as Dictionary).keys():
			GameState.set_flag(String(fk), node["set_flags"][fk])
	node = _resolve_text_variant(node)
	node = _localize_node(node)
	EventBus.dialogue_node_changed.emit(node)

## NPCs can read the pilgrim's state: a node may carry `text_variants` (each with
## `conditions` + `text`); the first whose conditions pass replaces the line.
func _resolve_text_variant(node: Dictionary) -> Dictionary:
	if not node.has("text_variants"):
		return node
	for v in node["text_variants"]:
		if v is Dictionary and _choice_conditions_met(v):
			var copy := node.duplicate(true)
			copy["text"] = String(v.get("text", node.get("text", "")))
			if v.has("text_zh"):
				copy["text_zh"] = String(v["text_zh"])
			else:
				copy.erase("text_zh")
			return copy
	return node


## Bilingual: when the locale is zh, swap in the node's text_zh / speaker_zh if
## present. Dialogue JSON stays backward-compatible; untranslated nodes are
## clearly marked in Chinese instead of appearing as pure English.
func _localize_node(node: Dictionary) -> Dictionary:
	var copy := node.duplicate(true)
	var en_text := String(node.get("text", ""))
	var zh_text := String(node.get("text_zh", ""))
	copy["text"] = (zh_text if zh_text != "" else LocaleManager.zh_or_mixed(en_text)) if LocaleManager.is_zh() else LocaleManager.bilingual(zh_text, en_text)
	var spk := String(node.get("speaker", ""))
	if spk != "":
		# Per-node speaker_zh wins; otherwise the central npc.<name> table localizes it.
		var spk_zh := String(node.get("speaker_zh", ""))
		copy["speaker"] = spk_zh if spk_zh != "" and LocaleManager.is_zh() else LocaleManager.t("npc." + spk, spk)
	return copy


func _localize_choice(choice: Dictionary) -> Dictionary:
	var c := choice.duplicate(true)
	var en := String(choice.get("text", ""))
	var zh := String(choice.get("text_zh", ""))
	c["text"] = (zh if zh != "" else LocaleManager.zh_or_mixed(en)) if LocaleManager.is_zh() else LocaleManager.bilingual(zh, en)
	return c


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
