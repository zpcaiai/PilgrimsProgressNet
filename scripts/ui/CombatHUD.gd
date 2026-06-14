extends CanvasLayer
class_name CombatHUD
## Minimal combat overlay: Resolve, Promise charges, prayer cooldown, enemy
## count, and the control hints. Reads the PlayerCombat in group "player_combat".

var _resolve_bar: ProgressBar
var _info: RichTextLabel
var _combat = null  # untyped: PlayerCombat accessed dynamically


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
	panel.position = Vector2(-260, -120)
	panel.size = Vector2(520, 100)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vb)

	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Resolve"
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	_resolve_bar = ProgressBar.new()
	_resolve_bar.min_value = 0
	_resolve_bar.max_value = 100
	_resolve_bar.show_percentage = false
	_resolve_bar.custom_minimum_size = Vector2(380, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.5, 0.4)
	fill.set_corner_radius_all(4)
	_resolve_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_resolve_bar)
	vb.add_child(row)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(0, 48)
	vb.add_child(_info)


func _process(_delta: float) -> void:
	if _combat == null or not is_instance_valid(_combat):
		var c := get_tree().get_nodes_in_group("player_combat")
		if c.size() > 0:
			_combat = c[0]
		else:
			return
	_resolve_bar.value = _combat.resolve
	var enemies := get_tree().get_nodes_in_group("enemy").size()
	var cd: float = _combat.prayer_cooldown
	var cd_txt := "ready" if cd <= 0.0 else "%.1fs" % cd
	_info.text = "[b]Promise:[/b] %d   [b]Prayer:[/b] %s   [b]Foes:[/b] %d\n[color=#aaaaaa]J strike  K dodge  L stand firm  U promise  P pray[/color]" % [_combat.promise_charge, cd_txt, enemies]
