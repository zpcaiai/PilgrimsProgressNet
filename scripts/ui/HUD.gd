extends CanvasLayer
class_name HUD
## Self-building heads-up display: quest tracker, a small spiritual panel
## (Faith / Hope / Despair / Burden), interaction prompt, dialogue box,
## toast notifications, and a despair "darkness" overlay.

var _darkness_overlay: ColorRect
var _quest_label: RichTextLabel
var _faith_bar: ProgressBar
var _hope_bar: ProgressBar
var _love_bar: ProgressBar
var _despair_bar: ProgressBar
var _weariness_bar: ProgressBar
var _sleep_bar: ProgressBar
var _vanity_bar: ProgressBar
var _river_bar: ProgressBar
var _humility_bar: ProgressBar
var _watchfulness_bar: ProgressBar
var _fear_bar: ProgressBar
var _shame_bar: ProgressBar
var _load_label: Label
var _burden_label: Label
var _prompt_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0
var _stat_labels: Array = []
var _stat_value_labels: Array = []
var _lang_btn: Button
var _quest_panel: Panel
var _spiritual_panel: Panel
var _debug_panel: Panel
var _debug_label: RichTextLabel
var _debug_visible: bool = false

# Dialogue
var _dialogue_panel: Panel
var _dialogue_hbox: HBoxContainer
var _dialogue_scroll: ScrollContainer
var _portrait: TextureRect
var _speaker_label: Label
var _text_label: RichTextLabel
var _choice_box: VBoxContainer
var _current_choices: Array = []

# Grace / glory animation overlay (optional flipbook)
var _grace_anim: AnimatedSprite2D

const FONT_TITLE := 22
const FONT_BODY := 18
const MOBILE_FONT_TITLE := 30
const MOBILE_FONT_BODY := 24
const MOBILE_FONT_DIALOGUE := 28
const MOBILE_FONT_CHOICE := 25
const MOBILE_FONT_NARRATION := 26
const ResponsiveLayout := preload("res://scripts/ui/ResponsiveLayout.gd")

# Title card
var _title_card: Control
var _title_bg: TextureRect
var _title_center: CenterContainer
var _title_main: Label
var _title_sub: Label

# Character panel
var _char_panel: Panel
var _char_label: RichTextLabel
var _char_visible: bool = false

# Narration (reflective inner voice that opens each chapter)
var _narration_panel: Panel
var _narration_label: RichTextLabel
var _narration_queue: Array = []
var _narration_index: int = -1
var _narration_phase: int = 0  # 0 idle, 1 fade-in, 2 hold, 3 fade-out
var _narration_timer: float = 0.0
const NARR_FADE := 0.7
const NARR_HOLD := 4.2


func _ready() -> void:
	layer = 10
	_build_darkness()
	_build_quest_tracker()
	_build_spiritual_panel()
	_build_prompt()
	_build_toast()
	_build_dialogue()
	_build_title_card()
	_build_char_panel()
	_build_narration()
	_build_grace_anim()
	_build_debug_panel()
	_connect_signals()
	_build_lang_toggle()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_refresh_quest()


func _connect_signals() -> void:
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.dialogue_node_changed.connect(_on_dialogue_node)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.dialogue_started.connect(func(_id): _hide_prompt())
	EventBus.quest_started.connect(func(_id): _refresh_quest())
	EventBus.quest_updated.connect(func(_id): _refresh_quest())
	EventBus.quest_completed.connect(func(_id): _refresh_quest())
	EventBus.notify.connect(_on_toast)
	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.input_open_journal.connect(_on_open_journal)
	if EventBus.has_signal("cross_grace_applied"):
		EventBus.cross_grace_applied.connect(_on_cross_grace)
	EventBus.locale_changed.connect(_on_locale_changed)


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------
func _panel_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _viewport_size() -> Vector2:
	return ResponsiveLayout.viewport_size(self)


func _is_mobile_ui() -> bool:
	return ResponsiveLayout.is_mobile(self)


func _body_font() -> int:
	return MOBILE_FONT_BODY if _is_mobile_ui() else FONT_BODY


func _title_font() -> int:
	return MOBILE_FONT_TITLE if _is_mobile_ui() else FONT_TITLE


func _dialogue_font() -> int:
	return MOBILE_FONT_DIALOGUE if _is_mobile_ui() else FONT_BODY


func _safe_margin() -> float:
	return 24.0 if _is_mobile_ui() else 20.0


func _choice_font() -> int:
	return MOBILE_FONT_CHOICE if _is_mobile_ui() else FONT_BODY


func _show_dialogue_portrait() -> bool:
	var s := _viewport_size()
	return not _is_mobile_ui() or s.x >= 900.0


func _set_bottom_wide_rect(control: Control, left: float, bottom: float, width: float, height: float) -> void:
	var s := _viewport_size()
	control.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	control.offset_left = left
	control.offset_right = left + width
	control.offset_top = -bottom - height
	control.offset_bottom = -bottom


