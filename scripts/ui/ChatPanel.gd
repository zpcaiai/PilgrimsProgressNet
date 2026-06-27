extends CanvasLayer
## ChatPanel
## In-game real-time chat over RealtimeService (WebSocket). Channels: 本关
## (chapter) / 世界 (world) / 私聊 (dm to a chosen peer). Supports sending images
## (file picker -> base64 upload -> message references the /media URL). Press T to
## open the input; Enter sends; Esc/T closes. Corner log stays visible; closed-
## panel messages also flash as toasts. No-op when realtime is off.

const FONT_BODY := 16
const MAX_ROWS := 80

var _log_panel: Panel
var _log_scroll: ScrollContainer
var _log_box: VBoxContainer
var _input_row: Panel
var _input: LineEdit
var _channel_btn: OptionButton
var _dm_btn: OptionButton
var _file_dialog: FileDialog
var _open: bool = false

var _channel: String = "chapter"
var _peers: Dictionary = {}   # peer_id -> name (for DM targets)
var _img_http: HTTPRequest
var _room_edit: LineEdit
var _room_box: HBoxContainer
var _current_room: String = ""
var _room_name: String = ""
var _members_popup: PanelContainer
var _members_box: VBoxContainer
var _reply_bar: Panel
var _reply_label: Label
var _reply_to: String = ""
var _reply_preview: String = ""
var _sticker_grid: GridContainer
var _sticker_group_btn: OptionButton
var _sticker_data: Dictionary = {"groups": {LocaleManager.t("chat.default_group", "默认"): []}, "active": LocaleManager.t("chat.default_group", "默认")}
var _builtin_packs: Dictionary = {}
var _builtin_label_to_id: Dictionary = {}
var _muted: bool = false
const STICKER_FILE := "user://chat_stickers.json"
var _badge: Label
var _unread_total: int = 0
var _unread_by_peer: Dictionary = {}   # peer_id -> count
var _mention_re: RegEx
var _ac_popup: PanelContainer          # @-mention autocomplete
var _ac_list: VBoxContainer
var _rows_by_mid: Dictionary = {}      # mid -> the row Control (for recall)
var _avatar_url_cache: Dictionary = {} # player_id -> avatar url
var _avatar_tex_cache: Dictionary = {} # url -> ImageTexture
var _emoji_popup: PanelContainer
var _recent_grid: GridContainer
var _recent_emojis: Array = []

const RECENT_FILE := "user://chat_recent_emoji.json"
const MAX_RECENT := 8

const EMOJIS := ["😀", "😂", "🙏", "😭", "👍", "❤️", "🔥", "✨", "😅", "🤝", "🌟", "💪"]
const QUICK_PHRASES := ["愿你平安", "一路同行", "前面小心", "我先走一步", "稍等我", "感谢相助"]
const RECALL_WINDOW_MS := 120000
var _viewer: Control                    # full-image viewer overlay
var _viewer_rect: TextureRect
var _viewer_zoom: float = 1.0
var _viewer_bytes: PackedByteArray
var _viewer_ext: String = "png"
var _save_dialog: FileDialog
var _pan_active: bool = false
var _pan_moved: bool = false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_mention_re = RegEx.new()
	_mention_re.compile("@([^\\s@：:，,。.!！?？]+)")
	if NetConfig.enabled and NetConfig.realtime:
		RealtimeService.chat_received.connect(_on_chat)
		RealtimeService.chat_history.connect(_on_history)
		RealtimeService.chat_system.connect(func(t): _system(t))
		RealtimeService.chat_deleted.connect(_on_chat_deleted)
		RealtimeService.peer_updated.connect(_on_peer_seen)
		RealtimeService.peer_left.connect(func(pid): _peers.erase(pid))
		RealtimeService.room_members.connect(_on_room_members)
		AuthService.authenticated.connect(func(_id, _n): _refresh_unread(); _refresh_mentions())
		EventBus.chapter_started.connect(func(_c): _clear())
		if AuthService.is_online:
			call_deferred("_refresh_unread")
			call_deferred("_refresh_mentions")
	else:
		_log_panel.visible = false
	_set_input_open(false)


