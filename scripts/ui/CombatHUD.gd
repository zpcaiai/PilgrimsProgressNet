extends CanvasLayer
class_name CombatHUD
## Minimal combat overlay: Resolve, Promise charges, prayer cooldown, enemy
## count, and the control hints. Reads the PlayerCombat in group "player_combat".
##
## The Resolve bar is colour-coded (green -> amber -> red) and, when resolve runs
## low, a big pulsing warning appears and the U (promise) / P (pray) keys light
## up so the player knows exactly how to recover before collapse.

const LOW_PCT := 0.38   # below this, warn and highlight recovery keys

var _resolve_bar: ProgressBar
var _fill: StyleBoxFlat
var _info: RichTextLabel
var _warn: Label
var _keys: RichTextLabel
var _boss_panel: Panel
var _boss_bar: ProgressBar
var _boss_fill: StyleBoxFlat
var _boss_lbl: Label
var _combat = null  # untyped: PlayerCombat accessed dynamically
var _t := 0.0


func _ready() -> void:
	layer = 11
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.7)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-280, -132)
	panel.size = Vector2(560, 116)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vb)

	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = LocaleManager.t("combat.resolve", "Resolve")
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	_resolve_bar = ProgressBar.new()
	_resolve_bar.min_value = 0
	_resolve_bar.max_value = 100
	_resolve_bar.show_percentage = false
	_resolve_bar.custom_minimum_size = Vector2(400, 20)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = Color(0.5, 0.8, 0.45)
	_fill.set_corner_radius_all(4)
	_resolve_bar.add_theme_stylebox_override("fill", _fill)
	row.add_child(_resolve_bar)
	vb.add_child(row)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(0, 44)
	vb.add_child(_info)

	# Pulsing recovery-key hint line (only while resolve is low).
	_keys = RichTextLabel.new()
	_keys.bbcode_enabled = true
	_keys.fit_content = true
	_keys.scroll_active = false
	_keys.custom_minimum_size = Vector2(0, 24)
	vb.add_child(_keys)

	# Big warning headline above the panel.
	_warn = Label.new()
	_warn.add_theme_font_size_override("font_size", 30)
	_warn.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	_warn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_warn.add_theme_constant_override("outline_size", 6)
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_warn.position = Vector2(-320, -178)
	_warn.size = Vector2(640, 40)
	_warn.text = LocaleManager.t("combat.resolve_warning",
		"⚠ 定力将尽 — 快按 U 应许 / P 祷告!  (Resolve failing — press U / P!)")
	_warn.visible = false
	add_child(_warn)

	# Boss "claim" bar (top-centre): the foe's influence, breaking as you answer
	# with promise, prayer and a firm stand. Shown only while a boss-tier foe lives.
	_boss_panel = Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.06, 0.03, 0.04, 0.72)
	bsb.set_corner_radius_all(8)
	bsb.content_margin_left = 14
	bsb.content_margin_right = 14
	bsb.content_margin_top = 8
	bsb.content_margin_bottom = 8
	_boss_panel.add_theme_stylebox_override("panel", bsb)
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-260, 18)
	_boss_panel.size = Vector2(520, 58)
	_boss_panel.visible = false
	add_child(_boss_panel)
	var bvb := VBoxContainer.new()
	bvb.set_anchors_preset(Control.PRESET_FULL_RECT)
	bvb.add_theme_constant_override("separation", 2)
	_boss_panel.add_child(bvb)
	_boss_lbl = Label.new()
	_boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.78))
	bvb.add_child(_boss_lbl)
	_boss_bar = ProgressBar.new()
	_boss_bar.min_value = 0
	_boss_bar.max_value = 100
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(492, 16)
	_boss_fill = StyleBoxFlat.new()
	_boss_fill.bg_color = Color(0.78, 0.16, 0.16) if not Settings.colorblind else Color(0.84, 0.37, 0.0)
	_boss_fill.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("fill", _boss_fill)
	bvb.add_child(_boss_bar)