func _apply_inner_rect(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


func _apply_responsive_layout() -> void:
	var s := _viewport_size()
	var mobile := _is_mobile_ui()
	var portrait := s.x < s.y
	var body := _body_font()
	var title := _title_font()
	var dialogue := _dialogue_font()
	var margin := _safe_margin()

	if is_instance_valid(_quest_panel):
		if mobile and portrait:
			_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_quest_panel.position = Vector2(margin, margin)
			_quest_panel.size = Vector2(maxf(220.0, s.x - margin * 2.0), 156)
		elif mobile:
			_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_quest_panel.position = Vector2(margin, margin)
			_quest_panel.size = Vector2(minf(520.0, maxf(360.0, s.x * 0.34)), 156)
		else:
			_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_quest_panel.position = Vector2(margin, margin)
			_quest_panel.size = Vector2(340, 134)
	if is_instance_valid(_quest_label):
		_quest_label.add_theme_font_size_override("normal_font_size", body)
		_quest_label.add_theme_font_size_override("bold_font_size", body)
		_quest_label.add_theme_constant_override("line_separation", 6 if mobile else 4)
		_quest_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART

	if is_instance_valid(_spiritual_panel):
		if mobile and portrait:
			_spiritual_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_spiritual_panel.position = Vector2(margin, _quest_panel.position.y + _quest_panel.size.y + 12.0)
			_spiritual_panel.size = Vector2(maxf(220.0, s.x - margin * 2.0), 150)
		elif mobile:
			_spiritual_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_spiritual_panel.position = Vector2(-346, margin)
			_spiritual_panel.size = Vector2(330, 150)
		else:
			_spiritual_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_spiritual_panel.position = Vector2(-272, margin)
			_spiritual_panel.size = Vector2(252, 305)
	for lbl in _stat_labels:
		if is_instance_valid(lbl):
			lbl.custom_minimum_size = Vector2(104 if mobile else 70, 0)
			lbl.add_theme_font_size_override("font_size", body)
			ResponsiveLayout.apply_text_wrap(lbl, mobile)
	for vlbl in _stat_value_labels:
		if is_instance_valid(vlbl):
			vlbl.custom_minimum_size = Vector2(42 if mobile else 32, 0)
			vlbl.add_theme_font_size_override("font_size", body)
	for bar in [_faith_bar, _hope_bar, _love_bar, _humility_bar, _watchfulness_bar, _despair_bar, _fear_bar, _shame_bar, _weariness_bar]:
		if is_instance_valid(bar):
			bar.custom_minimum_size = Vector2(170 if mobile else 120, 20 if mobile else 16)
			bar.get_parent().visible = not mobile or bar in [_faith_bar, _hope_bar, _love_bar]
	if is_instance_valid(_burden_label):
		_burden_label.visible = not mobile
		_burden_label.add_theme_font_size_override("font_size", body)
		ResponsiveLayout.apply_text_wrap(_burden_label, mobile)
	if is_instance_valid(_load_label):
		_load_label.visible = not mobile
		_load_label.add_theme_font_size_override("font_size", body)
		ResponsiveLayout.apply_text_wrap(_load_label, mobile)

	if is_instance_valid(_prompt_label):
		_prompt_label.add_theme_font_size_override("font_size", title)
		var prompt_w := minf(520.0, s.x - 48.0)
		_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_prompt_label.position = Vector2((s.x - prompt_w) * 0.5, -210 if mobile else -180)
		_prompt_label.size = Vector2(prompt_w, 54 if mobile else 40)
		_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt_label.clip_text = false
	if is_instance_valid(_toast_label):
		_toast_label.add_theme_font_size_override("font_size", body)
		var toast_w := minf(760.0, s.x - 48.0)
		_toast_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var toast_y := 130.0
		if mobile:
			toast_y = (_spiritual_panel.position.y + _spiritual_panel.size.y + 10.0) if portrait else (_quest_panel.position.y + _quest_panel.size.y + 10.0)
		_toast_label.position = Vector2((s.x - toast_w) * 0.5, toast_y)
		_toast_label.size = Vector2(toast_w, 86 if mobile else 34)
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART
		_toast_label.clip_text = false

	if is_instance_valid(_dialogue_panel):
		if mobile:
			var dialog_w := maxf(220.0, s.x - margin * 2.0)
			var dialog_h := clampf(s.y * 0.42, 300.0, 380.0)
			_set_bottom_wide_rect(_dialogue_panel, margin, 64.0, dialog_w, dialog_h)
		else:
			var dw := minf(1040.0, s.x - 240.0)
			_set_bottom_wide_rect(_dialogue_panel, (s.x - dw) * 0.5, 30.0, dw, 290.0)
	if is_instance_valid(_dialogue_hbox):
		_dialogue_hbox.add_theme_constant_override("separation", 10 if mobile else 16)
	if is_instance_valid(_dialogue_scroll):
		_dialogue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(_portrait):
		_portrait.custom_minimum_size = Vector2(128, 128) if mobile else Vector2(168, 168)
		if not _show_dialogue_portrait():
			_portrait.visible = false
	if is_instance_valid(_speaker_label):
		_speaker_label.add_theme_font_size_override("font_size", title)
		ResponsiveLayout.apply_text_wrap(_speaker_label, mobile)
	if is_instance_valid(_text_label):
		_text_label.add_theme_font_size_override("normal_font_size", dialogue)
		_text_label.add_theme_font_size_override("bold_font_size", dialogue)
		_text_label.add_theme_constant_override("line_separation", 8 if mobile else 4)
		_text_label.custom_minimum_size = Vector2(0, 126 if mobile else 68)
		_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(_choice_box):
		_choice_box.add_theme_constant_override("separation", 8 if mobile else 4)
		for child in _choice_box.get_children():
			if child is Button:
				(child as Button).add_theme_font_size_override("font_size", _choice_font())
				(child as Button).custom_minimum_size = Vector2(0, 56 if mobile else 44)
				ResponsiveLayout.set_button_wrap(child as Button)

	if is_instance_valid(_title_center):
		var title_w := minf(s.x - 48.0, 760.0) if mobile else 600.0
		var title_h := 230.0 if mobile else 160.0
		_title_center.position = Vector2(-title_w * 0.5, -title_h * 0.5)
		_title_center.size = Vector2(title_w, title_h)
	if is_instance_valid(_title_main):
		_title_main.add_theme_font_size_override("font_size", 44 if mobile else 40)
		_title_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(_title_sub):
		_title_sub.add_theme_font_size_override("font_size", 28 if mobile else 22)
		_title_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_instance_valid(_narration_panel):
		var narr_w := minf(maxf(240.0, s.x - 64.0), 760.0)
		_narration_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_narration_panel.position = Vector2((s.x - narr_w) * 0.5, _narration_panel.position.y)
		_narration_panel.size = Vector2(narr_w, _narration_panel.size.y)
	if is_instance_valid(_narration_label):
		_narration_label.add_theme_font_size_override("normal_font_size", MOBILE_FONT_NARRATION if mobile else 21)
		_resize_narration_to_content()

	if is_instance_valid(_char_panel):
		if mobile:
			var cw := minf(s.x - 48.0, 620.0)
			var ch := minf(s.y - 96.0, 560.0)
			_char_panel.position = Vector2(-cw * 0.5, -ch * 0.5)
			_char_panel.size = Vector2(cw, ch)
			_char_label.fit_content = false
			_char_label.scroll_active = true
		else:
			_char_panel.position = Vector2(-230, -210)
			_char_panel.size = Vector2(460, 420)
			_char_label.fit_content = true
			_char_label.scroll_active = false
	if is_instance_valid(_char_label):
		_char_label.add_theme_font_size_override("normal_font_size", body)
		_char_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if mobile else TextServer.AUTOWRAP_WORD_SMART

	if is_instance_valid(_lang_btn):
		_lang_btn.add_theme_font_size_override("font_size", 18 if mobile else 14)
		_lang_btn.position = Vector2(16 if mobile else 20, -54 if mobile else -40)
		_lang_btn.custom_minimum_size = Vector2(86, 42) if mobile else Vector2.ZERO

	if is_instance_valid(_debug_panel):
		var dw := minf(520.0, s.x - 32.0)
		_debug_panel.position = Vector2(16, s.y - 214.0)
		_debug_panel.size = Vector2(dw, 198.0)
		_debug_label.add_theme_font_size_override("normal_font_size", 15 if not mobile else 18)

	# Re-flow the auto-sized objective box (and narration) for the new viewport.
	_refresh_mobile_hud_chrome()
	if is_instance_valid(_quest_label):
		_refresh_quest()


func _build_darkness() -> void:
	_darkness_overlay = ColorRect.new()
	_darkness_overlay.color = Color(0.02, 0.0, 0.05, 0.0)
	_darkness_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darkness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_darkness_overlay)


