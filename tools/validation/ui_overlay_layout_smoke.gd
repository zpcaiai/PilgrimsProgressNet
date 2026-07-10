extends Node
## Verifies chapter overlays and their primary actions stay inside the viewport at
## representative phone, tablet, and desktop sizes. All 16 gates are checked.

const VIEWPORTS := [
	Vector2i(390, 844),
	Vector2i(844, 390),
	Vector2i(768, 1024),
	Vector2i(1280, 720),
	Vector2i(2048, 1054),
]
const GATE_SCRIPT := preload("res://scripts/ui/ScriptureGate.gd")
const CORE_OVERLAYS := [
	{"name": "learning_moment", "script": preload("res://scripts/ui/LearningMomentPanel.gd")},
	{"name": "teaching_guide", "script": preload("res://scripts/ui/TeachingGuidePanel.gd")},
	{"name": "account", "script": preload("res://scripts/ui/AccountPanel.gd")},
	{"name": "cloud_sync", "script": preload("res://scripts/ui/CloudSyncDialog.gd")},
	{"name": "conversation", "script": preload("res://scripts/ui/ConversationPanel.gd")},
	{"name": "leaderboard", "script": preload("res://scripts/ui/LeaderboardPanel.gd")},
	{"name": "marker_input", "script": preload("res://scripts/ui/MarkerInput.gd")},
	{"name": "review", "script": preload("res://scripts/ui/ReviewPanel.gd")},
	{"name": "reward", "script": preload("res://scripts/ui/RewardPopup.gd")},
]

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _inside_viewport(rect: Rect2, viewport: Vector2) -> bool:
	return (rect.position.x >= -1.0 and rect.position.y >= -1.0
			and rect.end.x <= viewport.x + 1.0 and rect.end.y <= viewport.y + 1.0)


func _collect_modal_actions(node: Node, result: Array[Button]) -> void:
	if node is Button and node.has_meta("modal_action"):
		result.append(node as Button)
	for child in node.get_children():
		_collect_modal_actions(child, result)


func _check_panel(label: String, owner: Node, viewport: Vector2) -> void:
	var panel := owner.get("_panel") as Control
	if not is_instance_valid(panel):
		_failures.append("[%s] panel was not created" % label)
		return
	var rect := panel.get_global_rect()
	if not _inside_viewport(rect, viewport):
		_failures.append("[%s] panel %s escaped viewport %s" % [label, rect, viewport])
	var actions: Array[Button] = []
	_collect_modal_actions(owner, actions)
	if actions.is_empty():
		_failures.append("[%s] has no visible next/close action" % label)
	for action in actions:
		var action_rect := action.get_global_rect()
		if not action.visible or action.disabled or not action_rect.has_area():
			_failures.append("[%s] action '%s' is not usable" % [label, action.text])
		elif not _inside_viewport(action_rect, viewport):
			_failures.append("[%s] action '%s' escaped viewport: %s" % [label, action.text, action_rect])
		elif not action.has_meta("viewport_action") and not rect.encloses(action_rect):
			_failures.append("[%s] action '%s' escaped its panel: %s" % [label, action.text, action_rect])
	var scroll := owner.get("_scroll") as ScrollContainer
	var content := owner.get("_content") as Control
	if is_instance_valid(scroll) and is_instance_valid(content):
		if content.size.x > scroll.size.x + 2.0:
			_failures.append("[%s] content width %.1f exceeds scroll width %.1f" % [label, content.size.x, scroll.size.x])


func _set_viewport_size(size: Vector2i) -> void:
	get_tree().root.size = size
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	var original_size := get_tree().root.size
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/scripture/scripture_gates.json"))
	if not (parsed is Dictionary):
		push_error("Unable to load Scripture Gate data")
		get_tree().quit(1)
		return
	var gates := parsed as Dictionary
	var chapter_ids: Array = gates.keys().filter(func(key): return not String(key).begins_with("_"))
	chapter_ids.sort()
	if chapter_ids.size() != 16:
		_failures.append("Expected 16 Scripture Gates, found %d" % chapter_ids.size())

	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		var actual := get_viewport().get_visible_rect().size
		for chapter_id in chapter_ids:
			var gate := GATE_SCRIPT.new()
			gate.set("_q", gates[chapter_id])
			gate.set("_chapter_id", String(chapter_id))
			add_child(gate)
			await get_tree().process_frame
			_check_panel("%s/%s" % [chapter_id, viewport_size], gate, actual)
			get_tree().paused = false
			gate.queue_free()
			await get_tree().process_frame

		for spec in CORE_OVERLAYS:
			var overlay: Node = spec.script.new()
			add_child(overlay)
			await get_tree().process_frame
			_check_panel("%s/%s" % [spec.name, viewport_size], overlay, actual)
			overlay.queue_free()
			await get_tree().process_frame

	await _set_viewport_size(original_size)
	if _failures.is_empty():
		print("UI OVERLAY ACTION SMOKE PASSED: 16 gates and 9 overlay families across 5 viewports")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("UI OVERLAY LAYOUT SMOKE FAILED: %d issue(s)" % _failures.size())
	get_tree().quit(1)