func _build() -> void:
	_log_panel = Panel.new()
	_log_panel.add_theme_stylebox_override("panel", _bg(Color(0.04, 0.05, 0.08, 0.55), 8))
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.position = Vector2(20, -320)
	_log_panel.size = Vector2(440, 230)
	_log_panel.modulate = Color(1, 1, 1, 0.92)
	_log_panel.visible = false
	add_child(_log_panel)
	_log_scroll = ScrollContainer.new()
	_log_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_panel.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 3)
	_log_scroll.add_child(_log_box)

	# Private-message unread red dot (top-right of the log panel).
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.add_theme_color_override("font_color", Color(1, 1, 1))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.85, 0.25, 0.3)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		bs.set("corner_radius_" + side, 9)
	bs.content_margin_left = 7
	bs.content_margin_right = 7
	bs.content_margin_top = 1
	bs.content_margin_bottom = 1
	_badge.add_theme_stylebox_override("normal", bs)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.position = Vector2(-44, 6)
	_badge.visible = false
	_log_panel.add_child(_badge)

	# Reply context bar (shown above the input when quoting a message).
	_reply_bar = Panel.new()
	_reply_bar.add_theme_stylebox_override("panel", _bg(Color(0.10, 0.12, 0.16, 0.97), 6))
	_reply_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_reply_bar.position = Vector2(20, -120)
	_reply_bar.size = Vector2(720, 30)
	_reply_bar.visible = false
	add_child(_reply_bar)
	var rb := HBoxContainer.new()
	rb.set_anchors_preset(Control.PRESET_FULL_RECT)
	rb.add_theme_constant_override("separation", 8)
	_reply_bar.add_child(rb)
	_reply_label = Label.new()
	_reply_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reply_label.add_theme_font_size_override("font_size", 13)
	_reply_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	rb.add_child(_reply_label)
	var rx := Button.new()
	rx.text = "×"
	rx.pressed.connect(_clear_reply)
	_seticon(rx, "close", "×")
	rb.add_child(rx)

	_input_row = Panel.new()
	_input_row.add_theme_stylebox_override("panel", _bg(Color(0.06, 0.07, 0.11, 0.97), 8))
	_input_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_input_row.position = Vector2(20, -84)
	_input_row.size = Vector2(720, 48)
	add_child(_input_row)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 8)
	_input_row.add_child(hb)

	_channel_btn = OptionButton.new()
	_channel_btn.add_item(LocaleManager.t("chat.ch_local", "本关"), 0)
	_channel_btn.add_item(LocaleManager.t("chat.ch_world", "世界"), 1)
	_channel_btn.add_item(LocaleManager.t("chat.ch_dm", "私聊"), 2)
	_channel_btn.add_item(LocaleManager.t("chat.ch_room", "群聊"), 3)
	_channel_btn.item_selected.connect(_on_channel_selected)
	hb.add_child(_channel_btn)

	_dm_btn = OptionButton.new()
	_dm_btn.visible = false
	_dm_btn.item_selected.connect(_on_dm_target_selected)
	hb.add_child(_dm_btn)

	# Group-room controls (visible when channel == "room").
	_room_box = HBoxContainer.new()
	_room_box.add_theme_constant_override("separation", 4)
	_room_box.visible = false
	hb.add_child(_room_box)
	_room_edit = LineEdit.new()
	_room_edit.placeholder_text = LocaleManager.t("chat.room_code", "房间码")
	_room_edit.custom_minimum_size = Vector2(110, 0)
	_room_edit.add_theme_font_size_override("font_size", FONT_BODY)
	_room_box.add_child(_room_edit)
	var join_b := Button.new()
	join_b.text = LocaleManager.t("chat.join_btn", "进")
	join_b.tooltip_text = LocaleManager.t("chat.join_room", "加入房间")
	join_b.pressed.connect(_join_room)
	_room_box.add_child(join_b)
	var new_b := Button.new()
	new_b.text = LocaleManager.t("chat.create_btn", "建")
	new_b.tooltip_text = LocaleManager.t("chat.create_room_tip", "在房间码栏填名字再点建，创建带名群聊")
	new_b.pressed.connect(_create_room)
	_room_box.add_child(new_b)
	var mem_b := Button.new()
	mem_b.text = LocaleManager.t("chat.members", "成员")
	mem_b.pressed.connect(_toggle_members)
	_room_box.add_child(mem_b)

	# Members popup (room name + member list).
	_members_popup = PanelContainer.new()
	_members_popup.add_theme_stylebox_override("panel", _bg(Color(0.08, 0.09, 0.13, 0.99), 8))
	_members_popup.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_members_popup.position = Vector2(360, -260)
	_members_popup.visible = false
	add_child(_members_popup)
	_members_box = VBoxContainer.new()
	_members_box.add_theme_constant_override("separation", 3)
	_members_popup.add_child(_members_box)

	_input = LineEdit.new()
	_input.max_length = 200
	_input.placeholder_text = LocaleManager.t("chat.input_ph", "说点什么…（Enter 发送）")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", FONT_BODY)
	_input.text_submitted.connect(_on_submit)
	_input.text_changed.connect(_on_input_changed)
	hb.add_child(_input)

	# @-mention autocomplete popup (floats above the input row).
	_ac_popup = PanelContainer.new()
	_ac_popup.add_theme_stylebox_override("panel", _bg(Color(0.08, 0.09, 0.13, 0.99), 8))
	_ac_popup.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_ac_popup.position = Vector2(120, -130)
	_ac_popup.visible = false
	add_child(_ac_popup)
	_ac_list = VBoxContainer.new()
	_ac_list.add_theme_constant_override("separation", 2)
	_ac_popup.add_child(_ac_list)

	var emoji_btn := Button.new()
	emoji_btn.text = "😀"
	emoji_btn.tooltip_text = LocaleManager.t("chat.emoji_tip", "表情 / 快捷短语")
	emoji_btn.pressed.connect(_toggle_emoji)
	_seticon(emoji_btn, "emoji", "😀")
	hb.add_child(emoji_btn)

	var img_btn := Button.new()
	img_btn.text = LocaleManager.t("chat.img_btn", "图")
	img_btn.tooltip_text = LocaleManager.t("chat.send_image", "发送图片")
	img_btn.pressed.connect(_pick_image)
	_seticon(img_btn, "image", LocaleManager.t("chat.img_btn", "图"))
	hb.add_child(img_btn)

	var at_btn := Button.new()
	at_btn.tooltip_text = LocaleManager.t("chat.at_mention", "@ 提及")
	at_btn.pressed.connect(func(): _insert_text("@"))
	_seticon(at_btn, "at", "@")
	hb.add_child(at_btn)

	var bell_btn := Button.new()
	bell_btn.tooltip_text = LocaleManager.t("chat.toggle_sound", "开/关 新消息提示音")
	bell_btn.toggle_mode = true
	bell_btn.toggled.connect(func(on): _muted = on)
	_seticon(bell_btn, "bell", "🔔")
	hb.add_child(bell_btn)

	var send_btn := Button.new()
	send_btn.tooltip_text = LocaleManager.t("common.send", "发送")
	send_btn.pressed.connect(func(): _on_submit(_input.text))
	_seticon(send_btn, "send", "↵")
	hb.add_child(send_btn)

	# Emoji / quick-phrase picker popup.
	_emoji_popup = PanelContainer.new()
	_emoji_popup.add_theme_stylebox_override("panel", _bg(Color(0.08, 0.09, 0.13, 0.99), 8))
	_emoji_popup.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_emoji_popup.position = Vector2(360, -150)
	_emoji_popup.visible = false
	add_child(_emoji_popup)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 4)
	_emoji_popup.add_child(ev)
	# "Recently used" row (filled from disk, updated on use).
	var recent_lbl := Label.new()
	recent_lbl.text = LocaleManager.t("chat.recent", "最近")
	recent_lbl.add_theme_font_size_override("font_size", 12)
	recent_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	ev.add_child(recent_lbl)
	_recent_grid = GridContainer.new()
	_recent_grid.columns = 8
	ev.add_child(_recent_grid)
	var grid := GridContainer.new()
	grid.columns = 6
	ev.add_child(grid)
	for e in EMOJIS:
		var eb := Button.new()
		eb.text = e
		eb.add_theme_font_size_override("font_size", 20)
		var ec := String(e)
		eb.pressed.connect(func(): _emoji_used(ec))
		grid.add_child(eb)
	_load_recent()
	_rebuild_recent()
	for p in QUICK_PHRASES:
		var pb := Button.new()
		pb.text = LocaleManager.t("chat.phrase." + String(p), String(p))
		pb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pc := String(p)
		pb.pressed.connect(func(): _insert_text(pc); _hide_emoji())
		ev.add_child(pb)

	# Custom sticker pack (saved image URLs).
	var sep := HSeparator.new()
	ev.add_child(sep)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	ev.add_child(srow)
	var slabel := Label.new()
	slabel.text = LocaleManager.t("chat.stickers", "贴图")
	slabel.add_theme_font_size_override("font_size", 12)
	slabel.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	srow.add_child(slabel)
	_sticker_group_btn = OptionButton.new()
	_sticker_group_btn.add_theme_font_size_override("font_size", 12)
	_sticker_group_btn.item_selected.connect(_on_sticker_group_selected)
	srow.add_child(_sticker_group_btn)
	var new_grp := Button.new()
	new_grp.text = LocaleManager.t("chat.new_group", "新建组")
	new_grp.pressed.connect(_new_sticker_group)
	srow.add_child(new_grp)
	var add_st := Button.new()
	add_st.text = LocaleManager.t("chat.add", "＋添加")
	add_st.tooltip_text = LocaleManager.t("chat.add_sticker_tip", "上传图片加入当前分组")
	add_st.pressed.connect(_add_sticker)
	srow.add_child(add_st)
	_sticker_grid = GridContainer.new()
	_sticker_grid.columns = 5
	ev.add_child(_sticker_grid)
	_load_stickers()
	_builtin_packs = AssetLib.sticker_manifest()
	_rebuild_sticker_groups()
	_rebuild_stickers()

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg, *.jpeg ; JPEG", "*.webp ; WebP"])
	_file_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_file_dialog.file_selected.connect(_on_file_chosen)
	add_child(_file_dialog)

	_img_http = HTTPRequest.new()
	add_child(_img_http)

	# Full-image viewer overlay (click a thumbnail to open).
	_viewer = Control.new()
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.visible = false
	_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_viewer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.add_child(dim)
	_viewer_rect = TextureRect.new()
	_viewer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer_rect.offset_left = 60
	_viewer_rect.offset_top = 80
	_viewer_rect.offset_right = -60
	_viewer_rect.offset_bottom = -60
	_viewer_rect.pivot_offset = Vector2.ZERO
	_viewer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let wheel reach the viewer
	_viewer.add_child(_viewer_rect)

	# Toolbar: zoom out / reset / in / save / close.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.position = Vector2(-180, 24)
	_viewer.add_child(bar)
	for spec in [["－", Callable(self, "_zoom_by").bind(1.0 / 1.25)],
			["100%", Callable(self, "_zoom_reset")],
			["＋", Callable(self, "_zoom_by").bind(1.25)],
			[LocaleManager.t("common.save", "保存"), Callable(self, "_save_image")],
			[LocaleManager.t("common.close", "关闭"), Callable(self, "_close_viewer")]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.add_theme_font_size_override("font_size", FONT_BODY)
		b.pressed.connect(spec[1])
		bar.add_child(b)

	# Wheel zooms; drag pans; a click that didn't drag closes.
	_viewer.gui_input.connect(_on_viewer_input)

	_save_dialog = FileDialog.new()
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_dialog.file_selected.connect(_on_save_path)
	add_child(_save_dialog)


func _bg(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _on_peer_seen(peer_id: String, peer_name: String, avatar: String, _p: Vector3, _y: float) -> void:
	_peers[peer_id] = peer_name
	if avatar != "":
		_avatar_url_cache[peer_id] = avatar


func _on_channel_selected(idx: int) -> void:
	_channel = ["chapter", "world", "dm", "room"][idx]
	_dm_btn.visible = _channel == "dm"
	_room_box.visible = _channel == "room"
	if _channel != "room":
		_members_popup.visible = false
	if _channel == "dm":
		_rebuild_dm_targets()


# --- Group rooms ---
func _create_room() -> void:
	if not AuthService.is_online:
		_system(LocaleManager.t("chat.offline_room", "离线状态：无法创建房间。"))
		return
	# Text in the room field (if any) is used as the new room's name.
	var wanted_name := _room_edit.text.strip_edges()
	var res: Dictionary = await ApiClient.request_json("POST", "/chat/room/create", {"name": wanted_name})
	if res.ok and res.data is Dictionary:
		_room_edit.text = String((res.data as Dictionary).get("room", ""))
		_join_room()


func _join_room() -> void:
	var room := _room_edit.text.strip_edges()
	if room == "":
		return
	if _current_room != "" and _current_room != room:
		RealtimeService.room_leave(_current_room)
	_current_room = room
	RealtimeService.room_join(room)
	# Load this room's recent history.
	var res: Dictionary = await ApiClient.request_json("GET", "/chat/history?scope=room&room_id=%s" % room)
	if res.ok and res.data is Array:
		_system(LocaleManager.t("chat.room_history", "—— 群聊「%s」历史 ——") % room)
		for m in res.data:
			if m is Dictionary:
				_add_row(m, false)


func _on_room_members(room: String, room_name: String, members: Array) -> void:
	if room != _current_room:
		return
	if room_name != "":
		_room_name = room_name
	_render_members(members)


func _toggle_members() -> void:
	_members_popup.visible = not _members_popup.visible


func _render_members(members: Array) -> void:
	for c in _members_box.get_children():
		c.queue_free()
	var title := Label.new()
	var label := _room_name if _room_name != "" else _current_room
	title.text = LocaleManager.t("chat.room_title", "群聊「%s」 · %d 人") % [label, members.size()]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	_members_box.add_child(title)
	for mm in members:
		if mm is Dictionary:
			var mrow := HBoxContainer.new()
			mrow.add_theme_constant_override("separation", 6)
			var av := String(mm.get("avatar", ""))
			var mid := String(mm.get("id", ""))
			if av != "":
				_avatar_url_cache[mid] = av
			var ar := TextureRect.new()
			ar.custom_minimum_size = Vector2(20, 20)
			ar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_apply_avatar(ar, av, mid)
			mrow.add_child(ar)
			var l := Label.new()
			var nm := String(mm.get("name", LocaleManager.t("lb.pilgrim", "朝圣者")))
			if String(mm.get("id", "")) == AuthService.player_id:
				nm += LocaleManager.t("chat.you", "（你）")
			l.text = nm
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
			mrow.add_child(l)
			_members_box.add_child(mrow)


func _rebuild_dm_targets() -> void:
	_dm_btn.clear()
	if _peers.is_empty():
		_dm_btn.add_item(LocaleManager.t("chat.no_others", "（本关暂无他人）"), 0)
		_dm_btn.set_item_disabled(0, true)
		return
	var i := 0
	for pid in _peers.keys():
		var n := int(_unread_by_peer.get(pid, 0))
		var label := String(_peers[pid]) + ("  (%d)" % n if n > 0 else "")
		_dm_btn.add_item(label, i)
		_dm_btn.set_item_metadata(i, pid)
		i += 1


func _dm_target() -> String:
	if _dm_btn.item_count == 0:
		return ""
	var meta: Variant = _dm_btn.get_item_metadata(_dm_btn.selected)
	return String(meta) if meta != null else ""


func _on_dm_target_selected(_idx: int) -> void:
	_mark_read(_dm_target())


# --- Private-message unread (red dot) ---
func _refresh_unread() -> void:
	if not (NetConfig.enabled and AuthService.is_online):
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/chat/unread")
	if not res.ok or not (res.data is Dictionary):
		return
	var data: Dictionary = res.data
	_unread_total = int(data.get("total", 0))
	_unread_by_peer.clear()
	for t in data.get("threads", []):
		if t is Dictionary:
			_unread_by_peer[String(t.get("peer_id", ""))] = int(t.get("count", 0))
	_update_badge()
	if _channel == "dm":
		_rebuild_dm_targets()


func _update_badge() -> void:
	if _unread_total > 0:
		_badge.text = LocaleManager.t("chat.dm_n", "私信 %d") % _unread_total
		_badge.visible = true
	else:
		_badge.visible = false


func _mark_read(peer_id: String) -> void:
	if peer_id == "" or int(_unread_by_peer.get(peer_id, 0)) == 0:
		return
	await ApiClient.request_json("POST", "/chat/read", {"peer_id": peer_id})
	_refresh_unread()


# --- Offline @mention notifications ---
func _refresh_mentions() -> void:
	if not (NetConfig.enabled and AuthService.is_online):
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/chat/mentions")
	if not res.ok or not (res.data is Array):
		return
	var items: Array = res.data
	for m in items:
		if m is Dictionary:
			EventBus.toast(LocaleManager.t("chat.mention_notif", "[@] %s 在%s里提到了你：%s") % [
				String(m.get("from_name", "")), _channel_tag_plain(String(m.get("channel", ""))),
				String(m.get("text", "")).left(24)])
	# Acknowledge so they don't notify again.
	if not items.is_empty():
		await ApiClient.request_json("POST", "/chat/mentions/seen", {})


# --- Sending ---
func _on_submit(text: String) -> void:
	if _ac_popup.visible:
		# Enter while the autocomplete is open accepts the first suggestion.
		if _ac_list.get_child_count() > 0:
			(_ac_list.get_child(0) as Button).pressed.emit()
			return
	var t := text.strip_edges()
	if t != "":
		RealtimeService.send_chat(t, _channel, _dm_target(), "", _current_room, _reply_to, _reply_preview)
	_input.text = ""
	_clear_reply()
	_hide_autocomplete()
	_set_input_open(false)


# --- Quote reply ---
func _set_reply(mid: String, who: String, preview: String) -> void:
	_reply_to = mid
	_reply_preview = preview
	_reply_label.text = LocaleManager.t("chat.reply_to", "回复 %s：%s") % [who, preview.left(28)]
	_reply_bar.visible = true
	_set_input_open(true)


func _clear_reply() -> void:
	_reply_to = ""
	_reply_preview = ""
	_reply_bar.visible = false


# --- Custom stickers ---
func _add_sticker() -> void:
	if not AuthService.is_online:
		_system(LocaleManager.t("chat.offline_sticker", "离线状态：无法添加贴图。"))
		return
	_file_dialog.set_meta("mode", "sticker")
	_file_dialog.popup_centered_ratio(0.6)


func _send_sticker(url: String) -> void:
	RealtimeService.send_chat("", _channel, _dm_target(), url, _current_room)
	AudioManager.play_sfx("sticker_send")
	_hide_emoji()


func _active_group() -> String:
	return String(_sticker_data.get("active", LocaleManager.t("chat.default_group", "默认")))


func _active_stickers() -> Array:
	var groups: Dictionary = _sticker_data.get("groups", {})
	return groups.get(_active_group(), [])


func _rebuild_sticker_groups() -> void:
	_sticker_group_btn.clear()
	var groups: Dictionary = _sticker_data.get("groups", {})
	var i := 0
	var active := _active_group()
	for g in groups.keys():
		_sticker_group_btn.add_item(String(g), i)
		if String(g) == active:
			_sticker_group_btn.select(i)
		i += 1
	_builtin_label_to_id.clear()
	var packs: Dictionary = _builtin_packs.get("packs", {})
	for pid in packs.keys():
		var label := "📦" + String(packs[pid].get("label", pid))
		_sticker_group_btn.add_item(label, i)
		_builtin_label_to_id[label] = String(pid)
		if label == active:
			_sticker_group_btn.select(i)
		i += 1


func _on_sticker_group_selected(idx: int) -> void:
	_sticker_data["active"] = _sticker_group_btn.get_item_text(idx)
	_save_stickers()
	_rebuild_stickers()


func _new_sticker_group() -> void:
	var groups: Dictionary = _sticker_data.get("groups", {})
	var base := LocaleManager.t("chat.group_n", "分组%d") % (groups.size() + 1)
	groups[base] = []
	_sticker_data["groups"] = groups
	_sticker_data["active"] = base
	_save_stickers()
	_rebuild_sticker_groups()
	_rebuild_stickers()


func _rebuild_stickers() -> void:
	for c in _sticker_grid.get_children():
		c.queue_free()
	if _builtin_label_to_id.has(_active_group()):
		_build_builtin_stickers(_builtin_label_to_id[_active_group()])
		return
	for url in _active_stickers():
		var b := Button.new()
		b.text = "🖼"
		b.tooltip_text = LocaleManager.t("chat.send_sticker", "发送贴图（右键删除）")
		b.add_theme_font_size_override("font_size", 18)
		var u := String(url)
		b.pressed.connect(func(): _send_sticker(u))
		b.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				_active_stickers().erase(u); _save_stickers(); _rebuild_stickers())
		_sticker_grid.add_child(b)


func _build_builtin_stickers(pid: String) -> void:
	var names: Array = _builtin_packs.get("packs", {}).get(pid, {}).get("names", [])
	for nm in names:
		var b := Button.new()
		var st := AssetLib.sticker(pid, String(nm))
		if st != null:
			b.icon = st
			b.expand_icon = true
			b.custom_minimum_size = Vector2(44, 44)
		else:
			b.text = "🖼"
			b.tooltip_text = String(nm)
		var token := "sticker://%s/%s" % [pid, String(nm)]
		b.pressed.connect(func(): _send_sticker(token))
		_sticker_grid.add_child(b)


func _add_to_active_group(url: String) -> void:
	var arr := _active_stickers()
	if not arr.has(url):
		arr.push_front(url)
		_save_stickers()
		_rebuild_stickers()


func _load_stickers() -> void:
	if not FileAccess.file_exists(STICKER_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STICKER_FILE))
	if parsed is Dictionary and parsed.has("groups"):
		_sticker_data = parsed
	elif parsed is Array:
		# Migrate the old flat list into the default group.
		_sticker_data = {"groups": {LocaleManager.t("chat.default_group", "默认"): parsed}, "active": LocaleManager.t("chat.default_group", "默认")}
		_save_stickers()


