extends CanvasLayer
## ConversationPanel
## A standalone private-message window (toggle Y): left = list of DM
## conversations (peer + last message + unread); right = the selected thread's
## full history, with a reply box. Reading a thread clears its unread. History
## comes from GET /chat/{threads,history}; replies go out via RealtimeService.
## No-op / offline notice when networking is off.

const FONT_BODY := 16

var _dim: ColorRect
var _panel: Panel
var _thread_list: VBoxContainer
var _history_box: VBoxContainer
var _history_scroll: ScrollContainer
var _title: Label
var _reply: LineEdit
var _search: LineEdit
var _open: bool = false
var _active_peer: String = ""
var _active_name: String = ""
var _threads: Array = []   # cached thread data for client-side search
var _rows_by_mid: Dictionary = {}
var _read_label: Label
var _my_last_ts: int = 0


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if NetConfig.enabled and NetConfig.realtime:
		RealtimeService.chat_received.connect(_on_chat)
		RealtimeService.chat_deleted.connect(_on_chat_deleted)
		RealtimeService.dm_read.connect(_on_dm_read)
	_set_open(false)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _bg(Color(0.06, 0.06, 0.1, 0.99)))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-440, -260)
	_panel.size = Vector2(880, 520)
	add_child(_panel)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	_panel.add_child(root)

	# Left: thread list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	var lh := Label.new()
	lh.text = "私聊会话"
	lh.add_theme_font_size_override("font_size", 20)
	lh.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	left.add_child(lh)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索昵称…"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 14)
	_search.text_changed.connect(func(_t): _render_threads())
	left.add_child(_search)
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(0, 430)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(lscroll)
	_thread_list = VBoxContainer.new()
	_thread_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread_list.add_theme_constant_override("separation", 4)
	lscroll.add_child(_thread_list)

	# Right: history + reply
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	_title = Label.new()
	_title.text = "选择左侧的会话"
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	right.add_child(_title)
	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(0, 400)
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_history_scroll)
	_history_box = VBoxContainer.new()
	_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_box.add_theme_constant_override("separation", 3)
	_history_scroll.add_child(_history_box)

	_read_label = Label.new()
	_read_label.text = ""
	_read_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_read_label.add_theme_font_size_override("font_size", 12)
	_read_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.6))
	right.add_child(_read_label)

	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	right.add_child(rrow)
	_reply = LineEdit.new()
	_reply.max_length = 200
	_reply.placeholder_text = "回复…（Enter 发送）"
	_reply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reply.add_theme_font_size_override("font_size", FONT_BODY)
	_reply.text_submitted.connect(func(_t): _send_reply())
	rrow.add_child(_reply)
	var close := Button.new()
	close.text = "关闭 (Y)"
	close.pressed.connect(func(): _set_open(false))
	rrow.add_child(close)


func _bg(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 12)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _refresh_threads() -> void:
	if not (NetConfig.enabled and AuthService.is_online):
		for c in _thread_list.get_children():
			c.queue_free()
		_title.text = "离线模式 — 联网后可查看私聊。"
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/chat/threads")
	if res.ok and res.data is Array:
		_threads = res.data
	_render_threads()


func _render_threads() -> void:
	for c in _thread_list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower() if _search else ""
	var shown := 0
	for t in _threads:
		if not (t is Dictionary):
			continue
		if q != "" and not String(t.get("peer_name", "")).to_lower().contains(q):
			continue
		_add_thread_button(t)
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "没有匹配的会话。" if q != "" else "还没有私聊会话。"
		none.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		_thread_list.add_child(none)


func _add_thread_button(t: Dictionary) -> void:
	var pid := String(t.get("peer_id", ""))
	var pname := String(t.get("peer_name", "朝圣者"))
	var pinned := bool(t.get("pinned", false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_thread_list.add_child(row)

	var pin := Button.new()
	pin.text = "★" if pinned else "☆"
	pin.tooltip_text = "取消置顶" if pinned else "置顶"
	pin.custom_minimum_size = Vector2(34, 48)
	pin.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4) if pinned else Color(0.6, 0.62, 0.7))
	pin.pressed.connect(func(): _toggle_pin(pid, not pinned))
	row.add_child(pin)

	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unread := int(t.get("unread", 0))
	var badge := "  [%d]" % unread if unread > 0 else ""
	btn.text = "%s%s\n%s" % [pname, badge, String(t.get("last_text", "")).left(20)]
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): _open_thread(pid, pname))
	row.add_child(btn)


