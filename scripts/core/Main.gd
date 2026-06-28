extends Node3D
## Main
## Root of the game. Owns the world container, HUD, title/end menus, the
## collapse/repentance flow, and developer debug shortcuts.

const HUD_SCRIPT := preload("res://scripts/ui/HUD.gd")
const DATA_VALIDATOR := preload("res://scripts/core/DataValidator.gd")
const NET_UI := preload("res://scenes/ui/NetUI.tscn")
const TOUCH_CONTROLS := preload("res://scripts/ui/TouchControls.gd")

var _world_root: Node3D
var _hud: CanvasLayer
var _menu_layer: CanvasLayer
var _menu_root: Control
var _route_layer: CanvasLayer
var _route_visible: bool = false
var _pause_layer: CanvasLayer
var _pause_visible: bool = false
var _in_game: bool = false
var _touch: CanvasLayer


func _ready() -> void:
	_ensure_input_actions()
	_load_video_settings()
	_apply_ui_scale()

	_world_root = Node3D.new()
	_world_root.name = "World"
	add_child(_world_root)
	ChapterManager.set_world_root(_world_root)

	_hud = HUD_SCRIPT.new()
	_hud.visible = false
	add_child(_hud)

	# Networked overlays (leaderboard B / companions / cloud-sync dialog /
	# marker input M). Self-hide and no-op when networking is offline, so this
	# is safe even with no backend running.
	add_child(NET_UI.instantiate())

	# On-screen touch keypad (WASD + Space/E + 1-4 + C/Tab/Esc). Only active on a
	# touchscreen; self-hides outside gameplay. See scripts/ui/TouchControls.gd.
	_touch = TOUCH_CONTROLS.new()
	add_child(_touch)

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	add_child(_menu_layer)

	_route_layer = CanvasLayer.new()
	_route_layer.layer = 15
	add_child(_route_layer)

	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 22
	add_child(_pause_layer)

	EventBus.demo_completed.connect(_on_demo_completed)
	EventBus.spiritual_collapse.connect(_on_collapse)
	EventBus.settings_changed.connect(_apply_ui_scale)

	_show_title()


# ---------------------------------------------------------------------------
# Input map safety net (in case project.godot input section is unavailable)
# ---------------------------------------------------------------------------
func _ensure_input_actions() -> void:
	var defs := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
	}
	for action in defs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	# --- Gamepad bindings (left stick + d-pad move, A jump, X interact) ---
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_bind_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_bind_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_bind_button("move_forward", JOY_BUTTON_DPAD_UP)
	_bind_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_bind_button("jump", JOY_BUTTON_A)
	_bind_button("interact", JOY_BUTTON_X)
	# --- Camera look (right stick) ---
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
	_bind_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	# --- Menu navigation on a controller ---
	_bind_button("ui_accept", JOY_BUTTON_A)
	_bind_button("ui_cancel", JOY_BUTTON_B)


func _bind_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _bind_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------------------
# Menu helpers
# ---------------------------------------------------------------------------
func _clear_menu() -> void:
	for c in _menu_layer.get_children():
		c.queue_free()
	_menu_root = null


func _make_fullscreen_panel(bg: Color) -> Control:
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rect := ColorRect.new()
	rect.color = bg
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(rect)
	_menu_layer.add_child(ctrl)
	_menu_root = ctrl
	return ctrl