func _build_quest_tracker() -> void:
	_quest_panel = Panel.new()
	_quest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.09, 0.65)))
	_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quest_panel.position = Vector2(20, 20)
	_quest_panel.size = Vector2(340, 134)
	add_child(_quest_panel)
	_quest_label = RichTextLabel.new()
	_quest_label.bbcode_enabled = true
	_quest_label.fit_content = false
	_quest_label.scroll_active = false
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_apply_inner_rect(_quest_label, 14.0)
	_quest_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_quest_label.add_theme_font_size_override("bold_font_size", FONT_BODY)
	_quest_label.add_theme_constant_override("line_separation", 4)
	_quest_panel.add_child(_quest_label)


func _build_spiritual_panel() -> void:
	_spiritual_panel = Panel.new()
	_spiritual_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.09, 0.65)))
	_spiritual_panel.size = Vector2(252, 305)
	_spiritual_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_spiritual_panel.position = Vector2(-272, 20)
	add_child(_spiritual_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	_spiritual_panel.add_child(vb)

	_faith_bar = _add_stat_row(vb, "hud.faith", "信心 Faith", Color(0.95, 0.85, 0.4))
	_hope_bar = _add_stat_row(vb, "hud.hope", "盼望 Hope", Color(0.45, 0.8, 0.95))
	_love_bar = _add_stat_row(vb, "hud.love", "爱心 Love", Color(0.95, 0.58, 0.58))
	_humility_bar = _add_stat_row(vb, "hud.humility", "谦卑 Humility", Color(0.55, 0.8, 0.5))
	_watchfulness_bar = _add_stat_row(vb, "hud.watchfulness", "警醒 Vigilance", Color(0.5, 0.7, 0.95))
	_despair_bar = _add_stat_row(vb, "hud.despair", "绝望 Despair", Color(0.6, 0.35, 0.62))
	_fear_bar = _add_stat_row(vb, "hud.fear", "惧怕 Fear", Color(0.82, 0.42, 0.46))
	_shame_bar = _add_stat_row(vb, "hud.shame", "羞愧 Shame", Color(0.72, 0.46, 0.36))
	_weariness_bar = _add_stat_row(vb, "hud.weariness", "疲惫 Weariness", Color(0.6, 0.55, 0.4))

	# CHAPTER PRESSURE METERS.
	#
	# GameState carries three per-chapter "temporary meters" — sleepiness on the
	# Enchanted Ground, vanity pressure at the Fair, river depth at the crossing.
	# All three drive real mechanics (SleepinessSystem, VanityPressureSystem,
	# RiverDepthSystem) and NONE of them were ever shown, so the player was
	# losing to a number they could not see. Each row appears only in the
	# chapter that uses it.
	_sleep_bar = _add_stat_row(vb, "hud.sleepiness", "困倦 Sleepiness", Color(0.55, 0.5, 0.75))
	_vanity_bar = _add_stat_row(vb, "hud.vanity_pressure", "虚荣压力 Vanity", Color(0.9, 0.65, 0.35))
	_river_bar = _add_stat_row(vb, "hud.river_depth", "水深 River", Color(0.4, 0.65, 0.9))

	_burden_label = Label.new()
	_burden_label.add_theme_font_size_override("font_size", FONT_BODY)
	_burden_label.text = LocaleManager.t("hud.burden_carried", "Burden: carried")
	_burden_label.modulate = Color(0.85, 0.7, 0.6)
	ResponsiveLayout.apply_text_wrap(_burden_label)
	vb.add_child(_burden_label)

	_load_label = Label.new()
	_load_label.add_theme_font_size_override("font_size", FONT_BODY)
	_load_label.modulate = Color(0.8, 0.8, 0.88)
	ResponsiveLayout.apply_text_wrap(_load_label)
	vb.add_child(_load_label)


## Show only the pressure meter this chapter actually uses, so the panel does
## not grow three permanently-zero rows.
func _update_pressure_meters() -> void:
	var cid := String(ChapterManager.current_chapter_id)
	_set_meter(_sleep_bar, "sleepiness", cid == "enchanted_ground")
	_set_meter(_vanity_bar, "vanity_pressure", cid == "vanity_fair")
	_set_meter(_river_bar, "river_depth_pressure", cid == "river_of_death")


func _set_meter(bar: ProgressBar, key: String, active: bool) -> void:
	if not is_instance_valid(bar):
		return
	var row: Node = bar.get_parent()
	var v := GameState.get_temporary_meter(key)
	if row is CanvasItem:
		(row as CanvasItem).visible = active and (v > 0 or bar.value > 0.5)
	bar.value = v
	if bar.has_meta("vlabel"):
		(bar.get_meta("vlabel") as Label).text = str(v)


func _add_stat_row(parent: VBoxContainer, key: String, fallback: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = LocaleManager.t(key, fallback)
	lbl.set_meta("i18n_key", key)
	lbl.set_meta("i18n_fb", fallback)
	_stat_labels.append(lbl)
	lbl.custom_minimum_size = Vector2(70, 0)
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	ResponsiveLayout.apply_text_wrap(lbl)
	row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.18)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	# Numeric readout so a stat is legible without reading the bar length (also
	# helps colour-blind players who can't rely on the fill colour alone).
	var val := Label.new()
	val.add_theme_font_size_override("font_size", FONT_BODY)
	val.custom_minimum_size = Vector2(32, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.modulate = Color(0.82, 0.85, 0.92)
	row.add_child(val)
	bar.set_meta("vlabel", val)
	_stat_value_labels.append(val)
	parent.add_child(row)
	return bar


func _build_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-200, -180)
	_prompt_label.size = Vector2(400, 40)
	ResponsiveLayout.apply_text_wrap(_prompt_label)
	_prompt_label.visible = false
	add_child(_prompt_label)


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", FONT_BODY)
	_toast_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast_label.add_theme_constant_override("outline_size", 5)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position = Vector2(-300, 130)
	_toast_label.size = Vector2(600, 30)
	ResponsiveLayout.apply_text_wrap(_toast_label)
	_toast_label.visible = false
	add_child(_toast_label)


func _build_dialogue() -> void:
	_dialogue_panel = Panel.new()
	_dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.08, 0.92)))
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_set_bottom_wide_rect(_dialogue_panel, 120.0, 30.0, 1040.0, 230.0)
	_dialogue_panel.visible = false
	add_child(_dialogue_panel)

	_dialogue_hbox = HBoxContainer.new()
	_apply_inner_rect(_dialogue_hbox, 16.0)
	_dialogue_hbox.add_theme_constant_override("separation", 16)
	_dialogue_panel.add_child(_dialogue_hbox)

	# Optional speaker portrait (hidden when no art exists for the speaker).
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(168, 168)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	_dialogue_hbox.add_child(_portrait)

	_dialogue_scroll = ScrollContainer.new()
	_dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialogue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.follow_focus = true
	_dialogue_hbox.add_child(_dialogue_scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	_dialogue_scroll.add_child(vb)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_speaker_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	ResponsiveLayout.apply_text_wrap(_speaker_label)
	vb.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	_text_label.scroll_active = true
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 60)
	_text_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.98))
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_text_label.add_theme_constant_override("outline_size", 3)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	vb.add_child(_choice_box)


