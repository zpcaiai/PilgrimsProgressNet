extends Node3D
## Main
## Root of the game. Owns the world container, HUD, title/end menus, the
## collapse/repentance flow, and developer debug shortcuts.

const HUD_SCRIPT := preload("res://scripts/ui/HUD.gd")
const DATA_VALIDATOR := preload("res://scripts/core/DataValidator.gd")
const NET_UI := preload("res://scenes/ui/NetUI.tscn")

var _world_root: Node3D
var _hud: CanvasLayer
var _menu_layer: CanvasLayer
var _menu_root: Control
var _route_layer: CanvasLayer
var _route_visible: bool = false
var _pause_layer: CanvasLayer
var _pause_visible: bool = false
var _in_game: bool = false


func _ready() -> void:
	_ensure_input_actions()

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
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	vb.add_child(lbl)


func _add_button(vb: VBoxContainer, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
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
	_hud.visible = false
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.04, 0.04, 0.08, 1.0))
	var vb := _make_centered_box(panel)
	_add_title(vb, "PILGRIM'S ROAD", 48, Color(0.95, 0.88, 0.6))
	_add_title(vb, "Burden Fallen", 26, Color(0.7, 0.78, 0.9))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	_add_title(vb, "Choose your journey", 18, Color(0.7, 0.72, 0.82))
	_add_button(vb, "Devout Journey  (敬虔版 · full)", _start_standard)
	_add_button(vb, "Children's Journey  (gentle, easy to finish)", _start_child)
	if SaveManager.has_save("slot_1"):
		var summary := SaveManager.get_save_summary("slot_1")
		_add_button(vb, "Continue (%s)" % String(summary.get("chapter", "")), continue_game)
	_add_button(vb, "Quit", func(): get_tree().quit())
	var hint := Label.new()
	hint.text = "WASD move · Space jump · E interact · 1-4 choose · C heart · Tab map · Esc pause"
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
	EventBus.game_started.emit()
	if mode == "child":
		EventBus.toast("Children's Journey — a gentle road. Take your time.")
	ChapterManager.start_chapter("city_of_destruction")


func continue_game() -> void:
	if not SaveManager.load_game("slot_1"):
		return
	_clear_menu()
	_hud.visible = true
	_in_game = true
	var chapter := GameState.current_chapter_id
	if chapter == "":
		chapter = "city_of_destruction"
	ChapterManager.start_chapter(chapter)


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
	_add_title(vb, "You have crossed the river and entered in.", 32, Color(0.98, 0.94, 0.72))
	_add_title(vb, "From first awakening to final welcome,", 20, Color(0.8, 0.82, 0.9))
	_add_title(vb, "grace has carried the pilgrim home.", 20, Color(0.8, 0.82, 0.9))
	_add_title(vb, "The burden is gone. The City is before you.", 18, Color(0.65, 0.65, 0.75))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	_add_button(vb, "Return to Title", _show_title)
	_add_button(vb, "Quit", func(): get_tree().quit())


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
	_add_title(vb, "You have sunk down under the weight.", 28, Color(0.85, 0.75, 0.85))
	_add_title(vb, "Trying harder cannot raise a heart that needs mercy.", 20, Color(0.78, 0.72, 0.82))
	_add_title(vb, "But the way back was never closed. Tell the truth, and receive help:", 18, Color(0.75, 0.8, 0.9))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)
	# Each confession is an honest naming, not a payment. Grace does the lifting.
	var confessions := {
		"\"I was afraid, and I obeyed fear as if it were truth.\"": {"fear": -25, "faith": 10},
		"\"I trusted myself, and called refusal to receive help strength.\"": {"pride": -22, "humility": 16},
		"\"I believed despair when it said mercy was finished with me.\"": {"despair": -40, "hope": 20},
		"\"I wanted the easy way more than the true one.\"": {"deception": -18, "perseverance": 12},
	}
	for line in confessions.keys():
		var effects: Dictionary = confessions[line]
		_add_button(vb, line, func(): _confess(effects))


func _confess(effects: Dictionary) -> void:
	SpiritualStateManager.apply_effects(effects)
	# Confession is honesty; grace does the lifting. It is never earned.
	SpiritualStateManager.apply_effects({"despair": -25, "hope": 18, "humility": 10, "shame": -18})
	SpiritualStateManager.clear_collapse()
	_clear_menu()
	EventBus.player_control_locked.emit(false)
	EventBus.repentance_completed.emit()
	EventBus.toast("You are lifted by grace, not by self-rescue. Walk on.")


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
	_add_title(vb, "Paused", 36, Color(0.95, 0.9, 0.7))
	_add_button(vb, "Resume", _resume_from_pause)
	_add_button(vb, "Route Map", _pause_to_route)
	_add_button(vb, "Save", _pause_save)
	_add_button(vb, "Load", _load_from_pause)
	_add_button(vb, "Return to Title", _pause_to_title)
	_add_button(vb, "Quit", func(): get_tree().quit())


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
	title.text = "THE PILGRIM'S ROAD"
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
		var mark: String = "[done]" if done else ("[ now ]" if is_current else "[    ]")
		var color: Color = Color(0.6, 0.85, 0.6) if done else (Color(1, 0.95, 0.6) if is_current else Color(0.55, 0.55, 0.62))
		label.text = "%s  %s" % [mark, String(data.get("title", chapter_id))]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", color)
		vb.add_child(label)

	var hint := Label.new()
	hint.text = "Tab / Esc to close"
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
