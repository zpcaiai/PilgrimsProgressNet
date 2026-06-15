extends CanvasLayer
## CloudSyncDialog
## Modal that appears when a cloud-save upload conflicts (the cloud holds a
## newer save than this device knows about — e.g. you played on another
## device). Lets the player choose which save to keep. Also surfaces a brief
## toast on successful sync. No-op when networking is disabled.

const FONT_TITLE := 22
const FONT_BODY := 18

var _dim: ColorRect
var _panel: Panel
var _body: RichTextLabel
var _slot_id: String = "slot_1"
var _server_version: int = 0


func _ready() -> void:
	layer = 20
	_build()
	_set_visible(false)
	if NetConfig.enabled:
		CloudSaveService.cloud_conflict.connect(_on_conflict)
		CloudSaveService.cloud_downloaded.connect(func(_s): EventBus.toast(LocaleManager.t("cloud.restored", "已从云端恢复存档。")))
		CloudSaveService.cloud_uploaded.connect(func(_s, _v): pass)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
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
	_panel.position = Vector2(-280, -140)
	_panel.size = Vector2(560, 280)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = LocaleManager.t("cloud.conflict", "云端存档冲突")
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.7))
	vb.add_child(title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 110)
	_body.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_body.add_theme_color_override("default_color", Color(0.86, 0.89, 0.96))
	vb.add_child(_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var take_cloud := Button.new()
	take_cloud.text = LocaleManager.t("cloud.download", "下载云端存档")
	take_cloud.add_theme_font_size_override("font_size", FONT_BODY)
	take_cloud.custom_minimum_size = Vector2(220, 44)
	take_cloud.pressed.connect(_take_cloud)
	row.add_child(take_cloud)

	var keep_local := Button.new()
	keep_local.text = LocaleManager.t("cloud.keep_local", "保留本地（覆盖云端）")
	keep_local.add_theme_font_size_override("font_size", FONT_BODY)
	keep_local.custom_minimum_size = Vector2(220, 44)
	keep_local.pressed.connect(_keep_local)
	row.add_child(keep_local)


func _on_conflict(slot_id: String, server_version: int) -> void:
	_slot_id = slot_id
	_server_version = server_version
	_body.text = (LocaleManager.t("cloud.conflict_msg", "云端有一份[b]更新的存档[/b]（版本 %d），可能来自你的另一台设备。\n\n")
		+ LocaleManager.t("cloud.opt_download", "[color=#cfd6ea]下载云端[/color]：用云端进度覆盖本地。\n")
		+ LocaleManager.t("cloud.opt_keep", "[color=#cfd6ea]保留本地[/color]：用当前设备进度覆盖云端。")) % server_version
	_set_visible(true)
	get_tree().paused = true


func _take_cloud() -> void:
	_close()
	await CloudSaveService.resolve_take_cloud(_slot_id)


func _keep_local() -> void:
	_close()
	CloudSaveService.resolve_keep_local(_slot_id, _server_version)
	EventBus.toast(LocaleManager.t("cloud.overwrote", "已用本地存档覆盖云端。"))


func _close() -> void:
	get_tree().paused = false
	_set_visible(false)


func _set_visible(v: bool) -> void:
	_dim.visible = v
	_panel.visible = v
	# Let the dialog process and accept clicks even while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
