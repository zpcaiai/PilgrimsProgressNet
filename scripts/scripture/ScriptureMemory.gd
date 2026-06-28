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


func chapter_preview_line(chapter_id: String) -> String:
	var card := get_chapter_card(chapter_id)
	if card.is_empty():
		return ""
	return "本章默想：%s｜%s。%s" % [
		String(card.get("ref", "")),
		_card_theme(card),
		String(card.get("memory_zh", card.get("memory_en", "")))
	]


func learning_body(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	var value := _value_line(card)
	var question := _reflection_question(card)
	var practice := _practice_line(card)
	var prayer := _prayer_line(card)
	var lines := PackedStringArray()
	lines.append("[b]经文[/b]  %s" % String(card.get("ref", "")))
	lines.append("[b]主题[/b]  %s" % _card_theme(card))
	lines.append("[b]要义[/b]  %s" % String(card.get("memory_zh", card.get("memory_en", ""))))
	lines.append("[b]基督徒价值[/b]  %s" % value)
	lines.append("[b]想一想[/b]  %s" % question)
	lines.append("[b]走一步[/b]  %s" % practice)
	lines.append("[b]祷告[/b]  [i]%s[/i]" % prayer)
	return "\n\n".join(lines)


func known_card_summary(max_count: int = 5) -> String:
	var cards := known_cards()
	if cards.is_empty():
		return "尚未记住经文。经过经文之门后，会把经文记在这里。"
	var lines: Array = []
	var count := mini(cards.size(), max_count)
	for i in range(count):
		var card: Dictionary = cards[i]
		lines.append("  • %s｜%s" % [String(card.get("ref", "")), _card_theme(card)])
	if cards.size() > count:
		lines.append("  • 还有 %d 张经文卡，可在旅程中继续默想。" % (cards.size() - count))
	return "\n".join(PackedStringArray(lines))


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


func _value_line(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if tags.has("humility") or tags.has("pride"):
		return "谦卑不是自我否定，而是承认自己需要神的恩典与真理。"
	if tags.has("deception") or tags.has("discernment"):
		return "分辨力让人不被热闹、恐惧或谎言牵走，而是回到神的话。"
	if tags.has("fear") or tags.has("presence"):
		return "勇敢不是没有害怕，而是在害怕中相信主仍同在。"
	if tags.has("despair") or tags.has("hope"):
		return "盼望不是乐观口号，而是相信神的怜悯尚未停止。"
	if tags.has("weariness") or tags.has("perseverance") or tags.has("watchfulness"):
		return "忍耐与警醒帮助人把下一步交给主，而不是交给疲乏。"
	return "信心把眼光从自我转向神，使选择不再只由环境决定。"


func _reflection_question(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if tags.has("deception"):
		return "这一章里，哪一种声音最像真理，却其实正在拉你离开真理？"
	if tags.has("fear"):
		return "如果今天惧怕开口命令你，你可以用这节经文怎样回应它？"
	if tags.has("despair"):
		return "当心里说“已经没有路了”时，这节经文提醒你还有什么？"
	if tags.has("pride"):
		return "你在哪个选择上最需要放下自夸，重新接受帮助？"
	if tags.has("weariness"):
		return "你下一步只需要忠心做哪一件小事？"
	return "这节经文怎样改变你看待本章处境的方式？"


func _practice_line(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if tags.has("prayer"):
		return "停下几秒，把这节经文变成一句简短祷告。"
	if tags.has("decision"):
		return "做下一个选择前，先问：这一步是在靠近神，还是靠近旧安全感？"
	if tags.has("armor"):
		return "遇到控告或试探时，先回想真理，再行动。"
	if tags.has("watchfulness"):
		return "留意让心沉睡的舒适，选择一个清醒的小行动。"
	return "把经文中的一个词带进下一段路，边走边默念。"


func _prayer_line(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if tags.has("humility"):
		return "主啊，赐我谦卑的心，使我愿意受教，也愿意接受帮助。"
	if tags.has("fear"):
		return "主啊，当我害怕时，求你使我记得你的同在比黑暗更真实。"
	if tags.has("despair"):
		return "主啊，求你在绝望处扶起我，使我的脚重新站在磐石上。"
	if tags.has("deception"):
		return "主啊，用你的话校准我的眼光，使我能分辨真实与谎言。"
	if tags.has("weariness"):
		return "主啊，求你赐我今天够用的忍耐，使我忠心走下一步。"
	return "主啊，使这节经文不只停在眼前，也住进我的选择里。"


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
