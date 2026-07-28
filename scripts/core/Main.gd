extends Node3D
## Main
## Root of the game. Owns the world container, HUD, title/end menus, the
## collapse/repentance flow, and developer debug shortcuts.

const HUD_SCRIPT := preload("res://scripts/ui/HUD.gd")
const DATA_VALIDATOR := preload("res://scripts/core/DataValidator.gd")
const NET_UI := preload("res://scenes/ui/NetUI.tscn")
const TOUCH_CONTROLS := preload("res://scripts/ui/TouchControls.gd")
const ResponsiveLayout := preload("res://scripts/ui/ResponsiveLayout.gd")

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
	# One line in the log saying which renderer and which character pipeline
	# this build actually resolved to — so "why does it look different on my
	# machine" is answerable without guessing.
	FigureFactory.log_once()

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
		"pray": [KEY_Q, KEY_P],
		"repent": [KEY_R],
		"open_journal": [KEY_J, KEY_TAB],
		"recenter_player": [KEY_H],
		"dash": [KEY_SHIFT],
		"combat_attack": [KEY_J],
		"combat_dodge": [KEY_K],
		"combat_guard": [KEY_L],
		"combat_promise": [KEY_U],
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
	ResponsiveLayout.fit_fullscreen(ctrl, self)
	_menu_root = ctrl
	return ctrl


func _make_centered_box(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := ResponsiveLayout.margin(self)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, int(safe))
	parent.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var safe_size := ResponsiveLayout.safe_size(self)
	center.custom_minimum_size = Vector2(maxf(240.0, safe_size.x), maxf(260.0, safe_size.y))
	scroll.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.custom_minimum_size = Vector2(minf(560.0, maxf(240.0, safe_size.x)), 0)
	center.add_child(vb)
	return vb


