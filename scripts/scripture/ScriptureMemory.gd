extends Node
## Stores chapter Scripture cards in GameState inventory and helps combat,
## prayer, and story moments recall the right promise in Chinese-first text.

const DATA_PATH := "res://data/scripture/verse_cards.json"
const ITEM_PREFIX := "verse_"

var _cards: Dictionary = {}


func _ready() -> void:
	_load_cards()


func _load_cards() -> Dictionary:
	if not _cards.is_empty():
		return _cards
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("ScriptureMemory: missing " + DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_cards = parsed
	else:
		push_warning("ScriptureMemory: failed to parse " + DATA_PATH)
	return _cards


func get_card(card_id: String) -> Dictionary:
	var card: Variant = _load_cards().get(card_id, {})
	return (card as Dictionary).duplicate(true) if card is Dictionary else {}


func get_chapter_card(chapter_id: String) -> Dictionary:
	for id in _load_cards().keys():
		var card: Dictionary = get_card(String(id))
		if String(card.get("chapter_id", "")) == chapter_id:
			return card
	return {}


func grant_for_chapter(chapter_id: String) -> Dictionary:
	var card := get_chapter_card(chapter_id)
	if card.is_empty():
		return {}
	return grant_card(String(card.get("id", "")))


func grant_card(card_id: String) -> Dictionary:
	var card := get_card(card_id)
	if card.is_empty():
		return {}
	var item_id := ITEM_PREFIX + card_id
	var already_known := GameState.has_inventory_item(item_id)
	if not already_known:
		GameState.add_inventory_item(item_id, 1)
		GameState.set_flag(item_id, true)
		GameState.set_flag("scripture_" + String(card.get("chapter_id", card_id)), true)
		if EventBus.has_signal("scripture_card_received"):
			EventBus.scripture_card_received.emit(card_id)
	if card.has("effects") and card["effects"] is Dictionary:
		SpiritualStateManager.apply_effects(card["effects"])
	var message := "经文记在心里：%s｜%s" % [String(card.get("ref", "")), _card_theme(card)]
	if already_known:
		message = "再次默想：%s｜%s" % [String(card.get("ref", "")), _card_theme(card)]
	EventBus.toast(message)
	return card


func has_card(card_id: String) -> bool:
	return GameState.has_inventory_item(ITEM_PREFIX + card_id)


func known_cards() -> Array:
	var result: Array = []
	for id in _load_cards().keys():
		var card_id := String(id)
		if has_card(card_id):
			result.append(get_card(card_id))
	return result


func recall_current_chapter() -> Dictionary:
	var current := GameState.current_chapter_id
	if current == "":
		current = ChapterManager.current_chapter_id
	var card := get_chapter_card(current)
	if not card.is_empty() and has_card(String(card.get("id", ""))):
		return card
	var known := known_cards()
	if known.is_empty():
		return {}
	return known[known.size() - 1]


func recall_line(card: Dictionary) -> String:
	if card.is_empty():
		return "祷告使心安静下来，重新等待主的话。"
	return "回想经文：%s｜%s。%s" % [
		String(card.get("ref", "")),
		_card_theme(card),
		String(card.get("memory_zh", card.get("memory_en", "")))
	]


func use_for_trial(trial_type: String) -> Dictionary:
	var card := best_card_for_trial(trial_type)
	if card.is_empty():
		return {}
	if card.has("effects") and card["effects"] is Dictionary:
		SpiritualStateManager.apply_effects(card["effects"])
	return card


func best_card_for_trial(trial_type: String) -> Dictionary:
	var desired := _trial_tags(trial_type)
	var best: Dictionary = {}
	var best_score := -1
	for card in known_cards():
		var score := _score_card(card, desired)
		if score > best_score:
			best_score = score
			best = card
	if best_score <= 0:
		return recall_current_chapter()
	return best


func choice_feedback(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""
	if int(effects.get("humility", 0)) > 0 or int(effects.get("pride", 0)) < 0:
		return "价值回应：你选择谦卑受教，而不是靠自己夸胜。"
	if int(effects.get("discernment", 0)) > 0 or int(effects.get("deception", 0)) < 0:
		return "价值回应：你选择分辨真理，不被表面的声音牵走。"
	if int(effects.get("faith", 0)) > 0 or int(effects.get("fear", 0)) < 0:
		return "价值回应：你用信心回应惧怕，继续向前。"
	if int(effects.get("hope", 0)) > 0 or int(effects.get("despair", 0)) < 0:
		return "价值回应：你让盼望胜过绝望。"
	if int(effects.get("perseverance", 0)) > 0 or int(effects.get("weariness", 0)) < 0:
		return "价值回应：你选择忍耐，不让疲乏决定方向。"
	if int(effects.get("pride", 0)) > 0:
		return "提醒：骄傲正在变重，回到谦卑会使路更清楚。"
	if int(effects.get("deception", 0)) > 0:
		return "提醒：欺哄正在变重，需要用真理重新校准。"
	if int(effects.get("fear", 0)) > 0 or int(effects.get("despair", 0)) > 0:
		return "提醒：惧怕或绝望正在逼近，可以祷告并回想经文。"
	return ""


func _score_card(card: Dictionary, desired: Array) -> int:
	var tags: Array = card.get("tags", [])
	var score := 0
	for tag in tags:
		if desired.has(String(tag)):
			score += 3
	var chapter_id := String(card.get("chapter_id", ""))
	if chapter_id == GameState.current_chapter_id or chapter_id == ChapterManager.current_chapter_id:
		score += 1
	return score


func _trial_tags(trial_type: String) -> Array:
	match trial_type:
		"shame":
			return ["shame", "grace", "faith"]
		"despair":
			return ["despair", "hope", "promise"]
		"fear":
			return ["fear", "presence", "faith"]
		"deception":
			return ["deception", "discernment", "teaching"]
		"weariness":
			return ["weariness", "perseverance", "watchfulness"]
		"pride":
			return ["pride", "humility"]
		_:
			return ["faith", "discernment", "hope"]


func _card_theme(card: Dictionary) -> String:
	var zh := String(card.get("theme_zh", ""))
	var en := String(card.get("theme_en", ""))
	if LocaleManager.is_zh():
		return zh if zh != "" else LocaleManager.zh_or_mixed(en)
	return LocaleManager.bilingual(zh, en)