func _toggle_pin(peer_id: String, pinned: bool) -> void:
	await ApiClient.request_json("POST", "/chat/pin", {"peer_id": peer_id, "pinned": pinned})
	_refresh_threads()


func _open_thread(peer_id: String, peer_name: String) -> void:
	_active_peer = peer_id
	_active_name = peer_name
	_title.text = "与 %s 的私聊" % peer_name
	_read_label.text = ""
	_my_last_ts = 0
	_rows_by_mid.clear()
	for c in _history_box.get_children():
		c.queue_free()
	var res: Dictionary = await ApiClient.request_json(
		"GET", "/chat/history?scope=dm&to=%s" % peer_id)
	if res.ok and res.data is Array:
		for m in res.data:
			if m is Dictionary:
				_add_history_line(m)
	# Reading clears the unread for this peer.
	await ApiClient.request_json("POST", "/chat/read", {"peer_id": peer_id})
	_refresh_threads()
	# Has the peer already read my latest message?
	var st: Dictionary = await ApiClient.request_json("GET", "/chat/read-state?peer=%s" % peer_id)
	if st.ok and st.data is Dictionary:
		_apply_read_state(int((st.data as Dictionary).get("read_ts", 0)))


func _apply_read_state(read_ts: int) -> void:
	if _my_last_ts > 0 and read_ts >= _my_last_ts:
		_read_label.text = "对方已读"
	else:
		_read_label.text = ""


func _on_dm_read(reader_id: String, ts: int) -> void:
	if _open and reader_id == _active_peer:
		_apply_read_state(ts)


func _add_history_line(m: Dictionary) -> void:
	var mine := String(m.get("id", "")) == AuthService.player_id
	if mine:
		_my_last_ts = max(_my_last_ts, int(m.get("ts", 0)))
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 14)
	if bool(m.get("deleted", false)):
		lbl.text = "[color=#7a8090][i]此消息已撤回[/i][/color]"
	else:
		var col := "#9fe0c0" if mine else "#cfd6ea"
		var body := String(m.get("text", ""))
		if String(m.get("image_url", "")) != "":
			body += "  [图片]"
		var quote := ""
		var rp := String(m.get("reply_preview", ""))
		if rp != "":
			quote = "[color=#6b7790]┃ %s[/color]\n" % _safe(rp)
		lbl.text = "%s[color=%s]%s[/color]：%s" % [quote, col, _safe(String(m.get("name", "朝圣者"))), _safe(body)]
	_history_box.add_child(lbl)
	var mid := String(m.get("mid", ""))
	if mid != "":
		_rows_by_mid[mid] = lbl
	await get_tree().process_frame
	_history_scroll.scroll_vertical = int(_history_scroll.get_v_scroll_bar().max_value)


func _on_chat_deleted(mid: String) -> void:
	var node: Control = _rows_by_mid.get(mid)
	if node != null and is_instance_valid(node) and node is RichTextLabel:
		(node as RichTextLabel).text = "[color=#7a8090][i]此消息已撤回[/i][/color]"


func _send_reply() -> void:
	var t := _reply.text.strip_edges()
	if t == "" or _active_peer == "":
		return
	RealtimeService.send_chat(t, "dm", _active_peer)
	_reply.text = ""


func _on_chat(msg: Dictionary) -> void:
	# Live-append messages for the open thread; otherwise just refresh the list.
	if not _open:
		return
	if String(msg.get("channel", "")) == "dm":
		var other := String(msg.get("id", ""))
		var to := String(msg.get("to", ""))
		var involves := other == _active_peer or to == _active_peer \
			or (other == AuthService.player_id and to == _active_peer)
		if _active_peer != "" and involves:
			_add_history_line(msg)
			# My new outgoing message is unread by the peer again.
			if String(msg.get("id", "")) == AuthService.player_id:
				_read_label.text = ""
		_refresh_threads()


func _safe(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")


func _set_open(v: bool) -> void:
	_open = v
	_dim.visible = v
	_panel.visible = v
	get_tree().paused = v
	if v:
		_refresh_threads()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not (NetConfig.enabled and NetConfig.realtime):
		return
	if _open and event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_Y:
		_set_open(not _open)
		get_viewport().set_input_as_handled()