func _build_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.04, 0.07, 0.88)))
	_debug_panel.visible = false
	add_child(_debug_panel)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = false
	_debug_label.scroll_active = false
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_inner_rect(_debug_label, 12.0)
	_debug_panel.add_child(_debug_label)


# ---------------------------------------------------------------------------
# Chapter title card
# ---------------------------------------------------------------------------
func _build_title_card() -> void:
	_title_card = Control.new()
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate = Color(1, 1, 1, 0)
	add_child(_title_card)
	# Optional per-chapter backdrop art, drawn behind the title text and dimmed
	# so the text stays readable. Fades with the title card.
	_title_bg = TextureRect.new()
	_title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bg.visible = false
	_title_card.add_child(_title_bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.add_child(dim)
	_title_center = CenterContainer.new()
	_title_center.set_anchors_preset(Control.PRESET_CENTER)
	_title_center.position = Vector2(-300, -80)
	_title_center.size = Vector2(600, 160)
	_title_card.add_child(_title_center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_title_center.add_child(vb)
	_title_main = Label.new()
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_main.add_theme_font_size_override("font_size", 40)
	_title_main.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	_title_main.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_main.add_theme_constant_override("outline_size", 8)
	ResponsiveLayout.apply_text_wrap(_title_main)
	vb.add_child(_title_main)
	_title_sub = Label.new()
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub.add_theme_font_size_override("font_size", 22)
	_title_sub.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	_title_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_sub.add_theme_constant_override("outline_size", 6)
	ResponsiveLayout.apply_text_wrap(_title_sub)
	vb.add_child(_title_sub)


func _on_chapter_started(chapter_id: String) -> void:
	var data := ChapterManager.load_chapter_data(chapter_id)
	var art := AssetLib.scene_art(chapter_id)
	_title_bg.texture = art
	_title_bg.visible = art != null
	_title_main.text = String(data.get("title", chapter_id))
	var preview := ScriptureMemory.chapter_preview_line(chapter_id)
	if preview != "":
		var limit := 46 if _is_mobile_ui() else 160
		var short_preview := preview.left(limit) + ("…" if preview.length() > limit else "")
		get_tree().create_timer(7.5).timeout.connect(func(): EventBus.toast("✦ " + short_preview))
	_title_sub.text = String(data.get("subtitle", ""))
	var tw := create_tween()
	tw.tween_property(_title_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(_title_card, "modulate:a", 0.0, 1.0)
	# Queue the chapter's reflective opening narration after the title card.
	var intro: Array = data.get("intro", [])
	if not intro.is_empty():
		_pending_intro = intro.duplicate()
		_intro_delay = 4.2
	# Refresh the objective/story panel so the new chapter's header + goal show at once.
	_refresh_quest()


# ---------------------------------------------------------------------------
# Grace / glory animation overlay (optional flipbook sprite sheet)
# ---------------------------------------------------------------------------
func _build_grace_anim() -> void:
	var sf := AssetLib.sprite_frames("grace_glory", 8, 16.0, false)
	if sf == null:
		return  # no sheet shipped: silently skip (greybox particles still play)
	_grace_anim = AnimatedSprite2D.new()
	_grace_anim.sprite_frames = sf
	_grace_anim.centered = true
	_grace_anim.scale = Vector2(2.4, 2.4)
	_grace_anim.visible = false
	_grace_anim.z_index = 50
	add_child(_grace_anim)
	_grace_anim.animation_finished.connect(func(): _grace_anim.visible = false)


func _on_cross_grace() -> void:
	if _grace_anim == null:
		return
	_grace_anim.position = ResponsiveLayout.viewport_size(self) * 0.5
	_grace_anim.visible = true
	_grace_anim.frame = 0
	_grace_anim.play("default")


# ---------------------------------------------------------------------------
# Narration (reflective inner voice)
# ---------------------------------------------------------------------------
var _pending_intro: Array = []
var _intro_delay: float = 0.0


func _build_narration() -> void:
	_narration_panel = Panel.new()
	# Semi-opaque scrim so the reflective narration stays readable over any scene
	# (a fully transparent panel let bright scenes wash the text out completely).
	var sb := _panel_style(Color(0.04, 0.04, 0.08, 0.62))
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_narration_panel.add_theme_stylebox_override("panel", sb)
	_narration_panel.set_anchors_preset(Control.PRESET_CENTER)
	_narration_panel.position = Vector2(-360, -45)
	_narration_panel.size = Vector2(720, 90)
	_narration_panel.modulate = Color(1, 1, 1, 0)
	_narration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_narration_panel)
	_narration_label = RichTextLabel.new()
	_narration_label.bbcode_enabled = true
	_narration_label.fit_content = true
	_narration_label.scroll_active = false
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration_label.add_theme_font_size_override("normal_font_size", 21)
	_narration_label.add_theme_color_override("default_color", Color(0.95, 0.93, 0.82))
	_narration_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_narration_label.add_theme_constant_override("outline_size", 4)
	_narration_panel.add_child(_narration_label)


func play_narration(lines: Array) -> void:
	if lines.is_empty():
		return
	_narration_queue = lines.duplicate()
	_narration_index = 0
	_narration_phase = 1
	_narration_timer = 0.0
	_refresh_mobile_hud_chrome()
	_show_narration_line()


## Let the player move past the chapter-opening narration instead of waiting out
## each timed line — a tap / click / Enter skips the current line to the next.
func _unhandled_input(event: InputEvent) -> void:
	if _narration_phase == 0:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		skip = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER]:
		skip = true
	if skip:
		if _narration_phase == 1 or _narration_phase == 2:
			_narration_phase = 3
			_narration_timer = 0.0
		get_viewport().set_input_as_handled()


func _show_narration_line() -> void:
	var line := String(_narration_queue[_narration_index])
	if _is_mobile_ui():
		_narration_label.text = "[center][i]" + line + "[/i][/center]"
	else:
		_narration_label.text = "[center][i]" + line + "[/i]\n[font_size=13][color=#8b93a6]（点按 / 回车 继续）[/color][/font_size][/center]"
	_resize_narration_to_content()
	Settings.speak(line)


## Grow the narration scrim to fit the current line and keep it centred in the
## empty mid-screen band (clear of the corner panels and the bottom dialogue).
func _resize_narration_to_content() -> void:
	if not is_instance_valid(_narration_panel) or not is_instance_valid(_narration_label):
		return
	var s := _viewport_size()
	var h := clampf(_narration_label.get_content_height() + 28.0, 60.0, 280.0)
	_narration_panel.size = Vector2(_narration_panel.size.x, h)
	_narration_panel.position = Vector2((s.x - _narration_panel.size.x) * 0.5,
		clampf(s.y * 0.36 - h * 0.5, 92.0, maxf(92.0, s.y - h - 260.0)))


func _process_narration(delta: float) -> void:
	# Handle the delayed intro start.
	if _intro_delay > 0.0:
		_intro_delay -= delta
		if _intro_delay <= 0.0 and not _pending_intro.is_empty():
			play_narration(_pending_intro)
			_pending_intro = []
	if _narration_phase == 0:
		return
	_narration_timer += delta
	match _narration_phase:
		1:  # fade in
			_narration_panel.modulate.a = clampf(_narration_timer / NARR_FADE, 0.0, 1.0)
			if _narration_timer >= NARR_FADE:
				_narration_phase = 2
				_narration_timer = 0.0
		2:  # hold
			if _narration_timer >= NARR_HOLD:
				_narration_phase = 3
				_narration_timer = 0.0
		3:  # fade out
			_narration_panel.modulate.a = clampf(1.0 - _narration_timer / NARR_FADE, 0.0, 1.0)
			if _narration_timer >= NARR_FADE:
				_narration_index += 1
				if _narration_index < _narration_queue.size():
					_narration_phase = 1
					_narration_timer = 0.0
					_show_narration_line()
				else:
					_narration_phase = 0
					_narration_index = -1
					_refresh_mobile_hud_chrome()


func _refresh_mobile_hud_chrome() -> void:
	if not is_instance_valid(_quest_panel) or not is_instance_valid(_spiritual_panel):
		return
	var show_chrome := not _is_mobile_ui() or (_narration_phase == 0 and not _dialogue_panel.visible)
	_quest_panel.visible = show_chrome
	_spiritual_panel.visible = show_chrome


# ---------------------------------------------------------------------------
# Character / inventory panel (toggle with C)
# ---------------------------------------------------------------------------
func _build_char_panel() -> void:
	_char_panel = Panel.new()
	_char_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.09, 0.92)))
	_char_panel.set_anchors_preset(Control.PRESET_CENTER)
	_char_panel.position = Vector2(-230, -210)
	_char_panel.size = Vector2(460, 420)
	_char_panel.visible = false
	add_child(_char_panel)
	_char_label = RichTextLabel.new()
	_char_label.bbcode_enabled = true
	_char_label.fit_content = true
	_char_label.scroll_active = false
	_char_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_char_panel.add_child(_char_label)


