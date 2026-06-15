extends CanvasLayer
class_name HUD
## Self-building heads-up display: quest tracker, a small spiritual panel
## (Faith / Hope / Despair / Burden), interaction prompt, dialogue box,
## toast notifications, and a despair "darkness" overlay.

var _darkness_overlay: ColorRect
var _quest_label: RichTextLabel
var _faith_bar: ProgressBar
var _hope_bar: ProgressBar
var _despair_bar: ProgressBar
var _weariness_bar: ProgressBar
var _load_label: Label
var _burden_label: Label
var _prompt_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0
var _stat_labels: Array = []
var _lang_btn: Button

# Dialogue
var _dialogue_panel: Panel
var _portrait: TextureRect
var _speaker_label: Label
var _text_label: RichTextLabel
var _choice_box: VBoxContainer
var _current_choices: Array = []

# Grace / glory animation overlay (optional flipbook)
var _grace_anim: AnimatedSprite2D

const FONT_TITLE := 22
const FONT_BODY := 18

# Title card
var _title_card: Control
var _title_bg: TextureRect
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
	_connect_signals()
	_build_lang_toggle()
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


func _build_darkness() -> void:
	_darkness_overlay = ColorRect.new()
	_darkness_overlay.color = Color(0.02, 0.0, 0.05, 0.0)
	_darkness_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darkness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_darkness_overlay)


func _build_quest_tracker() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.09, 0.65)))
	panel.position = Vector2(20, 20)
	panel.size = Vector2(330, 90)
	add_child(panel)
	_quest_label = RichTextLabel.new()
	_quest_label.bbcode_enabled = true
	_quest_label.fit_content = true
	_quest_label.scroll_active = false
	_quest_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	panel.add_child(_quest_label)


func _build_spiritual_panel() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.09, 0.65)))
	panel.size = Vector2(240, 150)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-260, 20)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	_faith_bar = _add_stat_row(vb, "hud.faith", "Faith", Color(0.95, 0.85, 0.4))
	_hope_bar = _add_stat_row(vb, "hud.hope", "Hope", Color(0.45, 0.8, 0.95))
	_despair_bar = _add_stat_row(vb, "hud.despair", "Despair", Color(0.55, 0.35, 0.6))
	_weariness_bar = _add_stat_row(vb, "hud.weariness", "Weariness", Color(0.6, 0.55, 0.4))

	_burden_label = Label.new()
	_burden_label.add_theme_font_size_override("font_size", FONT_BODY)
	_burden_label.text = LocaleManager.t("hud.burden_carried", "Burden: carried")
	_burden_label.modulate = Color(0.85, 0.7, 0.6)
	vb.add_child(_burden_label)

	_load_label = Label.new()
	_load_label.add_theme_font_size_override("font_size", FONT_BODY)
	_load_label.modulate = Color(0.8, 0.8, 0.88)
	vb.add_child(_load_label)


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
	_toast_label.visible = false
	add_child(_toast_label)


func _build_dialogue() -> void:
	_dialogue_panel = Panel.new()
	_dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.08, 0.92)))
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialogue_panel.position = Vector2(120, -260)
	_dialogue_panel.size = Vector2(1040, 230)
	_dialogue_panel.visible = false
	add_child(_dialogue_panel)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 16)
	_dialogue_panel.add_child(hb)

	# Optional speaker portrait (hidden when no art exists for the speaker).
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(168, 168)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	hb.add_child(_portrait)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	hb.add_child(vb)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_speaker_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vb.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 60)
	_text_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	vb.add_child(_choice_box)


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-300, -80)
	center.size = Vector2(600, 160)
	_title_card.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	_title_main = Label.new()
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_main.add_theme_font_size_override("font_size", 40)
	_title_main.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	_title_main.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_main.add_theme_constant_override("outline_size", 8)
	vb.add_child(_title_main)
	_title_sub = Label.new()
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub.add_theme_font_size_override("font_size", 22)
	_title_sub.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	_title_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_sub.add_theme_constant_override("outline_size", 6)
	vb.add_child(_title_sub)


func _on_chapter_started(chapter_id: String) -> void:
	var data := ChapterManager.load_chapter_data(chapter_id)
	var art := AssetLib.scene_art(chapter_id)
	_title_bg.texture = art
	_title_bg.visible = art != null
	_title_main.text = String(data.get("title", chapter_id))
	var mech := String(data.get("core_mechanic", ""))
	if mech != "":
		get_tree().create_timer(7.5).timeout.connect(func(): EventBus.toast("✦ " + mech.left(140)))
	_title_sub.text = String(data.get("subtitle", ""))
	var tw := create_tween()
	tw.tween_property(_title_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(_title_card, "modulate:a", 0.0, 1.0)
	# Queue the chapter's reflective opening narration after the title card.
	var intro: Array = data.get("intro", [])
	if not intro.is_empty():
		_pending_intro = intro.duplicate()
		_intro_delay = 3.4


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
	_grace_anim.position = get_viewport().get_visible_rect().size * 0.5
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
	var sb := _panel_style(Color(0.03, 0.03, 0.06, 0.0))  # transparent bg, text only
	_narration_panel.add_theme_stylebox_override("panel", sb)
	_narration_panel.set_anchors_preset(Control.PRESET_CENTER)
	_narration_panel.position = Vector2(-420, 40)
	_narration_panel.size = Vector2(840, 90)
	_narration_panel.modulate = Color(1, 1, 1, 0)
	_narration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_narration_panel)
	_narration_label = RichTextLabel.new()
	_narration_label.bbcode_enabled = true
	_narration_label.fit_content = true
	_narration_label.scroll_active = false
	_narration_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration_label.add_theme_font_size_override("normal_font_size", 21)
	_narration_label.add_theme_color_override("default_color", Color(0.93, 0.91, 0.8))
	_narration_panel.add_child(_narration_label)