func _make_centered_box(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.custom_minimum_size = Vector2(520, 0)
	center.add_child(vb)
	return vb


func _add_title(vb: VBoxContainer, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(text)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	vb.add_child(lbl)


func _add_button(vb: VBoxContainer, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = LocaleManager.zh_or_mixed(text)
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(cb)
	vb.add_child(btn)
	return btn


# ---------------------------------------------------------------------------
# Title screen
# ---------------------------------------------------------------------------
func _show_title() -> void:
	_in_game = false
	if _touch:
		_touch.set_gameplay(false)
	_hud.visible = false
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.04, 0.04, 0.08, 1.0))
	# Optional title key art behind the menu (existence-checked; dimmed for text).
	var key_art := AssetLib.ui("title_key_art")
	if key_art != null:
		var bg := TextureRect.new()
		bg.texture = key_art
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate = Color(1, 1, 1, 0.55)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bg)
	# Optional title-screen music (silently skipped if the file is absent).
	AudioManager.play_music("res://assets/audio/music/title.ogg")
	var vb := _make_centered_box(panel)
	# Roomier vertical spacing between title-menu rows (e.g. between the journey buttons).
	vb.add_theme_constant_override("separation", 30)
	_add_title(vb, LocaleManager.t("menu.title", "PILGRIM'S ROAD"), 48, Color(0.95, 0.88, 0.6))
	_add_title(vb, LocaleManager.t("menu.subtitle", "Burden Fallen"), 26, Color(0.7, 0.78, 0.9))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	_add_title(vb, LocaleManager.t("menu.choose", "Choose your journey"), 18, Color(0.7, 0.72, 0.82))
	_add_button(vb, LocaleManager.t("menu.devout", "Devout Journey  (full)"), _start_standard)
	_add_button(vb, LocaleManager.t("menu.child", "Children's Journey  (gentle, easy to finish)"), _start_child)
	if SaveManager.has_save("slot_1"):
		var summary := SaveManager.get_save_summary("slot_1")
		_add_button(vb, LocaleManager.t("menu.continue", "Continue (%s)") % String(summary.get("chapter", "")), continue_game)
	_add_button(vb, LocaleManager.t("menu.options", "Options"), _options_from_title)
	_add_button(vb, LocaleManager.t("menu.quit", "Quit"), func(): get_tree().quit())
	_add_button(vb, LocaleManager.switch_label(), func(): LocaleManager.toggle(); _show_title())
	var hint := Label.new()
	hint.text = LocaleManager.t("menu.hint_touch", "左下方向区移动 · 点「跳跃」跳 · 点「互动」交互/继续对话 · 点「心境」查看/关闭心境 · 点「地图」看路线 · 点「暂停」打开菜单") if DisplayServer.is_touchscreen_available() else LocaleManager.t("menu.hint", "WASD move · Space jump · E interact · 1-4 choose · C heart · Tab map · Esc pause")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(hint)


func _start_standard() -> void:
	start_new_game("standard")


func _start_child() -> void:
	start_new_game("child")


func start_new_game(mode: String = "standard") -> void:
	GameState.reset_for_new_game()
	SpiritualStateManager.reset_for_new_game()
	QuestManager.reset_for_new_game()
	GameState.difficulty = mode
	_clear_menu()
	_hud.visible = true
	_in_game = true
	if _touch:
		_touch.set_gameplay(true)
	EventBus.game_started.emit()
	if mode == "child":
		EventBus.toast(LocaleManager.t("toast.child_mode", "Children's Journey — a gentle road. Take your time."))
	ChapterManager.start_chapter("city_of_destruction")
	_show_controls_hint()


func continue_game() -> void:
	if not SaveManager.load_game("slot_1"):
		return
	_clear_menu()
	_hud.visible = true
	_in_game = true
	if _touch:
		_touch.set_gameplay(true)
	var chapter := GameState.current_chapter_id
	if chapter == "":
		chapter = "city_of_destruction"
	ChapterManager.start_chapter(chapter)
	_show_controls_hint()


## First-run only: a dismissible control / onboarding overlay.
func _show_controls_hint() -> void:
	if Settings.seen_controls:
		return
	Settings.mark_controls_seen()
	var cl := CanvasLayer.new()
	cl.layer = 30
	add_child(cl)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	sb.border_color = Color(0.85, 0.74, 0.4, 0.6)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	_add_title(vb, "旅程指引 · Journey", 28, Color(0.95, 0.9, 0.6))
	var lines := [
		"这不是操作挑战，而是一段学习经文与操练价值观的旅程。",
		"遇到人物和物件时，停下来读、选择、思想：这一步在塑造什么品格？",
		"每章出口前会有经文之门；答题不是考试，而是把经文用到处境里。",
		"祷告、小教堂和心境面板会帮助你回想已经学过的经文。",
		"需要操作时：移动、互动、继续对话即可；战斗也可以用经文和祷告回应。",
	]
	if DisplayServer.is_touchscreen_available():
		lines = [
			"移动端重点是读、想、选择，不需要复杂操作。",
			"点「互动/继续」阅读人物、物件和经文提示；有选项时直接点大号选项。",
			"点「心境」可以回看已记住的经文与内心状态。",
			"小教堂、祷告和经文之门会给出短默想，帮助你把经文用到当下处境。",
			"每章出口有发光传送门；答对该章经文方可通行。",
		]
	for s in lines:
		var l := Label.new()
		l.text = s
		l.add_theme_font_size_override("font_size", 18)
		vb.add_child(l)
	_add_button(vb, "知道了 Got it", func(): cl.queue_free())