func _strongest_foe():
	var best = null
	var best_mi := 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not is_instance_valid(e):
			continue
		var mi: float = float(e.get("max_influence")) if e.get("max_influence") != null else 0.0
		if mi > best_mi:
			best_mi = mi
			best = e
	return best


func _process(delta: float) -> void:
	_t += delta
	if _combat == null or not is_instance_valid(_combat):
		var c := get_tree().get_nodes_in_group("player_combat")
		if c.size() > 0:
			_combat = c[0]
		else:
			return
	var maxr: float = max(1.0, float(_combat.max_resolve))
	_resolve_bar.max_value = maxr
	_resolve_bar.value = _combat.resolve
	var pct: float = float(_combat.resolve) / maxr

	# Colour-code the bar. Default green->amber->red; colour-blind-safe uses the
	# Okabe-Ito blue->orange->vermillion ramp (distinguishable for most CVD).
	if pct > 0.5:
		_fill.bg_color = Color(0.0, 0.45, 0.7) if Settings.colorblind else Color(0.45, 0.8, 0.45)
	elif pct > LOW_PCT:
		_fill.bg_color = Color(0.9, 0.6, 0.0) if Settings.colorblind else Color(0.95, 0.75, 0.3)
	else:
		_fill.bg_color = Color(0.84, 0.37, 0.0) if Settings.colorblind else Color(0.95, 0.3, 0.28)

	var enemies := get_tree().get_nodes_in_group("enemy").size()
	var cd: float = _combat.prayer_cooldown
	var cd_txt := "就绪" if cd <= 0.0 else "%.1fs" % cd
	var touch_hint := "移动版：点「攻击 / 闪避 / 站稳 / 应许 / 祷告」"
	var hud_template := LocaleManager.t("combat.hud", "[b]Promise:[/b] %d   [b]Prayer:[/b] %s   [b]Foes:[/b] %d\n[color=#aaaaaa]J strike  K dodge  L stand firm  U promise  P pray[/color]")
	var hud_args := [_combat.promise_charge, cd_txt, enemies] if LocaleManager.is_zh() else [_combat.promise_charge, cd_txt, enemies, _combat.promise_charge, cd_txt, enemies]
	_info.text = hud_template % hud_args
	if DisplayServer.is_touchscreen_available():
		_info.text += "\n[color=#aaaaaa]" + touch_hint + "[/color]"

	# When low, pulse the warning and highlight whichever recovery is available.
	var low := pct <= LOW_PCT
	_warn.visible = low
	if low:
		_warn.modulate = Color(1, 1, 1, 0.55 + 0.45 * sin(_t * 6.0))
		var promise_ready: bool = _combat.promise_charge > 0
		var prayer_ready: bool = cd <= 0.0
		var parts: Array = []
		if promise_ready:
			parts.append("[pulse freq=3.0 color=#ffe66d][b]► U 应许 Promise[/b][/pulse]")
		if prayer_ready:
			parts.append("[pulse freq=3.0 color=#ffe66d][b]► P 祷告 Pray[/b][/pulse]")
		if parts.is_empty():
			parts.append("[color=#cccccc]L 站稳 / K 闪避 — 撑住,应许与祷告即将就绪[/color]")
		_keys.text = "   ".join(parts)
	else:
		_keys.text = ""

	# Boss "claim" bar — visible only while a boss-tier foe (large influence) lives,
	# so the player can see Apollyon's hold on them breaking with every answer.
	var foe = _strongest_foe()
	if foe != null and float(foe.get("max_influence")) >= 75.0:
		var mi: float = max(1.0, float(foe.get("max_influence")))
		_boss_panel.visible = true
		_boss_bar.max_value = mi
		_boss_bar.value = clampf(float(foe.get("influence")), 0.0, mi)
		var nm: String = String(foe.get("display_name")) if foe.get("display_name") != null else "Apollyon"
		var claim_template := LocaleManager.t("combat.boss_claim", "%s 的控告 — 站立得住直到它破碎  (%s's claim — stand until it breaks)")
		_boss_lbl.text = (claim_template % [nm]) if LocaleManager.is_zh() else (claim_template % [nm, nm, nm])
	else:
		_boss_panel.visible = false
