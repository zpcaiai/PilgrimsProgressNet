extends Node
## JourneyJournal
## Persistent formation log: chapter milestones, choices, Scripture cards and
## warning thresholds. Autoloaded as "JourneyJournal".

const MAX_ENTRIES := 200

var entries: Array = []


func _ready() -> void:
	if EventBus.has_signal("chapter_started"):
		EventBus.chapter_started.connect(func(chapter_id): add_entry("chapter", "进入章节", "开始：" + _chapter_title(chapter_id), {"chapter_id": chapter_id}))
	if EventBus.has_signal("chapter_completed"):
		EventBus.chapter_completed.connect(func(chapter_id): add_entry("chapter", "完成章节", "完成：" + _chapter_title(chapter_id), {"chapter_id": chapter_id}))
	if EventBus.has_signal("choice_selected"):
		EventBus.choice_selected.connect(func(choice_id): add_entry("choice", "属灵选择", "选择：" + String(choice_id), {"choice_id": choice_id, "chapter_id": GameState.current_chapter_id}))
	if EventBus.has_signal("scripture_card_received"):
		EventBus.scripture_card_received.connect(func(card_id): add_entry("scripture", "经文记忆", "记住经文：" + String(card_id), {"card_id": card_id}))
	if EventBus.has_signal("spiritual_threshold_crossed"):
		EventBus.spiritual_threshold_crossed.connect(_on_threshold)


func add_entry(kind: String, title: String, body: String, meta: Dictionary = {}) -> void:
	entries.append({
		"kind": kind,
		"title": title,
		"body": body,
		"chapter_id": String(meta.get("chapter_id", GameState.current_chapter_id)),
		"meta": meta.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
	})
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()


func latest(count: int = 6) -> Array:
	var out: Array = []
	for i in range(maxi(0, entries.size() - count), entries.size()):
		out.append(entries[i])
	out.reverse()
	return out


func summary_text(count: int = 6) -> String:
	var lines: Array = []
	for e in latest(count):
		lines.append("  · %s：%s" % [String(e.get("title", "")), String(e.get("body", ""))])
	return "\n".join(PackedStringArray(lines)) if not lines.is_empty() else "  · 旅程刚刚开始。"


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	entries = data.get("entries", []).duplicate(true)


func _on_threshold(state_name: String, threshold: String, _old_value: int, new_value: int) -> void:
	if not threshold.begins_with("above_"):
		return
	if not SpiritualStateManager.NEGATIVE_STATES.has(state_name):
		return
	add_entry("warning", "内心警醒", "%s 到达 %d；需要祷告、悔改或回想经文。" % [_state_label(state_name), new_value], {"state": state_name})


func _chapter_title(chapter_id: String) -> String:
	var d := ChapterManager.load_chapter_data(String(chapter_id)) if ChapterManager else {}
	return String(d.get("title_zh", d.get("title", chapter_id)))


func _state_label(state_name: String) -> String:
	var names := {
		"despair": "绝望", "shame": "羞愧", "fear": "惧怕", "pride": "骄傲",
		"deception": "迷惑", "weariness": "疲惫", "temptation": "试探", "doubt": "疑惑",
	}
	return names.get(state_name, state_name)