func _save_stickers() -> void:
	var f := FileAccess.open(STICKER_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_sticker_data))
		f.close()


# --- @-mention autocomplete ---
func _on_input_changed(text: String) -> void:
	var frag: Variant = _active_mention_fragment(text)
	if frag == null:
		_hide_autocomplete()
		return
	var matches: Array = []
	var names := ["所有人"]
	for pid in _peers.keys():
		names.append(String(_peers[pid]))
	for n in names:
		if frag == "" or n.to_lower().begins_with(String(frag).to_lower()):
			matches.append(n)
	if matches.is_empty():
		_hide_autocomplete()
		return
	_show_autocomplete(matches.slice(0, 6))


## Returns the partial text after a trailing "@token" being typed, or null.
func _active_mention_fragment(text: String):
	var caret := _input.caret_column
	var upto := text.substr(0, caret)
	var at := upto.rfind("@")
	if at < 0:
		return null
	var frag := upto.substr(at + 1)
	if " " in frag or "\t" in frag:
		return null
	return frag


func _show_autocomplete(names: Array) -> void:
	for c in _ac_list.get_children():
		c.queue_free()
	for n in names:
		var btn := Button.new()
		btn.text = "@" + String(n)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", FONT_BODY)
		var nm := String(n)
		btn.pressed.connect(func(): _accept_mention(nm))
		_ac_list.add_child(btn)
	_ac_popup.visible = true