func _add_title(vb: VBoxContainer, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(text)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mobile_size := int(round(float(size) * 1.25)) if ResponsiveLayout.is_mobile(self) else size
	lbl.add_theme_font_size_override("font_size", mobile_size)
	lbl.add_theme_color_override("font_color", color)
	vb.add_child(lbl)


func _add_button(vb: VBoxContainer, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = LocaleManager.zh_or_mixed(text)
	var mobile := ResponsiveLayout.is_mobile(self)
	btn.custom_minimum_size = Vector2(0, 62 if mobile else 46)
	btn.add_theme_font_size_override("font_size", 28 if mobile else 20)
	ResponsiveLayout.set_button_wrap(btn)
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
	# ROUTE VARIANTS.
	#
	# MVP_ROUTE (5 chapters) and VERTICAL_SLICE_ROUTE (9) have existed in
	# ChapterManager since the game was built in slices, and were referenced by
	# nothing — dead code holding two genuinely useful products: a short demo
	# and a classroom-length slice. They are choosable here now.
	_add_button(vb, LocaleManager.t("menu.route", "旅程长度 Journey length"), _show_route_picker)
	_add_button(vb, LocaleManager.t("menu.options", "Options"), _options_from_title)
	_add_button(vb, LocaleManager.t("menu.achievements", "成就 Achievements"), _achievements_from_title)
	_add_button(vb, LocaleManager.t("menu.quit", "Quit"), func(): get_tree().quit())
	_add_button(vb, LocaleManager.switch_label(), func(): LocaleManager.toggle(); _show_title())
	var hint := Label.new()
	hint.text = LocaleManager.t("menu.hint_touch", "左侧摇杆移动 · 点「互动/继续」交互与对话 · 点「祷告」「悔改」回应试探 · 点「心境」回看经文 · 点「地图」看路线") if DisplayServer.is_touchscreen_available() else LocaleManager.t("menu.hint", "WASD move · E interact · Q/P pray · R repent · 1-4 choose · C heart · Tab map · Esc pause")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if ResponsiveLayout.is_mobile(self) else TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 22 if ResponsiveLayout.is_mobile(self) else 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(hint)


func _start_standard() -> void:
	start_new_game("standard")


func _start_child() -> void:
	start_new_game("child")


func start_new_game(mode: String = "standard") -> void:
	EventBus.clear_player_locks()
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
	EventBus.clear_player_locks()
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
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	EventBus.lock_player("controls_hint")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.05, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	sb.border_color = Color(0.85, 0.74, 0.4, 0.6)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var frame := VBoxContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_constant_override("separation", 10)
	panel.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)
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
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if ResponsiveLayout.is_mobile(self) else TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 24 if ResponsiveLayout.is_mobile(self) else 18)
		vb.add_child(l)
	var confirm := _add_button(frame, "确认并开始 / Confirm & Start", func():
		EventBus.unlock_player("controls_hint")
		cl.queue_free()
	)
	ResponsiveLayout.set_modal_action(confirm, 48.0)
	confirm.reparent(root)
	var apply_layout := func():
		var mobile := ResponsiveLayout.is_mobile(cl)
		ResponsiveLayout.fit_fullscreen(root, cl)
		var size := ResponsiveLayout.fit_center_panel(panel, cl, Vector2(720, 560), Vector2(280, 320))
		if mobile:
			scroll.custom_minimum_size = Vector2(maxf(220.0, size.x - 48.0), maxf(160.0, size.y - 126.0))
			vb.custom_minimum_size = Vector2(maxf(200.0, size.x - 72.0), 0)
		else:
			scroll.custom_minimum_size = Vector2(maxf(240.0, size.x - 48.0), maxf(180.0, size.y - 110.0))
			vb.custom_minimum_size = Vector2(maxf(220.0, size.x - 72.0), 0)
		ResponsiveLayout.normalize_tree(panel, mobile)
		if mobile:
			ResponsiveLayout.place_viewport_action(confirm, cl, 62.0, 18.0)
		else:
			ResponsiveLayout.place_panel_action(confirm, panel, 48.0, 24.0)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout.call()


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
	# Close the loop instead of dead-ending on "Return to Title / Quit".
	#
	#  * The credits existed only as a `show_credits` flag that four data files
	#    set and NOTHING ever read.
	#  * There was no New Game+ at all: the only way back in discarded every
	#    Scripture card the player had memorised, so a second journey started
	#    poorer than the first.
	#  * Achievements were reachable from the title screen and the pause menu —
	#    but not from the one screen where the player has just finished.
	_add_button(vb, LocaleManager.t("end.credits", "演职表 Credits"), _credits_from_end)
	_add_button(vb, LocaleManager.t("menu.achievements", "成就 Achievements"), _achievements_from_end)
	_add_button(vb, LocaleManager.t("end.newgame_plus", "再走一次（带着所学的）"),
		start_new_game_plus)
	_add_button(vb, LocaleManager.t("menu.return_title", "Return to Title"), _show_title)
	_add_button(vb, LocaleManager.t("menu.quit", "Quit"), func(): get_tree().quit())


func _achievements_from_end() -> void:
	_clear_menu()
	_show_achievements(_menu_layer, _on_demo_completed_screen)


func _credits_from_end() -> void:
	_show_credits()


## The ending panel without the 2.5 s wait (used when coming BACK from credits
## or the achievement list).
func _on_demo_completed_screen() -> void:
	_in_game = false
	_hud.visible = false
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.06, 0.05, 0.03, 1.0))
	var vb := _make_centered_box(panel)
	_add_title(vb, LocaleManager.t("end.title", "You have crossed the river and entered in."), 32, Color(0.98, 0.94, 0.72))
	_add_title(vb, LocaleManager.t("end.l3", "The burden is gone. The City is before you."), 18, Color(0.65, 0.65, 0.75))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	vb.add_child(sp)
	_add_button(vb, LocaleManager.t("end.credits", "演职表 Credits"), _credits_from_end)
	_add_button(vb, LocaleManager.t("menu.achievements", "成就 Achievements"), _achievements_from_end)
	_add_button(vb, LocaleManager.t("end.newgame_plus", "再走一次（带着所学的）"), start_new_game_plus)
	_add_button(vb, LocaleManager.t("menu.return_title", "Return to Title"), _show_title)


