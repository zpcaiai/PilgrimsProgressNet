extends CanvasLayer
## LeaderboardPanel
## Self-building leaderboard overlay. Toggle with B. Shows the three boards
## (fastest run / fewest falls / devout score) for the current difficulty,
## with the player's own rank highlighted.
##
## Add to a scene, or autoload it. Reads data via LeaderboardService, which is
## a no-op when networking is disabled — in that case this panel shows an
## "offline" notice instead of erroring.

const BOARDS := [
	{"id": "fastest_run", "title": "最快通关"},
	{"id": "fewest_falls", "title": "最少倒下"},
	{"id": "devout_score", "title": "敬虔之心"},
]
const FONT_TITLE := 24
const FONT_BODY := 18

var _panel: Panel
var _tabs: HBoxContainer
var _season_tabs: HBoxContainer
var _list: VBoxContainer
var _status: Label
var _visible: bool = false
var _active_board: String = "devout_score"
var _active_season: String = "current"   # "current" or "all"
var _season_label: String = ""


func _ready() -> void:
	layer = 11
	_build()
	if NetConfig.enabled:
		LeaderboardService.board_received.connect(_on_board_received)
		LeaderboardService.season_received.connect(_on_season_received)
	_panel.visible = false


func _build() -> void:
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.09, 0.95)))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-300, -240)
	_panel.size = Vector2(600, 480)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var header := Label.new()
	header.text = "天路榜  ·  Pilgrim Boards"
	header.add_theme_font_size_override("font_size", FONT_TITLE)
	header.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	vb.add_child(header)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	vb.add_child(_tabs)
	for b in BOARDS:
		var btn := Button.new()
		btn.text = String(b.title)
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		var bid := String(b.id)
		btn.pressed.connect(func(): _select(bid))
		_tabs.add_child(btn)

	_season_tabs = HBoxContainer.new()
	_season_tabs.add_theme_constant_override("separation", 8)
	vb.add_child(_season_tabs)
	for s in [{"id": "current", "title": "本赛季"}, {"id": "all", "title": "历史总榜"}]:
		var sbtn := Button.new()
		sbtn.text = String(s.title)
		sbtn.toggle_mode = true
		sbtn.button_pressed = (String(s.id) == _active_season)
		sbtn.add_theme_font_size_override("font_size", FONT_BODY)
		var sid := String(s.id)
		sbtn.pressed.connect(func(): _select_season(sid))
		_season_tabs.add_child(sbtn)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", FONT_BODY)
	_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vb.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var hint := Label.new()
	hint.text = "B 关闭"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	vb.add_child(hint)


func _select(board: String) -> void:
	_active_board = board
	_refresh()


func _select_season(season: String) -> void:
	_active_season = season
	# Keep the toggle buttons mutually exclusive.
	for i in _season_tabs.get_child_count():
		var btn := _season_tabs.get_child(i) as Button
		if btn:
			btn.button_pressed = (i == (0 if season == "current" else 1))
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if not NetConfig.enabled or not AuthService.is_online:
		_status.text = "离线模式 — 联网后可查看天路榜。"
		return
	_status.text = "加载中…  （难度：%s）" % _difficulty_label()
	if _active_season == "current":
		LeaderboardService.fetch_current_season()
	LeaderboardService.fetch(_active_board, "", _active_season)


func _on_season_received(season: String, _start: String, _end: String) -> void:
	_season_label = season


func _on_board_received(board: String, rows: Array, my_rank: int) -> void:
	if board != _active_board or not _visible:
		return
	for c in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		_status.text = "还没有人上榜，去成为第一位吧。"
		return
	var season_txt := ("本赛季 " + _season_label) if _active_season == "current" else "历史总榜"
	_status.text = "%s    难度：%s    我的排名：%s" % [
		season_txt, _difficulty_label(), ("#%d" % my_rank) if my_rank > 0 else "未上榜"]
	for row in rows:
		_add_row(int(row.get("rank", 0)), String(row.get("display_name", "朝圣者")),
			int(row.get("score", 0)), int(row.get("rank", 0)) == my_rank)


func _add_row(rank: int, name: String, score: int, mine: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var rank_lbl := Label.new()
	rank_lbl.text = "%d" % rank
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	var score_lbl := Label.new()
	score_lbl.text = str(score)
	score_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	var col := Color(0.97, 0.92, 0.6) if mine else Color(0.85, 0.88, 0.95)
	for l in [rank_lbl, name_lbl, score_lbl]:
		l.add_theme_color_override("font_color", col)
	hb.add_child(rank_lbl)
	hb.add_child(name_lbl)
	hb.add_child(score_lbl)
	_list.add_child(hb)


func _difficulty_label() -> String:
	return "童趣" if GameState.is_child_mode() else "敬虔"


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		_visible = not _visible
		_panel.visible = _visible
		if _visible:
			_refresh()
		get_viewport().set_input_as_handled()