func play_narration(lines: Array) -> void:
	if lines.is_empty():
		return
	_narration_queue = lines.duplicate()
	_narration_index = 0
	_narration_phase = 1
	_narration_timer = 0.0
	_show_narration_line()


func _show_narration_line() -> void:
	var line := String(_narration_queue[_narration_index])
	_narration_label.text = "[center][i]" + line + "[/i][/center]"


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
	_char_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_char_panel.add_child(_char_label)


func _toggle_char_panel() -> void:
	_char_visible = not _char_visible
	_char_panel.visible = _char_visible
	if _char_visible:
		_refresh_char_panel()


func _refresh_char_panel() -> void:
	var s := SpiritualStateManager
	var mode_label := LocaleManager.t("char.mode_child", "Children's Journey") if GameState.is_child_mode() else LocaleManager.t("char.mode_devout", "Devout Journey")
	var t := "[b]" + LocaleManager.t("char.title", "The Pilgrim's Heart") + "[/b]   [color=#888888]" + LocaleManager.t("char.close_hint", "(C to close)") + "[/color]\n"
	t += "[color=#9aa6c0]" + mode_label + "[/color]\n\n"
	t += "[color=#f0e0a0]" + LocaleManager.t("char.graces", "Graces") + "[/color]\n"
	t += "  %s %d   %s %d   %s %d\n" % [LocaleManager.t("hud.faith","Faith"), s.faith, LocaleManager.t("hud.hope","Hope"), s.hope, LocaleManager.t("hud.humility","Humility"), s.humility]
	t += "  %s %d   %s %d   %s %d\n\n" % [LocaleManager.t("hud.discernment","Discernment"), s.discernment, LocaleManager.t("hud.perseverance","Perseverance"), s.perseverance, LocaleManager.t("hud.watchfulness","Watchfulness"), s.watchfulness]
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
	t += "[color=#a0f0c0]" + LocaleManager.t("char.companions", "Companions") + "[/color]\n"
	var comps: Array = GameState.companions.keys()
	t += "  " + (", ".join(PackedStringArray(comps)) if not comps.is_empty() else LocaleManager.t("char.walking_alone", "walking alone")) + "\n"
	_char_label.text = t


# ---------------------------------------------------------------------------
# Process: live bars + darkness + toast countdown
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_instance_valid(_faith_bar):
		_faith_bar.value = SpiritualStateManager.faith
		_hope_bar.value = SpiritualStateManager.hope
		_despair_bar.value = SpiritualStateManager.despair
		_weariness_bar.value = SpiritualStateManager.weariness
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

	_process_narration(delta)


# ---------------------------------------------------------------------------
# Quest tracker
# ---------------------------------------------------------------------------
func _refresh_quest() -> void:
	if not is_instance_valid(_quest_label):
		return
	var quest := QuestManager.get_primary_active_quest()
	if quest.is_empty():
		_quest_label.text = "[color=#aaaaaa]" + LocaleManager.t("hud.quest_quiet", "The road is quiet.") + "[/color]"
		return
	var qid := String(quest.get("id", ""))
	var step := QuestManager.get_next_incomplete_step_text(qid)
	var t := "[b]%s[/b]\n[color=#cfcfe0]%s[/color]" % [String(quest.get("title", "")), step]
	_quest_label.text = t


# ---------------------------------------------------------------------------
# Interaction prompt
# ---------------------------------------------------------------------------
func _on_interaction_available(_id: String, prompt: String) -> void:
	if DialogueManager.is_active():
		return
	_prompt_label.text = "[E]  " + prompt
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
	_hide_prompt()
	var spk := String(node.get("speaker", ""))
	var pic := AssetLib.portrait(spk)
	if pic != null:
		_portrait.texture = pic
		_portrait.visible = true
	else:
		_portrait.visible = false
	_speaker_label.text = spk
	_text_label.text = String(node.get("text", ""))
	_rebuild_choices()


func _rebuild_choices() -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	_current_choices = DialogueManager.get_available_choices()
	var idx := 1
	for choice in _current_choices:
		var btn := Button.new()
		var hint := DialogueManager.get_choice_effect_hint(choice)
		btn.text = "%d.  %s%s" % [idx, String(choice.get("text", "")), ("    〔" + hint + "〕" if hint != "" else "")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		var cid := String(choice.get("id", ""))
		btn.pressed.connect(func(): _pick_choice(cid))
		_choice_box.add_child(btn)
		idx += 1
	# If a node has no choices, allow Space/E to continue (auto-end).
	if _current_choices.is_empty():
		var btn := Button.new()
		btn.text = LocaleManager.t("hud.continue", "(Continue)")
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		btn.pressed.connect(func(): DialogueManager.end_dialogue())
		_choice_box.add_child(btn)


func _pick_choice(choice_id: String) -> void:
	DialogueManager.select_choice(choice_id)


func _on_dialogue_ended(_id: String) -> void:
	_dialogue_panel.visible = false
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