# ---------------------------------------------------------------------------
# End of demo
# ---------------------------------------------------------------------------
func _on_demo_completed() -> void:
	_in_game = false
	await get_tree().create_timer(2.5).timeout
	_hud.visible = false
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.06, 0.05, 0.03, 1.0))
	var vb := _make_centered_box(panel)
	_add_title(vb, LocaleManager.t("end.title", "You have crossed the river and entered in."), 32, Color(0.98, 0.94, 0.72))
	_add_title(vb, LocaleManager.t("end.l1", "From first awakening to final welcome,"), 20, Color(0.8, 0.82, 0.9))
	_add_title(vb, LocaleManager.t("end.l2", "grace has carried the pilgrim home."), 20, Color(0.8, 0.82, 0.9))
	_add_title(vb, LocaleManager.t("end.l3", "The burden is gone. The City is before you."), 18, Color(0.65, 0.65, 0.75))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	_add_button(vb, LocaleManager.t("menu.return_title", "Return to Title"), _show_title)
	_add_button(vb, LocaleManager.t("menu.quit", "Quit"), func(): get_tree().quit())


# ---------------------------------------------------------------------------
# Collapse & repentance
# ---------------------------------------------------------------------------
func _on_collapse() -> void:
	if not _in_game:
		return
	EventBus.player_control_locked.emit(true)
	EventBus.repentance_started.emit()
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.02, 0.0, 0.04, 0.86))
	var vb := _make_centered_box(panel)
	_add_title(vb, LocaleManager.t("collapse.title", "You have sunk down under the weight."), 28, Color(0.85, 0.75, 0.85))
	_add_title(vb, LocaleManager.t("collapse.l1", "Trying harder cannot raise a heart that needs mercy."), 20, Color(0.78, 0.72, 0.82))
	_add_title(vb, LocaleManager.t("collapse.l2", "But the way back was never closed. Tell the truth, and receive help:"), 18, Color(0.75, 0.8, 0.9))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)
	# Each confession is an honest naming, not a payment. Grace does the lifting.
	var confessions := [
		{"k": "repent.afraid", "en": "\"I was afraid, and I obeyed fear as if it were truth.\"", "eff": {"fear": -25, "faith": 10}},
		{"k": "repent.pride", "en": "\"I trusted myself, and called refusal to receive help strength.\"", "eff": {"pride": -22, "humility": 16}},
		{"k": "repent.despair", "en": "\"I believed despair when it said mercy was finished with me.\"", "eff": {"despair": -40, "hope": 20}},
		{"k": "repent.easy", "en": "\"I wanted the easy way more than the true one.\"", "eff": {"deception": -18, "perseverance": 12}},
	]
	for c in confessions:
		var effects: Dictionary = c["eff"]
		_add_button(vb, LocaleManager.t(String(c["k"]), String(c["en"])), func(): _confess(effects))


func _confess(effects: Dictionary) -> void:
	SpiritualStateManager.apply_effects(effects)
	# Confession is honesty; grace does the lifting. It is never earned.
	SpiritualStateManager.apply_effects({"despair": -25, "hope": 18, "humility": 10, "shame": -18})
	SpiritualStateManager.clear_collapse()
	_clear_menu()
	EventBus.player_control_locked.emit(false)
	EventBus.repentance_completed.emit()
	EventBus.toast(LocaleManager.t("toast.lifted", "You are lifted by grace, not by self-rescue. Walk on."))


# ---------------------------------------------------------------------------
# Options / settings screen (volume sliders + fullscreen)
# ---------------------------------------------------------------------------
func _options_from_title() -> void:
	_clear_menu()
	_build_options(_menu_layer, _show_title)


func _pause_to_options() -> void:
	for c in _pause_layer.get_children():
		c.queue_free()
	_build_options(_pause_layer, _open_pause)