func _toggle_char_panel() -> void:
	_char_visible = not _char_visible
	_char_panel.visible = _char_visible
	if _char_visible:
		_refresh_char_panel()


func _on_open_journal() -> void:
	if _dialogue_panel.visible:
		return
	if not _char_visible:
		_toggle_char_panel()
	else:
		_refresh_char_panel()


func _refresh_char_panel() -> void:
	var s := SpiritualStateManager
	var mode_label := LocaleManager.t("char.mode_child", "Children's Journey") if GameState.is_child_mode() else LocaleManager.t("char.mode_devout", "Devout Journey")
	var close_hint := LocaleManager.t("char.close_hint_touch", "再次点「心境」关闭") if _is_mobile_ui() else LocaleManager.t("char.close_hint", "(C to close)")
	var t := "[b]" + LocaleManager.t("char.title", "The Pilgrim's Heart") + "[/b]   [color=#888888]" + close_hint + "[/color]\n"
	t += "[color=#9aa6c0]" + mode_label + "[/color]\n\n"
	t += "[color=#f0e0a0]" + LocaleManager.t("char.graces", "Graces") + "[/color]\n"
	t += "  %s %d   %s %d   %s %d\n" % [LocaleManager.t("hud.faith","Faith"), s.faith, LocaleManager.t("hud.hope","Hope"), s.hope, LocaleManager.t("hud.love","Love"), s.love]
	t += "  %s %d   %s %d   %s %d\n" % [LocaleManager.t("hud.humility","Humility"), s.humility, LocaleManager.t("hud.discernment","Discernment"), s.discernment, LocaleManager.t("hud.perseverance","Perseverance"), s.perseverance]
	t += "  %s %d\n\n" % [LocaleManager.t("hud.watchfulness","Watchfulness"), s.watchfulness]
	t += "[color=#d0a0c0]" + LocaleManager.t("char.burdens", "Burdens") + "[/color]\n"
	t += "  %s %d   %s %d   %s %d\n" % [LocaleManager.t("hud.despair","Despair"), s.despair, LocaleManager.t("hud.shame","Shame"), s.shame, LocaleManager.t("hud.fear","Fear"), s.fear]
	t += "  %s %d   %s %d   %s %d\n\n" % [LocaleManager.t("hud.pride","Pride"), s.pride, LocaleManager.t("hud.deception","Deception"), s.deception, LocaleManager.t("hud.weariness","Weariness"), s.weariness]
	t += "[color=#a0d0f0]" + LocaleManager.t("char.tokens", "Tokens") + "[/color]\n"
	var tokens: Array = []
	if s.has_burden: tokens.append(LocaleManager.t("token.burden", "Burden (carried)"))
	if s.has_scroll: tokens.append(LocaleManager.t("token.scroll", "Scroll"))
	if s.has_seal: tokens.append(LocaleManager.t("token.seal", "Seal"))
	if s.has_new_garment: tokens.append(LocaleManager.t("token.new_garment", "New Garment"))
	if s.has_promise_key: tokens.append(LocaleManager.t("token.promise_key", "Key of Promise"))
	t += "  " + (", ".join(PackedStringArray(tokens)) if not tokens.is_empty() else LocaleManager.t("char.none_yet", "none yet")) + "\n\n"
	t += "[color=#f0d890]学习进度[/color]\n"
	t += "  " + ScriptureMemory.reflection_progress_summary() + "\n\n"
	t += "[color=#f0d890]经文记忆[/color]\n"
	t += ScriptureMemory.known_card_summary(5) + "\n\n"
	t += "[color=#f0d890]旅程日志[/color]\n"
	t += JourneyJournal.summary_text(5) + "\n\n"
	t += "[color=#a0f0c0]" + LocaleManager.t("char.companions", "Companions") + "[/color]\n"
	var comps: Array = GameState.companions.keys()
	var comp_names: Array = []
	for comp_id in comps:
		comp_names.append(LocaleManager.npc_label(_companion_display_name(String(comp_id))))
	t += "  " + (", ".join(PackedStringArray(comp_names)) if not comp_names.is_empty() else LocaleManager.t("char.walking_alone", "walking alone")) + "\n"
	_char_label.text = t


