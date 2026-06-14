extends CanvasLayer
## MarkerInput
## Lets the player leave a written "marker" (a word of encouragement) at their
## current spot for other pilgrims to find. Toggle with M. Submits via
## GhostService.leave_marker(). No-op when networking is disabled/offline.

const FONT_TITLE := 20
const FONT_BODY := 18
const MAX_LEN := 80

var _dim: ColorRect
var _panel: Panel
var _edit: LineEdit
var _hint: Label
var _open: bool = false


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_open(false)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.1, 0.98)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 12)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", s)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-300, -110)
	_panel.size = Vector2(600, 220)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "在此留一句话，赠予后来的同行者"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	vb.add_child(title)

	_edit = LineEdit.new()
	_edit.max_length = MAX_LEN
	_edit.placeholder_text = "例如：白日将尽，仍要前行……"
	_edit.add_theme_font_size_override("font_size", FONT_BODY)
	_edit.custom_minimum_size = Vector2(0, 44)
	_edit.text_submitted.connect(func(_t): _submit())
	vb.add_child(_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var send := Button.new()
	send.text = "留下路标 (Enter)"
	send.add_theme_font_size_override("font_size", FONT_BODY)
	send.custom_minimum_size = Vector2(220, 42)
	send.pressed.connect(_submit)
	row.add_child(send)

	var cancel := Button.new()
	cancel.text = "取消 (Esc)"
	cancel.add_theme_font_size_override("font_size", FONT_BODY)
	cancel.custom_minimum_size = Vector2(150, 42)
	cancel.pressed.connect(func(): _set_open(false))
	row.add_child(cancel)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vb.add_child(_hint)


func _can_use() -> bool:
	if not NetConfig.enabled:
		return false
	var auth := get_node_or_null("/root/AuthService")
	return auth != null and auth.is_online


func _submit() -> void:
	var text := _edit.text.strip_edges()
	if text == "":
		_set_open(false)
		return
	GhostService.leave_marker(text)
	EventBus.toast("你的路标已留在此处。")
	_edit.text = ""
	_set_open(false)


func _set_open(v: bool) -> void:
	_open = v
	_dim.visible = v
	_panel.visible = v
	get_tree().paused = v
	if v:
		_hint.text = "其他朝圣者下次走到这一关时，会看到你留下的话。"
		_edit.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _open and event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_M and not _open:
		if not _can_use():
			EventBus.toast("离线状态：联网后才能留下路标。")
			get_viewport().set_input_as_handled()
			return
		_set_open(true)
		get_viewport().set_input_as_handled()
