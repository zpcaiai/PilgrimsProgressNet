extends CanvasLayer
class_name ScriptureGate
## A chapter's Scripture Gate: to pass on, the pilgrim must answer the chapter's
## key Bible verse. Correct -> proceeds (on_pass). Wrong -> a gentle word, and
## the player chooses again. A "Leave" option lets them step back and return.
##
## Data: data/scripture/scripture_gates.json, keyed by chapter_id. If a chapter
## has no entry the gate is skipped (on_pass fires immediately), so this can be
## rolled out chapter by chapter without breaking flow.

const DATA_PATH := "res://data/scripture/scripture_gates.json"
static var _data: Dictionary = {}

var _q: Dictionary = {}
var _chapter_id: String = ""
var _on_pass: Callable = Callable()
var _on_leave: Callable = Callable()
var _feedback: Label
var _buttons: Array = []
var _answered := false


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _is_mobile_ui() -> bool:
	var s := _viewport_size()
	return DisplayServer.is_touchscreen_available() or minf(s.x, s.y) <= 640.0


static func _all() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func has_question(chapter_id: String) -> bool:
	return _all().get(chapter_id, null) is Dictionary


## Open the gate for `chapter_id`. `on_pass` runs after a correct answer;
## `on_leave` (optional) runs if the player backs out.
static func open(host: Node, chapter_id: String, on_pass: Callable, on_leave: Callable = Callable()) -> void:
	var q: Variant = _all().get(chapter_id, null)
	if not (q is Dictionary):
		if on_pass.is_valid():
			on_pass.call()
		return
	var gate := ScriptureGate.new()
	gate._q = q
	gate._chapter_id = chapter_id
	gate._on_pass = on_pass
	gate._on_leave = on_leave
	host.get_tree().root.add_child(gate)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var mobile := _is_mobile_ui()
	var s := _viewport_size()
	var panel_w := maxf(320.0, minf(740.0, s.x - 48.0)) if mobile else 740.0
	var body_font := 23 if mobile else 20
	var prompt_font := 25 if mobile else 22
	var title_font := 30 if mobile else 26
	var small_font := 18 if mobile else 15
	var feedback_font := 20 if mobile else 17

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.13, 0.98)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18 if mobile else 24)
	sb.border_color = Color(0.85, 0.74, 0.4, 0.7)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(panel_w, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "✝  经文之门 · Scripture Gate"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", title_font)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vb.add_child(title)

	var refl := Label.new()
	refl.text = LocaleManager.zh_or_mixed(String(_q.get("ref", "")))
	refl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refl.add_theme_font_size_override("font_size", feedback_font)
	refl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.95))
	vb.add_child(refl)

	var prompt := Label.new()
	prompt.text = LocaleManager.zh_or_mixed(String(_q.get("prompt", "")))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(panel_w, 0)
	prompt.add_theme_font_size_override("font_size", prompt_font)
	vb.add_child(prompt)

	var prompt_en := String(_q.get("prompt_en", ""))
	if prompt_en != "":
		var pe := Label.new()
		pe.text = ("英文提示：" + prompt_en) if LocaleManager.is_zh() else prompt_en
		pe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pe.custom_minimum_size = Vector2(panel_w, 0)
		pe.add_theme_font_size_override("font_size", small_font)
		pe.add_theme_color_override("font_color", Color(0.62, 0.64, 0.7))
		vb.add_child(pe)

	vb.add_child(HSeparator.new())

	# Shuffle option order so the correct answer isn't always in the same slot.
	var opts: Array = _q.get("options", [])
	var order: Array = range(opts.size())
	order.shuffle()
	for oi in order:
		var b := Button.new()
		b.text = "   " + LocaleManager.zh_or_mixed(String(opts[oi]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(panel_w, 56 if mobile else 46)
		b.add_theme_font_size_override("font_size", body_font)
		var ans := int(oi)
		var btn := b
		b.pressed.connect(func(): _choose(ans, btn))
		vb.add_child(b)
		_buttons.append(b)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(panel_w, 0)
	_feedback.add_theme_font_size_override("font_size", feedback_font)
	vb.add_child(_feedback)

	var leave := Button.new()
	leave.text = "稍后再来 (Leave)"
	leave.custom_minimum_size = Vector2(0, 50 if mobile else 0)
	leave.add_theme_font_size_override("font_size", 19 if mobile else 16)
	leave.pressed.connect(_leave)
	vb.add_child(leave)


func _choose(orig_idx: int, btn: Button) -> void:
	if _answered:
		return
	if orig_idx == int(_q.get("answer", 0)):
		_answered = true
		_feedback.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		_feedback.text = "✔  " + String(_q.get("correct", "正确。"))
		for b in _buttons:
			b.disabled = true
		# Hiding the word in the heart strengthens discernment and faith.
		SpiritualStateManager.apply_effects({"discernment": 3, "faith": 2})
		ScriptureMemory.grant_for_chapter(_chapter_id)
		await get_tree().create_timer(1.2).timeout
		get_tree().paused = false
		if _on_pass.is_valid():
			_on_pass.call()
		queue_free()
	else:
		_feedback.add_theme_color_override("font_color", Color(0.96, 0.5, 0.45))
		_feedback.text = "✘  " + String(_q.get("wrong", "再选一次。 (Choose again.)"))
		if is_instance_valid(btn):
			btn.disabled = true   # grey out the wrong pick; retry the rest


func _leave() -> void:
	get_tree().paused = false
	if _on_leave.is_valid():
		_on_leave.call()
	queue_free()