func _build_options(layer: CanvasLayer, on_back: Callable) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	layer.add_child(panel)

	var vb := _make_centered_box(panel)
	_add_title(vb, "设置 Options", 36, Color(0.95, 0.9, 0.7))
	_add_title(vb, "音量 Volume", 20, Color(0.75, 0.8, 0.92))
	_add_volume_slider(vb, "主音量 Master", "master")
	_add_volume_slider(vb, "音乐 Music", "music")
	_add_volume_slider(vb, "环境音 Ambience", "ambient")
	_add_volume_slider(vb, "音效 Sound FX", "sfx")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer)

	_add_title(vb, "控制 Controls", 20, Color(0.75, 0.8, 0.92))
	_add_range_slider(vb, "鼠标视角 Mouse Look", "mouse_sensitivity", 0.05, 0.6, 0.01, 0.25, true)
	_add_range_slider(vb, "手柄视角 Controller Look", "controller_look_sensitivity", 60.0, 360.0, 10.0, 150.0, false)
	var inv := CheckButton.new()
	inv.text = "反转纵向视角 Invert Look Y"
	inv.add_theme_font_size_override("font_size", 18)
	inv.button_pressed = bool(_get_input_setting("invert_look_y", false))
	inv.toggled.connect(func(on): _set_input_setting("invert_look_y", on))
	vb.add_child(inv)
	_add_range_slider(vb, "触屏按钮大小 Touch Button Size", "touch_button_scale", 0.6, 1.4, 0.05, 1.0, true)
	_add_range_slider(vb, "界面缩放 UI Scale", "ui_scale", 0.8, 1.6, 0.05, _ui_scale_default(), true)

	var spacerA := Control.new()
	spacerA.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacerA)
	_add_title(vb, "Accessibility · 无障碍", 20, Color(0.75, 0.8, 0.92))
	var rm := CheckButton.new()
	rm.text = "减少震动 Reduce Motion (shake / hit-stop)"
	rm.add_theme_font_size_override("font_size", 18)
	rm.button_pressed = Settings.reduce_motion
	rm.toggled.connect(func(on): Settings.set_reduce_motion(on))
	vb.add_child(rm)
	var cbf := CheckButton.new()
	cbf.text = "色盲友好配色 Colour-blind safe"
	cbf.add_theme_font_size_override("font_size", 18)
	cbf.button_pressed = Settings.colorblind
	cbf.toggled.connect(func(on): Settings.set_colorblind(on))
	vb.add_child(cbf)
	var teach := CheckButton.new()
	teach.text = "章节教学与经文讨论 Learning reflections"
	teach.add_theme_font_size_override("font_size", 18)
	teach.button_pressed = Settings.teaching_mode
	teach.toggled.connect(func(on): Settings.set_teaching_mode(on))
	vb.add_child(teach)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer2)

	var cb := CheckButton.new()
	cb.text = "全屏 Fullscreen"
	cb.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(on):
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_fullscreen(on)
	)
	vb.add_child(cb)

	_add_button(vb, "返回 Back", func():
		AudioManager.save_settings()
		on_back.call()
	)