func _accept_mention(name: String) -> void:
	var text := _input.text
	var caret := _input.caret_column
	var upto := text.substr(0, caret)
	var at := upto.rfind("@")
	if at < 0:
		return
	var prefix := text.substr(0, at)
	var suffix := text.substr(caret)
	var insert := "@" + name + " "
	_input.text = prefix + insert + suffix
	_input.caret_column = (prefix + insert).length()
	_hide_autocomplete()
	_input.grab_focus()


func _hide_autocomplete() -> void:
	_ac_popup.visible = false


# --- Full-image viewer ---
func _open_viewer(full_url: String) -> void:
	_viewer.visible = true
	_viewer_rect.texture = null
	_viewer_bytes = PackedByteArray()
	_viewer_ext = full_url.get_extension().to_lower()
	_zoom_reset()
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var img := Image.new()
			var err := ERR_UNAVAILABLE
			if _viewer_ext == "png": err = img.load_png_from_buffer(body)
			elif _viewer_ext in ["jpg", "jpeg"]: err = img.load_jpg_from_buffer(body)
			elif _viewer_ext == "webp": err = img.load_webp_from_buffer(body)
			if err == OK and is_instance_valid(_viewer_rect):
				_viewer_rect.texture = ImageTexture.create_from_image(img)
				_viewer_bytes = body
		http.queue_free())
	http.request(NetConfig.media_url(full_url))