func _companion_display_name(companion_id: String) -> String:
	match companion_id:
		"hopeful":
			return "Hopeful"
		"pliable":
			return "Pliable"
		"faithful":
			return "Faithful"
		_:
			return companion_id.capitalize()


# ---------------------------------------------------------------------------
# Process: live bars + darkness + toast countdown
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_instance_valid(_faith_bar):
		_faith_bar.value = SpiritualStateManager.faith
		_hope_bar.value = SpiritualStateManager.hope
		_love_bar.value = SpiritualStateManager.love
		_humility_bar.value = SpiritualStateManager.humility
		_watchfulness_bar.value = SpiritualStateManager.watchfulness
		_despair_bar.value = SpiritualStateManager.despair
		_fear_bar.value = SpiritualStateManager.fear
		_shame_bar.value = SpiritualStateManager.shame
		_weariness_bar.value = SpiritualStateManager.weariness
		for _b in [_faith_bar, _hope_bar, _love_bar, _humility_bar, _watchfulness_bar, _despair_bar, _fear_bar, _shame_bar, _weariness_bar]:
			if is_instance_valid(_b) and _b.has_meta("vlabel"):
				(_b.get_meta("vlabel") as Label).text = str(int(round(_b.value)))
		_update_pressure_meters()
		var load_pct := int(round(SpiritualStateManager.get_movement_penalty() * 100.0))
		_load_label.text = (LocaleManager.t("hud.load_slower", "Load: %d%% slower") % load_pct) if load_pct > 0 else LocaleManager.t("hud.load_light", "Load: light")
		_load_label.modulate = Color(0.9, 0.6, 0.55) if load_pct >= 25 else Color(0.78, 0.8, 0.88)
		_burden_label.text = LocaleManager.t("hud.burden_carried", "Burden: carried") if SpiritualStateManager.has_burden else LocaleManager.t("hud.burden_fallen", "Burden: fallen")
		_burden_label.modulate = Color(0.85, 0.7, 0.6) if SpiritualStateManager.has_burden else Color(0.7, 0.95, 0.7)

	if is_instance_valid(_darkness_overlay):
		var target := SpiritualStateManager.get_visual_darkness()
		var a: float = lerp(_darkness_overlay.color.a, target, delta * 2.0)
		_darkness_overlay.color = Color(0.02, 0.0, 0.05, a)

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.visible = false

	if _char_visible:
		_refresh_char_panel()
	if _debug_visible:
		_refresh_debug_panel()

	_process_narration(delta)


