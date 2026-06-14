extends CanvasLayer
## AccountPanel
## Account management overlay. Toggle with N. Shows the current (anonymous)
## account, and lets the player BIND an email (so the account can be recovered)
## or RECOVER an account onto this device via an email code.
##
## Flow: enter email -> "发送验证码" -> enter the 6-digit code -> 绑定/找回.
## In dev the server echoes the code; it's shown in the hint for easy testing.
## No-op / shows offline notice when networking is disabled.

const FONT_TITLE := 22
const FONT_BODY := 18

var _dim: ColorRect
var _panel: Panel
var _who: RichTextLabel
var _rewards: RichTextLabel
var _email_edit: LineEdit
var _code_edit: LineEdit
var _hint: Label
var _mode: String = "bind"   # "bind" or "recover"
var _open: bool = false
var _mode_btns: Array = []

const TOKEN_NAMES := {
	"crown_of_life": "生命冠冕",
	"palm_branch": "棕榈枝",
	"pilgrims_staff": "朝圣杖",
}


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if NetConfig.enabled:
		AuthService.authenticated.connect(func(_id, _n): _refresh_identity())
		AuthService.email_code_sent.connect(_on_code_sent)
		AuthService.email_bound.connect(func(e): _flash("邮箱已绑定：" + e); _refresh_identity())
		AuthService.account_recovered.connect(func(_id): _flash("账号已找回，存档随后同步。"); _refresh_identity())
		AuthService.account_error.connect(func(msg): _flash(msg))
		LeaderboardService.rewards_received.connect(_on_rewards)
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
	_panel.position = Vector2(-320, -210)
	_panel.size = Vector2(640, 420)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "我的账号"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	vb.add_child(title)

	_who = RichTextLabel.new()
	_who.bbcode_enabled = true
	_who.fit_content = true
	_who.scroll_active = false
	_who.custom_minimum_size = Vector2(0, 64)
	_who.add_theme_font_size_override("normal_font_size", FONT_BODY)
	vb.add_child(_who)

	_rewards = RichTextLabel.new()
	_rewards.bbcode_enabled = true
	_rewards.fit_content = true
	_rewards.scroll_active = false
	_rewards.custom_minimum_size = Vector2(0, 40)
	_rewards.add_theme_font_size_override("normal_font_size", 16)
	vb.add_child(_rewards)

	# Mode switch: bind vs recover
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	vb.add_child(modes)
	for m in [{"id": "bind", "title": "绑定邮箱"}, {"id": "recover", "title": "找回账号"}]:
		var btn := Button.new()
		btn.text = String(m.title)
		btn.toggle_mode = true
		btn.button_pressed = (String(m.id) == _mode)
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		var mid := String(m.id)
		btn.pressed.connect(func(): _set_mode(mid))
		modes.add_child(btn)
		_mode_btns.append(btn)

	_email_edit = LineEdit.new()
	_email_edit.placeholder_text = "邮箱地址"
	_email_edit.max_length = 255
	_email_edit.custom_minimum_size = Vector2(0, 42)
	_email_edit.add_theme_font_size_override("font_size", FONT_BODY)
	vb.add_child(_email_edit)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	vb.add_child(code_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "6 位验证码"
	_code_edit.max_length = 8
	_code_edit.custom_minimum_size = Vector2(220, 42)
	_code_edit.add_theme_font_size_override("font_size", FONT_BODY)
	code_row.add_child(_code_edit)
	var send_btn := Button.new()
	send_btn.text = "发送验证码"
	send_btn.add_theme_font_size_override("font_size", FONT_BODY)
	send_btn.custom_minimum_size = Vector2(160, 42)
	send_btn.pressed.connect(_send_code)
	code_row.add_child(send_btn)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 12)
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(act_row)
	var confirm := Button.new()
	confirm.text = "确认"
	confirm.add_theme_font_size_override("font_size", FONT_BODY)
	confirm.custom_minimum_size = Vector2(200, 44)
	confirm.pressed.connect(_confirm)
	act_row.add_child(confirm)
	var close := Button.new()
	close.text = "关闭 (N)"
	close.add_theme_font_size_override("font_size", FONT_BODY)
	close.custom_minimum_size = Vector2(140, 44)
	close.pressed.connect(func(): _set_open(false))
	act_row.add_child(close)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.67, 0.78))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(0, 40)
	vb.add_child(_hint)


func _set_mode(mode: String) -> void:
	_mode = mode
	for i in _mode_btns.size():
		_mode_btns[i].button_pressed = (i == (0 if mode == "bind" else 1))
	_hint.text = ("绑定邮箱后，可在其它设备用邮箱找回此账号。"
		if mode == "bind" else "在新设备输入已绑定的邮箱，验证后即可把存档找回到本机。")


func _refresh_identity() -> void:
	var name := AuthService.display_name if AuthService.display_name != "" else "（未登录）"
	var mail := AuthService.email if AuthService.email != "" else "未绑定"
	var pid := AuthService.player_id.substr(0, 8) if AuthService.player_id != "" else "—"
	_who.text = "[b]%s[/b]\n[color=#9aa6c0]ID %s…   邮箱：%s[/color]" % [name, pid, mail]
	if AuthService.is_online:
		LeaderboardService.fetch_rewards()


func _on_rewards(rewards: Array) -> void:
	if rewards.is_empty():
		_rewards.text = "[color=#7a8090]赛季奖励：暂无（进入前三可在赛季结算时获得）[/color]"
		return
	var parts: Array = []
	for r in rewards:
		var token := String(r.get("token", ""))
		var token_name: String = TOKEN_NAMES.get(token, token)
		parts.append("[color=#f0e0a0]%s[/color]（%s·第%d名）" % [
			token_name, String(r.get("season", "")), int(r.get("rank", 0))])
	_rewards.text = "赛季奖励：" + "， ".join(PackedStringArray(parts))


func _send_code() -> void:
	var email := _email_edit.text.strip_edges()
	if email == "":
		_flash("请先填写邮箱。")
		return
	AuthService.request_email_code(email, _mode)


func _on_code_sent(dev_code: String) -> void:
	if dev_code != "":
		_flash("验证码已发送（开发模式：%s）。" % dev_code)
		_code_edit.text = dev_code  # convenience in dev
	else:
		_flash("验证码已发送，请查收邮箱。")


func _confirm() -> void:
	var email := _email_edit.text.strip_edges()
	var code := _code_edit.text.strip_edges()
	if email == "" or code == "":
		_flash("请填写邮箱与验证码。")
		return
	if _mode == "bind":
		AuthService.bind_email(email, code)
	else:
		AuthService.recover_account(email, code)


func _flash(msg: String) -> void:
	_hint.text = msg


func _set_open(v: bool) -> void:
	_open = v
	_dim.visible = v
	_panel.visible = v
	get_tree().paused = v
	if v:
		if not NetConfig.enabled or not AuthService.is_online:
			_flash("离线模式：联网后才能绑定 / 找回账号。")
		else:
			_set_mode(_mode)
		_refresh_identity()
		_email_edit.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _open and event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_N:
		_set_open(not _open)
		get_viewport().set_input_as_handled()
