extends CanvasLayer
## RewardPopup
## On login, checks for season rewards the player hasn't seen yet and shows a
## celebratory popup, then acknowledges them so they won't show again.
## No-op when offline.

var TOKEN_NAMES := {
	"crown_of_life": LocaleManager.t("reward.crown", "生命冠冕"),
	"palm_branch": LocaleManager.t("reward.palm", "棕榈枝"),
	"pilgrims_staff": LocaleManager.t("reward.staff", "朝圣杖"),
}
var BOARD_NAMES := {
	"fastest_run": LocaleManager.t("lb.board_fastest", "最快通关"),
	"fewest_falls": LocaleManager.t("lb.board_fewest", "最少倒下"),
	"devout_score": LocaleManager.t("lb.board_devout", "敬虔之心"),
}

var _dim: ColorRect
var _panel: Panel
var _body: RichTextLabel


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_visible(false)
	if NetConfig.enabled:
		AuthService.authenticated.connect(func(_id, _n): _check())
		LeaderboardService.unseen_rewards_received.connect(_on_unseen)
		# If already authenticated by the time we load, check once.
		if AuthService.is_online:
			call_deferred("_check")


func _check() -> void:
	if AuthService.is_online:
		LeaderboardService.fetch_unseen_rewards()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.04, 0.99)
	s.border_color = Color(0.85, 0.72, 0.35)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 14)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", s)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-300, -180)
	_panel.size = Vector2(600, 360)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 16)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = LocaleManager.t("reward.title", "赛季嘉奖")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	vb.add_child(title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 200)
	_body.add_theme_font_size_override("normal_font_size", 19)
	vb.add_child(_body)

	var btn := Button.new()
	btn.text = LocaleManager.t("reward.accept", "感谢，收下")
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(0, 46)
	btn.pressed.connect(_dismiss)
	vb.add_child(btn)


func _on_unseen(rewards: Array) -> void:
	if rewards.is_empty():
		return
	var lines: Array = [LocaleManager.t("reward.l1", "[center]你在上个赛季的征途中名列前茅，[/center]"),
		LocaleManager.t("reward.l2", "[center]这些恩典之记号赐予你：[/center]\n")]
	for r in rewards:
		var token := String(r.get("token", ""))
		var token_name: String = TOKEN_NAMES.get(token, token)
		var board_name: String = BOARD_NAMES.get(String(r.get("board", "")), String(r.get("board", "")))
		var diff := LocaleManager.t("lb.child", "童趣") if String(r.get("difficulty", "")) == "child" else LocaleManager.t("lb.devout", "敬虔")
		lines.append(LocaleManager.t("reward.cite", "[center][color=#f0e0a0]%s[/color]　— %s · %s · 第 %d 名（%s）[/center]") % [
			token_name, String(r.get("season", "")), board_name, int(r.get("rank", 0)), diff])
	_body.text = "\n".join(PackedStringArray(lines))
	_set_visible(true)
	get_tree().paused = true


func _dismiss() -> void:
	LeaderboardService.ack_rewards()
	get_tree().paused = false
	_set_visible(false)


func _set_visible(v: bool) -> void:
	_dim.visible = v
	_panel.visible = v