## New Game+: a fresh journey that keeps the Scripture cards you memorised and
## your achievements (both live outside the save slot), and marks the run so a
## later pass can acknowledge it. Everything describing *this* journey — flags,
## spiritual state, quests — is reset exactly as in a normal new game.
func start_new_game_plus() -> void:
	var mode := "child" if GameState.is_child_mode() else "standard"
	start_new_game(mode)
	GameState.set_flag("new_game_plus", true)
	EventBus.toast(LocaleManager.t("toast.ngplus",
		"你再次上路——所记住的话语仍在你心里。"))


## Roll the credits. This finally reads the `show_credits` flag that
## data/spiritual_events/journey_completed.json, data/dialogues/final_gate_entry
## and data/chapters/celestial_city.json have all been setting into the void.
func _show_credits() -> void:
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.03, 0.03, 0.05, 1.0))
	var scroller := ScrollContainer.new()
	scroller.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroller)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroller.add_child(vb)

	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 48)
	vb.add_child(head)
	_add_title(vb, LocaleManager.t("credits.title", "天路 · 重担脱落"), 30, Color(0.98, 0.94, 0.72))
	_add_title(vb, LocaleManager.t("credits.source",
		"改编自约翰·班扬《天路历程》（1678，公有领域）"), 16, Color(0.72, 0.74, 0.82))

	for line in _credit_lines():
		var is_head := line.begins_with("— ")
		_add_title(vb, line, 22 if is_head else 17,
			Color(0.92, 0.89, 0.78) if is_head else Color(0.72, 0.74, 0.82))

	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 32)
	vb.add_child(tail)
	_add_button(vb, LocaleManager.t("menu.back", "返回 Back"), _on_demo_completed_screen)
	GameState.set_flag("credits_seen", true)


func _credit_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("— 十六章 The Sixteen —")
	for cid in ChapterManager.route:
		var d := ChapterManager.load_chapter_data(String(cid))
		lines.append(String(d.get("title_zh", d.get("title", cid))))
	lines.append("— 记念 Remembered —")
	var cards := 0
	if ScriptureMemory.has_method("known_cards"):
		cards = (ScriptureMemory.known_cards() as Array).size()
	lines.append(LocaleManager.t("credits.cards", "记住的经文：%d") % cards)
	var journey := ""
	if JourneyJournal.has_method("summary_text"):
		journey = String(JourneyJournal.summary_text(6))
	if journey.strip_edges() != "":
		lines.append("— 你走过的路 Your Road —")
		lines.append(journey)
	lines.append("— —")
	lines.append(LocaleManager.t("credits.thanks",
		"愿这条路上的每一步，都记得是谁托住了你。"))
	return lines