func _on_viewer_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_by(1.1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_by(1.0 / 1.1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_pan_active = true
				_pan_moved = false
			else:
				_pan_active = false
				if not _pan_moved:
					_close_viewer()  # a click (no drag) closes
	elif e is InputEventMouseMotion and _pan_active:
		if e.relative.length() > 1.0:
			_pan_moved = true
		_viewer_rect.position += e.relative


func _zoom_by(factor: float) -> void:
	_viewer_zoom = clampf(_viewer_zoom * factor, 0.2, 6.0)
	_viewer_rect.scale = Vector2(_viewer_zoom, _viewer_zoom)


func _zoom_reset() -> void:
	_viewer_zoom = 1.0
	_viewer_rect.scale = Vector2.ONE
	_viewer_rect.position = Vector2.ZERO


func _save_image() -> void:
	if _viewer_bytes.is_empty():
		_system(LocaleManager.t("chat.img_loading", "图片尚未加载完成。"))
		return
	_save_dialog.current_file = "pilgrim_image.%s" % _viewer_ext
	_save_dialog.popup_centered_ratio(0.6)


func _on_save_path(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(_viewer_bytes)
		f.close()
		_system(LocaleManager.t("chat.img_saved", "图片已保存。"))
	else:
		_system(LocaleManager.t("chat.save_failed", "保存失败。"))


func _close_viewer() -> void:
	_viewer.visible = false
	_viewer_rect.texture = null
	_viewer_bytes = PackedByteArray()


func _pick_image() -> void:
	if not AuthService.is_online:
		_system(LocaleManager.t("chat.offline_image", "离线状态：无法发送图片。"))
		return
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_chosen(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		_system(LocaleManager.t("account.img_unreadable", "无法读取图片。"))
		return
	if bytes.size() > 2 * 1024 * 1024:
		_system(LocaleManager.t("account.img_too_big", "图片过大（上限 2MB）。"))
		return
	var ext := path.get_extension().to_lower()
	var b64 := Marshalls.raw_to_base64(bytes)
	var as_sticker := String(_file_dialog.get_meta("mode", "image")) == "sticker"
	_file_dialog.set_meta("mode", "image")
	var res: Dictionary = await ApiClient.request_json("POST", "/chat/image", {"data": b64, "ext": ext})
	if res.ok and res.data is Dictionary:
		var url := String((res.data as Dictionary).get("url", ""))
		if url == "":
			return
		if as_sticker:
			_add_to_active_group(url)
			_system(LocaleManager.t("chat.sticker_group_added", "已加入贴图分组「%s」。") % _active_group())
		else:
			RealtimeService.send_chat("", _channel, _dm_target(), url, _current_room, _reply_to, _reply_preview)
			_clear_reply()
	else:
		_system(LocaleManager.t("chat.img_upload_failed", "图片上传失败。"))


# --- Receiving ---
func _clear() -> void:
	for c in _log_box.get_children():
		c.queue_free()
	_log_panel.visible = false


func _on_history(items: Array) -> void:
	# Pre-fetch avatars for all senders so history rows can show them.
	var ids: Array = []
	for it in items:
		if it is Dictionary:
			var pid := String(it.get("id", ""))
			if pid != "" and not _avatar_url_cache.has(pid) and not ids.has(pid):
				ids.append(pid)
	if not ids.is_empty() and AuthService.is_online:
		var res: Dictionary = await ApiClient.request_json("GET", "/players/avatars?ids=%s" % ",".join(ids))
		if res.ok and res.data is Dictionary:
			for pid in (res.data as Dictionary).keys():
				_avatar_url_cache[String(pid)] = String((res.data as Dictionary)[pid])
	for it in items:
		if it is Dictionary:
			_add_row(it, false)


func _apply_avatar(rect: TextureRect, url: String, seed: String = "") -> void:
	if url == "":
		rect.texture = AvatarUtil.default_texture(seed)
		return
	if _avatar_tex_cache.has(url):
		rect.texture = _avatar_tex_cache[url]
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var tex := AvatarUtil.circle_from_buffer(body, url.get_extension())
			if tex != null:
				_avatar_tex_cache[url] = tex
				if is_instance_valid(rect):
					rect.texture = tex
		http.queue_free())
	http.request(NetConfig.media_url(url))


func _on_chat(msg: Dictionary) -> void:
	_add_row(msg, true)
	var mine := String(msg.get("id", "")) == AuthService.player_id
	if mine:
		return
	var text := String(msg.get("text", ""))
	var channel := String(msg.get("channel", ""))
	# Private message arrived -> refresh the unread red dot.
	if channel == "dm":
		_refresh_unread()
	# @mention of me -> a stronger notice.
	if _mentions_me(text):
		if not _muted:
			AudioManager.play_sfx("mention")
		EventBus.toast(LocaleManager.t("chat.mention_toast", "有人在%s里@了你：%s") % [_channel_tag_plain(channel), String(msg.get("name", ""))])
	elif not _open:
		if not _muted:
			AudioManager.play_sfx("message_in")
		var preview := text if text != "" else LocaleManager.t("chat.image_tag", "[图片]")
		EventBus.toast("%s%s：%s" % [_channel_tag(channel), String(msg.get("name", "")), preview])


func _seticon(btn: Button, ui_name: String, fallback: String) -> void:
	var t: Texture2D = AssetLib.ui(ui_name)
	if t != null:
		btn.icon = t
		btn.text = ""
		btn.expand_icon = true
		if btn.custom_minimum_size == Vector2.ZERO:
			btn.custom_minimum_size = Vector2(30, 30)
	else:
		btn.text = fallback


func _mentions_me(text: String) -> bool:
	if text == "":
		return false
	var me := AuthService.display_name
	if me != "" and ("@" + me) in text:
		return true
	for token in ["@all", "@All", "@所有人", "@全体"]:
		if token in text:
			return true
	return false


func _channel_tag_plain(channel: String) -> String:
	match channel:
		"world": return LocaleManager.t("chat.world_channel", "世界频道")
		"dm": return LocaleManager.t("chat.ch_dm", "私聊")
		_: return LocaleManager.t("chat.ch_local", "本关")


func _system(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 13)
	lbl.text = "[color=#d0a050][i]%s[/i][/color]" % _bbsafe(text)
	_append(lbl)


func _channel_tag(channel: String) -> String:
	match channel:
		"world": return LocaleManager.t("chat.tag_world", "[世界] ")
		"dm": return LocaleManager.t("chat.tag_dm", "[私聊] ")
		_: return ""


func _add_row(msg: Dictionary, _live: bool) -> void:
	var mid0 := String(msg.get("mid", ""))
	if bool(msg.get("deleted", false)):
		var ph := _make_placeholder()
		_append(ph)
		if mid0 != "":
			_rows_by_mid[mid0] = ph
		return
	var mine := String(msg.get("id", "")) == AuthService.player_id
	var name_col := "#9fe0c0" if mine else "#cfd6ea"
	var tag := _channel_tag(String(msg.get("channel", "")))
	var text := String(msg.get("text", ""))
	var mentions_me := not mine and _mentions_me(text)
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 14)
	lbl.text = "[color=#7c93b8]%s[/color][color=%s]%s[/color]：%s" % [
		tag, name_col, _bbsafe(String(msg.get("name", LocaleManager.t("lb.pilgrim", "朝圣者")))), _highlight_mentions(text)]
	if mentions_me:
		# Tint the whole row so a mention stands out.
		var hb := StyleBoxFlat.new()
		hb.bg_color = Color(0.32, 0.27, 0.08, 0.55)
		for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			hb.set("corner_radius_" + side, 4)
		lbl.add_theme_stylebox_override("normal", hb)

	# Build the row: [text (expand)] [引 quote] [× recall if own & recent].
	var mid := String(msg.get("mid", ""))
	var who := String(msg.get("name", LocaleManager.t("lb.pilgrim", "朝圣者")))
	var recallable := mine and mid != "" and (Time.get_unix_time_from_system() * 1000 - int(msg.get("ts", 0))) < RECALL_WINDOW_MS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sender avatar (live messages carry it; history is filled via batch cache).
	var av_url := String(msg.get("avatar", ""))
	if av_url == "":
		av_url = String(_avatar_url_cache.get(String(msg.get("id", "")), ""))
	var sender_id := String(msg.get("id", ""))
	if av_url != "":
		_avatar_url_cache[sender_id] = av_url
	var av_rect := TextureRect.new()
	av_rect.custom_minimum_size = Vector2(22, 22)
	av_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_avatar(av_rect, av_url, sender_id)
	row.add_child(av_rect)
	row.add_child(lbl)
	if mid != "":
		var q := Button.new()
		q.text = LocaleManager.t("chat.quote_btn", "引")
		q.tooltip_text = LocaleManager.t("chat.quote_reply", "引用回复")
		q.add_theme_color_override("font_color", Color(0.6, 0.78, 0.95))
		var preview := text if text != "" else LocaleManager.t("chat.image_tag", "[图片]")
		q.pressed.connect(func(): _set_reply(mid, who, preview))
		row.add_child(q)
	if recallable:
		var x := Button.new()
		x.text = "×"
		x.tooltip_text = LocaleManager.t("chat.recall", "撤回")
		x.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
		x.pressed.connect(func(): RealtimeService.recall(mid))
		_seticon(x, "recall", "×")
		row.add_child(x)

	# Wrap with a clickable quoted-preview line above (jumps to the original).
	var container: Control = row
	var rp := String(msg.get("reply_preview", ""))
	if rp != "":
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		var quote := Button.new()
		quote.flat = true
		quote.alignment = HORIZONTAL_ALIGNMENT_LEFT
		quote.add_theme_font_size_override("font_size", 12)
		quote.add_theme_color_override("font_color", Color(0.42, 0.47, 0.56))
		quote.text = "┃ " + rp
		quote.tooltip_text = LocaleManager.t("chat.jump_orig", "点击跳转原消息")
		var ref := String(msg.get("reply_to", ""))
		quote.pressed.connect(func(): _jump_to(ref))
		vb.add_child(quote)
		vb.add_child(row)
		container = vb

	_append(container)
	if mid != "":
		_rows_by_mid[mid] = container
	var image_url := String(msg.get("image_url", ""))
	if image_url != "":
		_append_image(image_url)


func _on_chat_deleted(mid: String) -> void:
	var node: Control = _rows_by_mid.get(mid)
	if node != null and is_instance_valid(node):
		var ph := _make_placeholder()
		node.add_sibling(ph)
		node.queue_free()
		_rows_by_mid[mid] = ph


func _jump_to(mid: String) -> void:
	var node: Control = _rows_by_mid.get(mid)
	if node == null or not is_instance_valid(node):
		_system(LocaleManager.t("chat.orig_gone", "原消息已不在当前记录中。"))
		return
	await get_tree().process_frame
	# Scroll the log so the target row is visible.
	_log_scroll.ensure_control_visible(node)
	# Brief highlight flash.
	var flash := StyleBoxFlat.new()
	flash.bg_color = Color(0.35, 0.32, 0.12, 0.7)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		flash.set("corner_radius_" + side, 4)
	if node is Control:
		node.add_theme_stylebox_override("panel", flash)
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(func():
			if is_instance_valid(node):
				node.remove_theme_stylebox_override("panel"))


func _make_placeholder() -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 13)
	lbl.text = LocaleManager.t("chat.recalled", "[color=#7a8090][i]此消息已撤回[/i][/color]")
	return lbl


func _insert_text(s: String) -> void:
	if not _open:
		_set_input_open(true)
	var caret := _input.caret_column
	var t := _input.text
	_input.text = t.substr(0, caret) + s + t.substr(caret)
	_input.caret_column = caret + s.length()
	_input.grab_focus()


func _toggle_emoji() -> void:
	_emoji_popup.visible = not _emoji_popup.visible


func _hide_emoji() -> void:
	_emoji_popup.visible = false


func _emoji_used(e: String) -> void:
	_insert_text(e)
	_recent_emojis.erase(e)
	_recent_emojis.push_front(e)
	if _recent_emojis.size() > MAX_RECENT:
		_recent_emojis.resize(MAX_RECENT)
	_save_recent()
	_rebuild_recent()


func _rebuild_recent() -> void:
	for c in _recent_grid.get_children():
		c.queue_free()
	for e in _recent_emojis:
		var b := Button.new()
		b.text = String(e)
		b.add_theme_font_size_override("font_size", 20)
		var ec := String(e)
		b.pressed.connect(func(): _emoji_used(ec))
		_recent_grid.add_child(b)


func _load_recent() -> void:
	if FileAccess.file_exists(RECENT_FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECENT_FILE))
		if parsed is Array:
			_recent_emojis = parsed


