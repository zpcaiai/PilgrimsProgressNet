extends CanvasLayer
## ReviewPanel
## Shows the player's flagged scores (anti-cheat queue) and lets them appeal a
## rejected one for human review. Toggle with R. No-op / offline notice when not
## connected.

const FONT_TITLE := 22
const FONT_BODY := 17
const BOARD_NAMES := {
	"fastest_run": LocaleManager.t("lb.board_fastest", "最快通关"), "fewest_falls": LocaleManager.t("lb.board_fewest", "最少倒下"), "devout_score": LocaleManager.t("lb.board_devout", "敬虔之心"),
}
const STATUS_NAMES := {
	"pending": LocaleManager.t("review.st_pending", "待重算"), "approved": LocaleManager.t("review.st_approved", "已通过"), "rejected": LocaleManager.t("review.st_rejected", "已拒绝"), "appealed": LocaleManager.t("review.st_appealed", "申诉中"),
}
const STATUS_COLORS := {
	"pending": Color(0.85, 0.82, 0.5), "approved": Color(0.6, 0.85, 0.6),
	"rejected": Color(0.9, 0.55, 0.55), "appealed": Color(0.6, 0.78, 0.95),
}

var _dim: ColorRect
var _panel: Panel
var _list: VBoxContainer
var _status: Label
var _open: bool = false


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if NetConfig.enabled:
		LeaderboardService.my_reviews_received.connect(_on_reviews)
		LeaderboardService.review_appealed.connect(func(_id, _s):
			_flash(LocaleManager.t("review.submitted", "申诉已提交，等待人工复核。")); _refresh())
	_set_open(false)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.1, 0.98)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 12)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", s)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-330, -240)
	_panel.size = Vector2(660, 480)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = LocaleManager.t("review.title", "成绩复核与申诉")
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	vb.add_child(title)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", FONT_BODY)
	_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vb.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var hint := Label.new()
	hint.text = LocaleManager.t("review.hint", "R 关闭　·　仅被拒绝的成绩可申诉")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	vb.add_child(hint)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if not NetConfig.enabled or not AuthService.is_online:
		_status.text = LocaleManager.t("review.offline", "离线模式 — 联网后可查看成绩复核状态。")
		return
	_status.text = LocaleManager.t("common.loading", "加载中…")
	LeaderboardService.fetch_my_reviews()


func _on_reviews(reviews: Array) -> void:
	if not _open:
		return
	for c in _list.get_children():
		c.queue_free()
	if reviews.is_empty():
		_status.text = LocaleManager.t("review.none", "你没有被标记的成绩，一切清白。")
		return
	_status.text = LocaleManager.t("review.count", "共 %d 条被标记的成绩：") % reviews.size()
	for r in reviews:
		_add_row(r)


func _add_row(r: Dictionary) -> void:
	var row := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.09, 0.13, 0.9)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		ps.set("corner_radius_" + side, 6)
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 8
	ps.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", ps)
	row.custom_minimum_size = Vector2(0, 78)
	_list.add_child(row)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("normal_font_size", FONT_BODY)
	var board_name: String = BOARD_NAMES.get(String(r.get("board", "")), String(r.get("board", "")))
	var st := String(r.get("status", ""))
	var st_name: String = STATUS_NAMES.get(st, st)
	var st_col: Color = STATUS_COLORS.get(st, Color.WHITE)
	info.text = LocaleManager.t("review.row", "[b]%s[/b]　分数 %d　[color=#%s]%s[/color]\n[color=#8890a0]%s[/color]") % [
		board_name, int(r.get("score", 0)), st_col.to_html(false), st_name,
		String(r.get("reason", ""))]
	hb.add_child(info)

	if st == "rejected":
		var btn := Button.new()
		btn.text = LocaleManager.t("review.appeal", "申诉")
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		btn.custom_minimum_size = Vector2(90, 40)
		var rid := String(r.get("id", ""))
		btn.pressed.connect(func(): LeaderboardService.appeal_review(rid, LocaleManager.t("review.request", "请求人工复核")))
		hb.add_child(btn)


func _flash(msg: String) -> void:
	_status.text = msg


func _set_open(v: bool) -> void:
	_open = v
	_dim.visible = v
	_panel.visible = v
	get_tree().paused = v
	if v:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _open and event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_R:
		_set_open(not _open)
		get_viewport().set_input_as_handled()