func _refresh_debug_panel() -> void:
	if not is_instance_valid(_debug_label):
		return
	var input := InputManager.debug_snapshot() if InputManager else {}
	var hist := DialogueManager.get_history_summary() if DialogueManager else {}
	var target := "无"
	if get_tree():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0].has_method("get"):
			var cur = players[0].get("_current_target")
			if cur != null:
				target = String(cur.name)
	_debug_label.text = "[b]调试 Debug[/b]\n输入上下文：%s  锁定：%s\n移动：%s\n按下：%s\n对话：%s / %s  最近选择：%s\n交互目标：%s\nP/Q 祷告冷却：%.1f  R 悔改冷却：%.1f" % [
		String(input.get("context", "")),
		str(input.get("movement_locked", false)),
		str(input.get("movement", Vector2.ZERO)),
		", ".join(PackedStringArray(input.get("pressed", []))),
		String(hist.get("dialogue", "")),
		String(hist.get("node", "")),
		String(hist.get("last_choice", "")),
		target,
		SpiritualStateManager.prayer_cooldown_left(),
		SpiritualStateManager.repentance_cooldown_left(),
	]


# ---------------------------------------------------------------------------
# Quest tracker
# ---------------------------------------------------------------------------
func _refresh_quest() -> void:
	if not is_instance_valid(_quest_label):
		return
	if ChapterManager.current_chapter_id == "":
		_quest_label.text = LocaleManager.t("hud.quest_quiet", "这条路一片安静。")
		_resize_quest_to_content()
		return
	# Keep the objective panel task-focused. The chapter title card already names
	# the place; repeating it here costs too much space on mobile.
	var data: Dictionary = ChapterManager.get_current_chapter_data()
	var quest := QuestManager.get_primary_active_quest()
	if quest.is_empty():
		var sub := String(data.get("subtitle", ""))
		var goal := sub if sub != "" else LocaleManager.t("hud.quest_quiet", "The road is quiet.")
		_quest_label.text = "[color=#cfcfe0]" + goal + "[/color]"
		_resize_quest_to_content()
		return
	var qid := String(quest.get("id", ""))
	var step := QuestManager.get_next_incomplete_step_text(qid)
	_quest_label.text = "[b]%s[/b]\n[color=#cfcfe0]%s[/color]" % [String(quest.get("title", "")), step]
	_resize_quest_to_content()


## Grow the objective box to fit its text so long goals never spill out of the
## panel background (or get clipped by a fixed height).
func _resize_quest_to_content() -> void:
	if not is_instance_valid(_quest_panel) or not is_instance_valid(_quest_label):
		return
	var s := _viewport_size()
	var mobile := _is_mobile_ui()
	var max_h := clampf(s.y * (0.28 if mobile else 0.34), 118.0, 260.0)
	_quest_panel.size.y = clampf(_quest_label.get_content_height() + 30.0, 68.0, max_h)
	var line_count := max(1, _quest_label.get_parsed_text().split("\n").size())
	var approx_line_h := float(_body_font() + 8)
	_quest_panel.size.y = clampf(maxf(_quest_panel.size.y, line_count * approx_line_h + 34.0), 68.0, max_h)
	_quest_label.scroll_active = _quest_label.get_content_height() + 30.0 > max_h


# ---------------------------------------------------------------------------
# Interaction prompt
# ---------------------------------------------------------------------------
func _on_interaction_available(_id: String, prompt: String) -> void:
	if DialogueManager.is_active():
		return
	var prefix := "点「互动」  " if _is_mobile_ui() else "[E]  "
	_prompt_label.text = prefix + LocaleManager.zh_or_mixed(prompt)
	_prompt_label.visible = true