func _save_recent() -> void:
	var f := FileAccess.open(RECENT_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_recent_emojis))
		f.close()


## Color every @token; brighten the one that mentions me.
func _highlight_mentions(text: String) -> String:
	var safe := _bbsafe(text)
	var me := AuthService.display_name
	var out := ""
	var last := 0
	for m in _mention_re.search_all(safe):
		out += safe.substr(last, m.get_start() - last)
		var token := m.get_string()  # includes the leading @
		var is_me := (me != "" and token == "@" + me) or token in ["@all", "@All", "@所有人", "@全体"]
		var col := "#ffd479" if is_me else "#8fc7ff"
		out += "[color=%s]%s[/color]" % [col, token]
		last = m.get_end()
	out += safe.substr(last)
	return out


func _append(node: Control) -> void:
	_log_panel.visible = true
	_log_box.add_child(node)
	while _log_box.get_child_count() > MAX_ROWS:
		_log_box.get_child(0).queue_free()
		_log_box.remove_child(_log_box.get_child(0))
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _thumb_of(url: String) -> String:
	var dot := url.rfind(".")
	if dot < 0:
		return url
	return url.substr(0, dot) + "_thumb" + url.substr(dot)


func _append_image(image_url: String) -> void:
	if image_url.begins_with("sticker://"):
		_append_builtin_sticker(image_url)
		return
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 120)
	rect.tooltip_text = LocaleManager.t("chat.view_full", "点击查看原图")
	rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rect.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_viewer(image_url))
	_append(rect)
	# Fetch the lightweight server-made thumbnail rather than the full image.
	var thumb := _thumb_of(image_url)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var img := Image.new()
			var ext := thumb.get_extension().to_lower()
			var err := ERR_UNAVAILABLE
			if ext == "png": err = img.load_png_from_buffer(body)
			elif ext in ["jpg", "jpeg"]: err = img.load_jpg_from_buffer(body)
			elif ext == "webp": err = img.load_webp_from_buffer(body)
			if err == OK and is_instance_valid(rect):
				rect.texture = ImageTexture.create_from_image(img)
		http.queue_free())
	http.request(NetConfig.media_url(thumb))


func _append_builtin_sticker(token: String) -> void:
	var parts := token.substr(10).split("/")
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 96)
	if parts.size() >= 2:
		var st := AssetLib.sticker(parts[0], parts[1])
		if st != null:
			rect.texture = st
		else:
			rect.tooltip_text = token
	_append(rect)


func _bbsafe(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")


func _set_input_open(v: bool) -> void:
	_open = v
	_input_row.visible = v
	get_tree().paused = v
	if v:
		if _channel == "dm":
			_rebuild_dm_targets()
		_input.grab_focus()
	else:
		_hide_autocomplete()
		_hide_emoji()
		_clear_reply()
		_members_popup.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not (NetConfig.enabled and NetConfig.realtime):
		return
	if _viewer.visible and event.keycode == KEY_ESCAPE:
		_close_viewer()
		get_viewport().set_input_as_handled()
		return
	if _open and event.keycode == KEY_ESCAPE:
		if _ac_popup.visible:
			_hide_autocomplete()
		else:
			_input.text = ""
			_set_input_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_T and not _open:
		_set_input_open(true)
		get_viewport().set_input_as_handled()