# ---------------------------------------------------------------------------
# Collapse & repentance
# ---------------------------------------------------------------------------
func _on_collapse() -> void:
	if not _in_game:
		return
	EventBus.lock_player("repentance")
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
	EventBus.unlock_player("repentance")
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
	ResponsiveLayout.set_button_wrap(inv)
	inv.add_theme_font_size_override("font_size", 18)
	inv.button_pressed = bool(_get_input_setting("invert_look_y", false))
	inv.toggled.connect(func(on): _set_input_setting("invert_look_y", on))
	vb.add_child(inv)
	_add_range_slider(vb, "触屏按钮大小 Touch Button Size", "touch_button_scale", 0.6, 1.4, 0.05, 1.0, true)
	var mobile_ui := DisplayServer.is_touchscreen_available()
	_add_range_slider(vb, "界面缩放 UI Scale", "ui_scale",
		1.6 if mobile_ui else 0.8, 2.6 if mobile_ui else 1.6, 0.05, _ui_scale_default(), true)

	var spacerA := Control.new()
	spacerA.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacerA)
	_add_title(vb, "Accessibility · 无障碍", 20, Color(0.75, 0.8, 0.92))
	var rm := CheckButton.new()
	rm.text = "减少震动 Reduce Motion (shake / hit-stop)"
	ResponsiveLayout.set_button_wrap(rm)
	rm.add_theme_font_size_override("font_size", 18)
	rm.button_pressed = Settings.reduce_motion
	rm.toggled.connect(func(on): Settings.set_reduce_motion(on))
	vb.add_child(rm)
	var cbf := CheckButton.new()
	cbf.text = "色盲友好配色 Colour-blind safe"
	ResponsiveLayout.set_button_wrap(cbf)
	cbf.add_theme_font_size_override("font_size", 18)
	cbf.button_pressed = Settings.colorblind
	cbf.toggled.connect(func(on): Settings.set_colorblind(on))
	vb.add_child(cbf)
	var teach := CheckButton.new()
	teach.text = "章节教学与经文讨论 Learning reflections"
	ResponsiveLayout.set_button_wrap(teach)
	teach.add_theme_font_size_override("font_size", 18)
	teach.button_pressed = Settings.teaching_mode
	teach.toggled.connect(func(on): Settings.set_teaching_mode(on))
	vb.add_child(teach)
	var tts := CheckButton.new()
	tts.text = "朗读旁白与对话 Read aloud (TTS)"
	ResponsiveLayout.set_button_wrap(tts)
	tts.add_theme_font_size_override("font_size", 18)
	tts.button_pressed = Settings.tts
	tts.toggled.connect(func(on): Settings.set_tts(on))
	vb.add_child(tts)
	# Text-size tiers — drive the global UI scale (which scales HUD + menu fonts).
	var fs_row := HFlowContainer.new()
	fs_row.add_theme_constant_override("separation", 8)
	var fs_lbl := Label.new()
	fs_lbl.text = LocaleManager.zh_or_mixed("字号 Text Size")
	fs_lbl.custom_minimum_size = Vector2(110, 0)
	fs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fs_lbl.add_theme_font_size_override("font_size", 18)
	fs_row.add_child(fs_lbl)
	var text_tiers := [["小", 1.6], ["标准", 2.0], ["大", 2.3], ["特大", 2.6]] if mobile_ui else [["小", 0.9], ["标准", 1.05], ["大", 1.2], ["特大", 1.4]]
	for tier in text_tiers:
		var b := Button.new()
		b.text = String(tier[0])
		b.add_theme_font_size_override("font_size", 18)
		ResponsiveLayout.set_button_wrap(b)
		var sc := float(tier[1])
		b.pressed.connect(func():
			_set_input_setting("ui_scale", sc)
			_apply_ui_scale()
		)
		fs_row.add_child(b)
	vb.add_child(fs_row)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer2)

	var cb := CheckButton.new()
	cb.text = "全屏 Fullscreen"
	ResponsiveLayout.set_button_wrap(cb)
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
	var row := HFlowContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(label_text)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(92 if ResponsiveLayout.is_mobile(self) else 130, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.get_volume(key)
	var available := maxf(120.0, ResponsiveLayout.viewport_size(self).x - ResponsiveLayout.margin(self) * 2.0 - 180.0)
	slider.custom_minimum_size = Vector2(minf(260.0, available), 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Web/mobile renders the 1280-wide logical canvas into a much narrower CSS
	# viewport. This default yields readable physical text and 44px touch targets.
	return 2.2 if DisplayServer.is_touchscreen_available() else 1.0


func _apply_ui_scale() -> void:
	# Global GUI scale for menus + HUD (Window.content_scale_factor). The touch
	# keypad re-derives its size from the viewport each frame, so it stays put;
	# fine-tune the keypad separately via "Touch Button Size".
	var w := get_window()
	if w == null:
		return
	var value := float(_get_input_setting("ui_scale", _ui_scale_default()))
	# Migrate legacy mobile saves from the old 0.8-1.6 range into the new readable
	# range. Desktop values and deliberately larger mobile values are unchanged.
	if DisplayServer.is_touchscreen_available() and value < 1.6:
		value = 2.0
	w.content_scale_factor = clampf(value, 1.6, 2.6) if DisplayServer.is_touchscreen_available() else clampf(value, 0.7, 2.0)


func _add_range_slider(vb: VBoxContainer, label_text: String, key: String,
		mn: float, mx: float, step: float, default: float, as_percent: bool) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = LocaleManager.zh_or_mixed(label_text)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(92 if ResponsiveLayout.is_mobile(self) else 130, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = float(_get_input_setting(key, default))
	var available := maxf(120.0, ResponsiveLayout.viewport_size(self).x - ResponsiveLayout.margin(self) * 2.0 - 180.0)
	slider.custom_minimum_size = Vector2(minf(260.0, available), 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	EventBus.lock_player("pause_menu")
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
	_add_button(vb, "成就 Achievements", _pause_to_achievements)
	_add_button(vb, "保存 Save", func(): _open_save_slots("save"))
	_add_button(vb, "读取 Load", func(): _open_save_slots("load"))
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
		EventBus.unlock_player("pause_menu")


func _load_from_pause() -> void:
	_resume_from_pause()
	if SaveManager.load_game("slot_1"):
		var chapter := GameState.current_chapter_id
		if chapter == "":
			chapter = "city_of_destruction"
		ChapterManager.start_chapter(chapter)


# ---------------------------------------------------------------------------
# Achievements panel
# ---------------------------------------------------------------------------
func _clear_layer(layer: CanvasLayer) -> void:
	for c in layer.get_children():
		c.queue_free()


func _close_overlay(layer: CanvasLayer, on_back: Callable) -> void:
	_clear_layer(layer)
	on_back.call()


func _pause_to_achievements() -> void:
	_clear_layer(_pause_layer)
	_show_achievements(_pause_layer, _open_pause)


func _achievements_from_title() -> void:
	_clear_menu()
	_show_achievements(_menu_layer, _show_title)


func _show_achievements(layer: CanvasLayer, on_back: Callable) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 34)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "成就 · Achievements   (%d / %d)" % [Achievements.unlocked_count(), Achievements.total()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for a in Achievements.all_defs():
		if a is Dictionary:
			_add_achievement_row(list, a)
	_add_button(vb, "返回 Back", func(): _close_overlay(layer, on_back))


func _add_achievement_row(list: VBoxContainer, a: Dictionary) -> void:
	var got: bool = Achievements.is_unlocked(String(a.get("id", "")))
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.17, 0.92) if got else Color(0.06, 0.06, 0.09, 0.7)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	list.add_child(row)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)
	var icon := Label.new()
	icon.text = String(a.get("icon", "•")) if got else "🔒"
	icon.add_theme_font_size_override("font_size", 26)
	icon.custom_minimum_size = Vector2(42, 0)
	hb.add_child(icon)
	var tvb := VBoxContainer.new()
	tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tvb)
	var nm := Label.new()
	nm.text = Achievements.label(a, "title")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7) if got else Color(0.6, 0.6, 0.66))
	tvb.add_child(nm)
	var ds := Label.new()
	ds.text = Achievements.label(a, "desc")
	ds.add_theme_font_size_override("font_size", 15)
	ds.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88) if got else Color(0.5, 0.5, 0.56))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tvb.add_child(ds)


