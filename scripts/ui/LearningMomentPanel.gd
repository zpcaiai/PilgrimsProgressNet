extends CanvasLayer
## Short, flow-integrated learning moments. They are intentionally low-friction:
## one Scripture/value thought, one reflection, one prayer, one continue button.

var _root: Control
var _title: Label
var _body: RichTextLabel
var _continue: Button
var _queue: Array = []
var _current: Dictionary = {}


func _ready() -> void:
	layer = 155
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	EventBus.learning_moment_requested.connect(_on_learning_moment)
	EventBus.scripture_card_received.connect(_on_scripture_card)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.075, 0.11, 0.98)
	sb.border_color = Color(0.86, 0.73, 0.42, 0.72)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(720, 0)
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	vb.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 230)
	_body.add_theme_font_size_override("normal_font_size", 21)
	vb.add_child(_body)

	_continue = Button.new()
	_continue.text = "继续默想 / Continue"
	_continue.custom_minimum_size = Vector2(0, 48)
	_continue.add_theme_font_size_override("font_size", 20)
	_continue.pressed.connect(_hide_current)
	vb.add_child(_continue)

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _apply_layout() -> void:
	if not is_instance_valid(_body):
		return
	var s := get_viewport().get_visible_rect().size
	var mobile := DisplayServer.is_touchscreen_available() or minf(s.x, s.y) <= 640.0
	var w := minf(s.x - 44.0, 720.0)
	var h := minf(s.y - 80.0, 520.0)
	var panel := _title.get_parent() as Control
	if panel:
		panel.custom_minimum_size = Vector2(maxf(320.0, w), 0)
	_title.add_theme_font_size_override("font_size", 28 if not mobile else 26)
	_body.custom_minimum_size = Vector2(0, maxf(220.0, h - 150.0))
	_body.add_theme_font_size_override("normal_font_size", 21 if not mobile else 23)
	_body.scroll_active = mobile
	_body.fit_content = not mobile
	_continue.add_theme_font_size_override("font_size", 20 if not mobile else 22)


func _process(_delta: float) -> void:
	if _root.visible or _queue.is_empty():
		return
	if get_tree().paused:
		return
	if DialogueManager.is_active():
		return
	_show(_queue.pop_front())


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_hide_current()
			get_viewport().set_input_as_handled()


func _on_learning_moment(moment: Dictionary) -> void:
	if moment.is_empty():
		return
	_queue.append(moment.duplicate(true))


func _on_scripture_card(card_id: String) -> void:
	var card := ScriptureMemory.get_card(card_id)
	if card.is_empty():
		return
	_queue.append({
		"title": "经文记忆：" + String(card.get("ref", "")),
		"body": ScriptureMemory.learning_body(card),
	})


func _show(moment: Dictionary) -> void:
	_current = moment.duplicate(true)
	_title.text = String(moment.get("title", "学习时刻"))
	_body.text = String(moment.get("body", ""))
	_root.visible = true
	visible = true
	EventBus.player_control_locked.emit(true)


func _hide_current() -> void:
	if not _current.is_empty():
		var flag := String(_current.get("flag_on_continue", ""))
		if flag != "" and not GameState.has_flag(flag):
			GameState.set_flag(flag, true)
			var effects: Dictionary = _current.get("effects_on_continue", {})
			if not effects.is_empty():
				SpiritualStateManager.apply_effects(effects)
	_current = {}
	_root.visible = false
	visible = false
	EventBus.player_control_locked.emit(false)
