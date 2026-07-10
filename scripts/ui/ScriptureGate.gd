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
const ResponsiveLayout := preload("res://scripts/ui/ResponsiveLayout.gd")
static var _data: Dictionary = {}

var _q: Dictionary = {}
var _chapter_id: String = ""
var _on_pass: Callable = Callable()
var _on_leave: Callable = Callable()
var _root: Control
var _panel: PanelContainer
var _frame: VBoxContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _feedback: Label
var _leave_button: Button
var _buttons: Array = []
var _answered := false


func _viewport_size() -> Vector2:
	return ResponsiveLayout.viewport_size(self)


func _is_mobile_ui() -> bool:
	return ResponsiveLayout.is_mobile(self)


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
	layer = 230
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var mobile := _is_mobile_ui()
	var body_font := 23 if mobile else 20
	var prompt_font := 25 if mobile else 22
	var title_font := 30 if mobile else 26
	var small_font := 18 if mobile else 15
	var feedback_font := 20 if mobile else 17

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.56)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.13, 0.98)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18 if mobile else 24)
	sb.border_color = Color(0.85, 0.74, 0.4, 0.7)
	sb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	_frame = VBoxContainer.new()
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_theme_constant_override("separation", 10)
	_panel.add_child(_frame)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var title := Label.new()
	title.text = "✝  经文之门 · Scripture Gate"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", title_font)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_content.add_child(title)

	var refl := Label.new()
	refl.text = LocaleManager.zh_or_mixed(String(_q.get("ref", "")))
	refl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refl.add_theme_font_size_override("font_size", feedback_font)
	refl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.95))
	_content.add_child(refl)

	var prompt := Label.new()
	prompt.text = LocaleManager.zh_or_mixed(String(_q.get("prompt", "")))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", prompt_font)
	_content.add_child(prompt)

	var prompt_en := String(_q.get("prompt_en", ""))
	if prompt_en != "":
		var pe := Label.new()
		pe.text = ("英文提示：" + prompt_en) if LocaleManager.is_zh() else prompt_en
		pe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pe.add_theme_font_size_override("font_size", small_font)
		pe.add_theme_color_override("font_color", Color(0.62, 0.64, 0.7))
		_content.add_child(pe)

	_content.add_child(HSeparator.new())

	# Shuffle option order so the correct answer isn't always in the same slot.
	var opts: Array = _q.get("options", [])
	var order: Array = range(opts.size())
	order.shuffle()
	for oi in order:
		var b := Button.new()
		b.text = "   " + LocaleManager.zh_or_mixed(String(opts[oi]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64 if mobile else 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.add_theme_font_size_override("font_size", body_font)
		var ans := int(oi)
		var btn := b
		b.pressed.connect(func(): _choose(ans, btn))
		_content.add_child(b)
		_buttons.append(b)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", feedback_font)
	_content.add_child(_feedback)

	_leave_button = Button.new()
	_leave_button.text = "稍后再来 (Leave)"
	_leave_button.custom_minimum_size = Vector2(0, 50 if mobile else 0)
	_leave_button.add_theme_font_size_override("font_size", 19 if mobile else 16)
	ResponsiveLayout.set_modal_action(_leave_button, 48.0)
	_leave_button.pressed.connect(_leave)
	_root.add_child(_leave_button)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _apply_layout() -> void:
	if not is_instance_valid(_panel):
		return
	var mobile := _is_mobile_ui()
	ResponsiveLayout.fit_fullscreen(_root, self)
	var size := ResponsiveLayout.fit_center_panel(_panel, self, Vector2(760.0, 620.0), Vector2(260.0, 320.0))
	var content_w := maxf(220.0, size.x - (44.0 if mobile else 56.0))
	var scroll_h := maxf(180.0, size.y - (108.0 if mobile else 114.0))
	if is_instance_valid(_scroll):
		_scroll.custom_minimum_size = Vector2(content_w, scroll_h)
	if is_instance_valid(_content):
		_content.custom_minimum_size = Vector2(content_w, 0)
	ResponsiveLayout.normalize_tree(_panel, mobile)
	if is_instance_valid(_leave_button):
		var action_h := 54.0 if mobile else 48.0
		_leave_button.add_theme_font_size_override("font_size", 19 if mobile else 16)
		if mobile:
			ResponsiveLayout.place_viewport_action(_leave_button, self, action_h, 18.0)
		else:
			ResponsiveLayout.place_panel_action(_leave_button, _panel, action_h, 24.0)
	for b in _buttons:
		if is_instance_valid(b):
			(b as Button).autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART
			(b as Button).custom_minimum_size = Vector2(0, 66 if mobile else 52)


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