# ---------------------------------------------------------------------------
# Save / load slots + cloud sync
# ---------------------------------------------------------------------------
func _open_save_slots(mode: String) -> void:
	_clear_layer(_pause_layer)
	_build_save_slots(_pause_layer, _open_pause, mode)


func _build_save_slots(layer: CanvasLayer, on_back: Callable, mode: String) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	layer.add_child(panel)
	var vb := _make_centered_box(panel)
	_add_title(vb, ("保存到存档位 Save" if mode == "save" else "读取存档 Load"), 32, Color(0.95, 0.9, 0.7))
	for i in range(1, 4):
		_add_save_slot_row(vb, layer, on_back, mode, i)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer)
	var cloud := HFlowContainer.new()
	cloud.add_theme_constant_override("separation", 10)
	var up := Button.new()
	up.text = "☁ 上传 Upload"
	up.add_theme_font_size_override("font_size", 18)
	ResponsiveLayout.set_button_wrap(up)
	up.pressed.connect(func(): CloudSaveService.upload("slot_1"))
	cloud.add_child(up)
	var down := Button.new()
	down.text = "☁ 下载 Download"
	down.add_theme_font_size_override("font_size", 18)
	ResponsiveLayout.set_button_wrap(down)
	down.pressed.connect(func(): CloudSaveService.download("slot_1"))
	cloud.add_child(down)
	vb.add_child(cloud)
	var hint := Label.new()
	hint.text = "云同步需登录账号；离线时自动忽略。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(hint)
	_add_button(vb, "返回 Back", func(): _close_overlay(layer, on_back))