func _on_interaction_unavailable() -> void:
	_hide_prompt()


func _hide_prompt() -> void:
	if is_instance_valid(_prompt_label):
		_prompt_label.visible = false


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------
func _on_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.visible = true
	_toast_timer = 3.0


# ---------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------
func _on_dialogue_node(node: Dictionary) -> void:
	_dialogue_panel.visible = true
	_refresh_mobile_hud_chrome()
	_hide_prompt()
	var spk := String(node.get("speaker", ""))
	var pic := AssetLib.portrait(spk)
	if pic != null and _show_dialogue_portrait():
		_portrait.texture = pic
		_portrait.visible = true
	else:
		_portrait.visible = false
	_speaker_label.text = spk
	_text_label.text = String(node.get("text", ""))
	Settings.speak(String(node.get("text", "")))
	_rebuild_choices()


## One coloured preview row under a choice button: gains, costs and the lasting
## marks (flags / items) the choice will leave on the journey.
func _add_choice_preview(parent: VBoxContainer, choice: Dictionary) -> void:
	var p: Dictionary = DialogueManager.get_choice_preview(choice)
	var gain := String(p.get("gain", ""))
	var cost := String(p.get("cost", ""))
	var marks := String(p.get("marks", ""))
	if gain == "" and cost == "" and marks == "":
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var size := maxi(11, _choice_font() - 4)
	if gain != "":
		var l := Label.new()
		l.text = "▲ " + gain
		l.add_theme_font_size_override("font_size", size)
		l.modulate = Color(0.55, 0.88, 0.55)
		row.add_child(l)
	if cost != "":
		var l2 := Label.new()
		l2.text = "▼ " + cost
		l2.add_theme_font_size_override("font_size", size)
		l2.modulate = Color(0.92, 0.55, 0.5)
		row.add_child(l2)
	if marks != "":
		var l3 := Label.new()
		l3.text = "◆ " + marks
		l3.add_theme_font_size_override("font_size", size)
		l3.modulate = Color(0.6, 0.75, 0.95)
		ResponsiveLayout.apply_text_wrap(l3)
		row.add_child(l3)
	parent.add_child(row)


func _rebuild_choices() -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	_current_choices = DialogueManager.get_available_choices()
	var idx := 1
	for choice in _current_choices:
		# CONSEQUENCE PREVIEW.
		#
		# Choices used to be bare text with one uncoloured string of numbers
		# glued on. A player could not tell a gain from a cost, and could not
		# see the FLAG a choice sets — which is where this game's long-range
		# consequence actually lives (accepting Help in chapter 3 changes what
		# he says; taking the armour changes the Valley). Each choice is now a
		# button plus a coloured preview line: gains green, costs red, lasting
		# marks blue.
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 0)
		var btn := Button.new()
		btn.text = "%d.  %s" % [idx, String(choice.get("text", ""))]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", _choice_font())
		ResponsiveLayout.set_button_wrap(btn)
		if _is_mobile_ui():
			btn.custom_minimum_size = Vector2(0, 56)
		var cid := String(choice.get("id", ""))
		btn.pressed.connect(func(): _pick_choice(cid))
		wrap.add_child(btn)
		_add_choice_preview(wrap, choice)
		_choice_box.add_child(wrap)
		idx += 1
	# If a node has no choices, allow Space/E to continue (auto-end).
	if _current_choices.is_empty():
		var btn := Button.new()
		btn.text = LocaleManager.t("hud.continue", "(Continue)")
		btn.add_theme_font_size_override("font_size", _choice_font())
		ResponsiveLayout.set_button_wrap(btn)
		if _is_mobile_ui():
			btn.custom_minimum_size = Vector2(0, 56)
		btn.pressed.connect(func(): DialogueManager.end_dialogue())
		_choice_box.add_child(btn)


func _pick_choice(choice_id: String) -> void:
	DialogueManager.select_choice(choice_id)


func _on_dialogue_ended(_id: String) -> void:
	_dialogue_panel.visible = false
	_refresh_mobile_hud_chrome()
	for c in _choice_box.get_children():
		c.queue_free()
	_current_choices = []


func _unhandled_key_input(event: InputEvent) -> void:
	# Character panel toggle works any time we are not mid-dialogue.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if not _dialogue_panel.visible:
			_toggle_char_panel()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F3, KEY_F4]:
		_debug_visible = not _debug_visible
		_debug_panel.visible = _debug_visible
		get_viewport().set_input_as_handled()
		return
	if not _dialogue_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var num := -1
		match event.keycode:
			KEY_1: num = 0
			KEY_2: num = 1
			KEY_3: num = 2
			KEY_4: num = 3
		if num >= 0 and num < _current_choices.size():
			_pick_choice(String(_current_choices[num].get("id", "")))
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_SPACE or event.keycode == KEY_E) and _current_choices.is_empty():
			DialogueManager.end_dialogue()
			get_viewport().set_input_as_handled()


func _build_lang_toggle() -> void:
	_lang_btn = Button.new()
	_lang_btn.text = LocaleManager.switch_label()
	_lang_btn.tooltip_text = "切换语言 / Switch language"
	_lang_btn.add_theme_font_size_override("font_size", 14)
	_lang_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lang_btn.position = Vector2(20, -40)
	_lang_btn.pressed.connect(func(): LocaleManager.toggle())
	add_child(_lang_btn)


func _on_locale_changed(_loc: String) -> void:
	if is_instance_valid(_lang_btn):
		_lang_btn.text = LocaleManager.switch_label()
	for lbl in _stat_labels:
		if is_instance_valid(lbl):
			lbl.text = LocaleManager.t(String(lbl.get_meta("i18n_key", "")), String(lbl.get_meta("i18n_fb", "")))
	_refresh_quest()
	if _char_visible:
		_refresh_char_panel()