func _add_volume_slider(vb: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(label_text)
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.get_volume(key)
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var val := Label.new()
	val.custom_minimum_size = Vector2(52, 0)
	val.text = "%d%%" % int(round(slider.value * 100.0))
	val.add_theme_font_size_override("font_size", 16)
	row.add_child(val)
	slider.value_changed.connect(func(v):
		AudioManager.set_volume(key, v)
		val.text = "%d%%" % int(round(v * 100.0))
	)
	slider.drag_ended.connect(func(_changed):
		if key == "sfx" or key == "master":
			AudioManager.play_sfx("ui_select")
	)
	vb.add_child(row)


func _get_input_setting(key: String, default):
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	return cf.get_value("input", key, default)


func _set_input_setting(key: String, value) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("input", key, value)
	cf.save("user://settings.cfg")
	if EventBus.has_signal("settings_changed"):
		EventBus.settings_changed.emit()


func _ui_scale_default() -> float:
	# Phones/tablets start a bit larger so menu text & HUD numbers are readable.
	return 1.15 if DisplayServer.is_touchscreen_available() else 1.0


func _apply_ui_scale() -> void:
	# Global GUI scale for menus + HUD (Window.content_scale_factor). The touch
	# keypad re-derives its size from the viewport each frame, so it stays put;
	# fine-tune the keypad separately via "Touch Button Size".
	var w := get_window()
	if w == null:
		return
	w.content_scale_factor = clampf(float(_get_input_setting("ui_scale", _ui_scale_default())), 0.7, 2.0)


func _add_range_slider(vb: VBoxContainer, label_text: String, key: String,
		mn: float, mx: float, step: float, default: float, as_percent: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(label_text)
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = float(_get_input_setting(key, default))
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var val := Label.new()
	val.custom_minimum_size = Vector2(52, 0)
	val.add_theme_font_size_override("font_size", 16)
	var fmt := func(v: float) -> String:
		if as_percent:
			return "%d%%" % int(round((v - mn) / (mx - mn) * 100.0))
		return "%d" % int(round(v))
	val.text = fmt.call(slider.value)
	row.add_child(val)
	slider.value_changed.connect(func(v):
		_set_input_setting(key, v)
		val.text = fmt.call(v)
	)
	vb.add_child(row)


func _save_fullscreen(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("video", "fullscreen", on)
	cf.save("user://settings.cfg")


func _load_video_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return
	if bool(cf.get_value("video", "fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------------------
# Pause menu (Esc)
# ---------------------------------------------------------------------------
func _open_pause() -> void:
	if DialogueManager.is_active():
		return
	_pause_visible = true
	EventBus.player_control_locked.emit(true)
	for c in _pause_layer.get_children():
		c.queue_free()
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	_pause_layer.add_child(panel)
	var vb := _make_centered_box(panel)
	_add_title(vb, "暂停 Paused", 36, Color(0.95, 0.9, 0.7))
	_add_button(vb, "继续 Resume", _resume_from_pause)
	_add_button(vb, "路线图 Route Map", _pause_to_route)
	_add_button(vb, "保存 Save", _pause_save)
	_add_button(vb, "读取 Load", _load_from_pause)
	_add_button(vb, "设置 Options", _pause_to_options)
	_add_button(vb, "返回标题 Return to Title", _pause_to_title)
	_add_button(vb, LocaleManager.t("menu.quit", "Quit"), func(): get_tree().quit())


func _pause_to_route() -> void:
	_resume_from_pause()
	_toggle_route_map()


func _pause_to_title() -> void:
	_resume_from_pause()
	_show_title()


func _pause_save() -> void:
	SaveManager.save_game("slot_1")


func _resume_from_pause() -> void:
	_pause_visible = false
	for c in _pause_layer.get_children():
		c.queue_free()
	if _in_game and not DialogueManager.is_active():
		EventBus.player_control_locked.emit(false)


func _load_from_pause() -> void:
	_resume_from_pause()
	if SaveManager.load_game("slot_1"):
		var chapter := GameState.current_chapter_id
		if chapter == "":
			chapter = "city_of_destruction"
		ChapterManager.start_chapter(chapter)


# ---------------------------------------------------------------------------
# Route map (Tab)
# ---------------------------------------------------------------------------
func _toggle_route_map() -> void:
	_route_visible = not _route_visible
	for c in _route_layer.get_children():
		c.queue_free()
	if not _route_visible:
		return
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	_route_layer.add_child(panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	center.add_child(vb)

	var title := Label.new()
	title.text = "天路历程 THE PILGRIM'S ROAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	vb.add_child(title)

	var current: String = ChapterManager.current_chapter_id
	for raw_chapter_id in ChapterManager.route:
		var chapter_id: String = String(raw_chapter_id)
		var data: Dictionary = ChapterManager.load_chapter_data(chapter_id)
		var label := Label.new()
		var done: bool = GameState.has_flag(chapter_id + "_completed")
		var is_current: bool = chapter_id == current
		var mark: String = "[完成]" if done else ("[当前]" if is_current else "[    ]")
		var color: Color = Color(0.6, 0.85, 0.6) if done else (Color(1, 0.95, 0.6) if is_current else Color(0.55, 0.55, 0.62))
		label.text = "%s  %s" % [mark, String(data.get("title", chapter_id))]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", color)
		vb.add_child(label)

	var hint := Label.new()
	hint.text = "点「地图」或「暂停」关闭" if DisplayServer.is_touchscreen_available() else "Tab / Esc 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(hint)


# ---------------------------------------------------------------------------
# Debug shortcuts (development aid)
# ---------------------------------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F2:
			SpiritualStateManager.modify_state("despair", 20)
			EventBus.toast("[debug] despair +20")
		KEY_F3:
			SpiritualStateManager.modify_state("hope", 20)
			EventBus.toast("[debug] hope +20")
		KEY_F4:
			if SpiritualStateManager.has_burden:
				SpiritualStateManager.remove_burden()
			else:
				SpiritualStateManager.has_burden = true
				EventBus.burden_removed.emit()
			EventBus.toast("[debug] toggled burden")
		KEY_F5:
			SaveManager.save_game("slot_1")
		KEY_F6:
			SaveManager.load_game("slot_1")
		KEY_F7:
			if _in_game:
				EventBus.toast("[debug] skip chapter")
				ChapterManager.go_to_next_chapter()
		KEY_F8:
			SpiritualStateManager.apply_cross_grace()
			EventBus.toast("[debug] cross grace")
		KEY_F9:
			var report: String = DATA_VALIDATOR.report()
			print(report)
			EventBus.toast(report.split("\n")[0])
		KEY_TAB:
			if _in_game:
				_toggle_route_map()
		KEY_ESCAPE:
			if _route_visible:
				_toggle_route_map()
			elif _pause_visible:
				_resume_from_pause()
			elif _in_game:
				_open_pause()