func _add_save_slot_row(vb: VBoxContainer, layer: CanvasLayer, on_back: Callable, mode: String, i: int) -> void:
	var slot := "slot_%d" % i
	var summary := SaveManager.get_save_summary(slot)
	var empty: bool = summary.is_empty()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := Label.new()
	info.custom_minimum_size = Vector2(minf(300.0, ResponsiveLayout.viewport_size(self).x - ResponsiveLayout.margin(self) * 2.0), 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 16)
	if empty:
		info.text = "存档位 %d · 空 Empty" % i
		info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	else:
		var ch_id := String(summary.get("chapter", ""))
		var ch_data := ChapterManager.load_chapter_data(ch_id)
		info.text = "存档位 %d · %s\n%s" % [i, String(ch_data.get("title", ch_id)), String(summary.get("timestamp", ""))]
		info.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	row.add_child(info)
	var act := Button.new()
	act.text = "保存 Save" if mode == "save" else "读取 Load"
	act.add_theme_font_size_override("font_size", 18)
	ResponsiveLayout.set_button_wrap(act)
	act.disabled = (mode == "load" and empty)
	act.pressed.connect(func(): _on_slot_action(layer, on_back, mode, slot))
	row.add_child(act)
	if not empty:
		var del := Button.new()
		del.text = "删除 Del"
		del.add_theme_font_size_override("font_size", 18)
		ResponsiveLayout.set_button_wrap(del)
		del.pressed.connect(func(): _on_slot_delete(layer, on_back, mode, slot))
		row.add_child(del)
	vb.add_child(row)


func _on_slot_action(layer: CanvasLayer, on_back: Callable, mode: String, slot: String) -> void:
	if mode == "save":
		SaveManager.save_game(slot)
		_clear_layer(layer)
		_build_save_slots(layer, on_back, mode)
	else:
		_do_load_slot(slot)


func _on_slot_delete(layer: CanvasLayer, on_back: Callable, mode: String, slot: String) -> void:
	SaveManager.delete_save(slot)
	_clear_layer(layer)
	_build_save_slots(layer, on_back, mode)


func _do_load_slot(slot: String) -> void:
	_clear_layer(_pause_layer)
	_pause_visible = false
	if SaveManager.load_game(slot):
		var chapter := GameState.current_chapter_id
		if chapter == "":
			chapter = "city_of_destruction"
		ChapterManager.start_chapter(chapter)
	if _in_game and not DialogueManager.is_active():
		EventBus.unlock_player("pause_menu")


## Pick the route length for the NEXT new journey.
func _show_route_picker() -> void:
	_clear_menu()
	var panel := _make_fullscreen_panel(Color(0.04, 0.04, 0.08, 1.0))
	var vb := _make_centered_box(panel)
	_add_title(vb, LocaleManager.t("route.title", "这一趟走多远？"), 28, Color(0.95, 0.9, 0.7))
	_add_title(vb, LocaleManager.t("route.hint",
		"随时可以改；已开始的旅程不受影响。"), 16, Color(0.65, 0.68, 0.78))
	for id in ChapterManager.ROUTE_IDS.keys():
		var rid := String(id)
		var label := String(ChapterManager.ROUTE_IDS[rid])
		var mark := "◆ " if ChapterManager.route_id == rid else "   "
		_add_button(vb, mark + label, func(): _pick_route(rid))
	_add_button(vb, LocaleManager.t("menu.back", "返回 Back"), _show_title)


func _pick_route(rid: String) -> void:
	ChapterManager.set_route(rid)
	EventBus.toast(String(ChapterManager.ROUTE_IDS.get(rid, rid)))
	_show_title()


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

	var vb := _make_centered_box(panel)
	vb.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "天路历程 THE PILGRIM'S ROAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	vb.add_child(title)

	# CHAPTER SELECT.
	#
	# The route map was a read-only list of Labels: it could tell you where you
	# had been and gave you no way to go back there. Every chapter you had
	# already completed is now a BUTTON, so a player can revisit a stretch of
	# road — for teaching, for a different choice, or simply to look at it —
	# without replaying eleven chapters to reach it. Chapters you have not
	# reached stay inert, and a chapter whose `required_flags` you do not hold
	# says which key is missing rather than silently refusing.
	var current: String = ChapterManager.current_chapter_id
	for raw_chapter_id in ChapterManager.route:
		var chapter_id: String = String(raw_chapter_id)
		var data: Dictionary = ChapterManager.load_chapter_data(chapter_id)
		var done: bool = GameState.has_flag(chapter_id + "_completed")
		var visited: bool = GameState.has_visited_chapter(chapter_id) if GameState.has_method("has_visited_chapter") else done
		var is_current: bool = chapter_id == current
		var mark: String = "[完成]" if done else ("[当前]" if is_current else "[    ]")
		var color: Color = Color(0.6, 0.85, 0.6) if done else (Color(1, 0.95, 0.6) if is_current else Color(0.55, 0.55, 0.62))
		var title_text := "%s  %s" % [mark, String(data.get("title_zh", data.get("title", chapter_id)))]

		if (done or visited) and not is_current:
			var btn := Button.new()
			btn.text = title_text + "    ↩ 重走"
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", color)
			ResponsiveLayout.set_button_wrap(btn)
			var cid := chapter_id
			btn.pressed.connect(func(): _jump_to_chapter(cid))
			vb.add_child(btn)
		else:
			var label := Label.new()
			label.text = title_text
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", color)
			vb.add_child(label)

	var hint := Label.new()
	hint.text = "点「地图」或「暂停」关闭" if DisplayServer.is_touchscreen_available() else "Tab / Esc 关闭 · 点已完成的章节可重走"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(hint)


## Revisit a chapter you have already walked.
##
## This also puts `ChapterManager.can_enter_chapter()` to work for the first
## time. It has existed since the route system was written, reads the
## `required_flags` every chapter JSON declares, and was called by NOTHING — so
## those flags were decorative. Enforcing it HERE rather than on the linear path
## is deliberate: the main journey should never be able to soft-lock itself, but
## a free jump genuinely can land you somewhere you are not equipped for.
func _jump_to_chapter(chapter_id: String) -> void:
	if chapter_id == "" or chapter_id == ChapterManager.current_chapter_id:
		return
	if not ChapterManager.can_enter_chapter(chapter_id):
		var data := ChapterManager.load_chapter_data(chapter_id)
		var missing: Array[String] = []
		for f in data.get("required_flags", []):
			if not GameState.has_flag(String(f)):
				missing.append(DialogueManager.flag_label(String(f)))
		EventBus.toast("这一段还走不了：你还缺 %s。" % "、".join(PackedStringArray(missing)))
		return
	_route_visible = false
	for c in _route_layer.get_children():
		c.queue_free()
	GameState.set_flag("revisited_chapter", true)
	await ChapterManager.transition_to(chapter_id)


# ---------------------------------------------------------------------------
# Debug shortcuts (development aid)
# ---------------------------------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.shift_pressed and event.keycode in [KEY_F2, KEY_F3, KEY_F4, KEY_F7, KEY_F8]:
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
