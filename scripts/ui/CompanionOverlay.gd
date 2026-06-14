extends CanvasLayer
## CompanionOverlay
## 多人同行 HUD: a small always-on widget (top-left, below the quest tracker)
## showing how many pilgrims walk this chapter right now, and surfacing other
## players' ghost markers/messages as gentle toasts when a chapter loads.
##
## Listens to GhostService signals. No-op and hidden when offline.

const FONT_BODY := 16

var _panel: Panel
var _presence_label: Label
var _net_label: Label
var _ghost_label: RichTextLabel
var _online: int = 0


func _ready() -> void:
	layer = 9
	_build()
	if NetConfig.enabled:
		GhostService.presence_updated.connect(_on_presence)
		GhostService.ghosts_received.connect(_on_ghosts)
		if NetConfig.realtime:
			RealtimeService.net_stats.connect(_on_net_stats)
			RealtimeService.realtime_disconnected.connect(func(): _set_net(-1, "poor"))
	_panel.visible = false


func _build() -> void:
	_panel = Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.09, 0.6)
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + side, 8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", s)
	_panel.position = Vector2(20, 122)   # just under the quest tracker
	_panel.size = Vector2(330, 96)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	_presence_label = Label.new()
	_presence_label.add_theme_font_size_override("font_size", FONT_BODY)
	_presence_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.8))
	vb.add_child(_presence_label)

	_net_label = Label.new()
	_net_label.add_theme_font_size_override("font_size", 13)
	_net_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_net_label.visible = false
	vb.add_child(_net_label)

	_ghost_label = RichTextLabel.new()
	_ghost_label.bbcode_enabled = true
	_ghost_label.fit_content = true
	_ghost_label.scroll_active = false
	_ghost_label.custom_minimum_size = Vector2(0, 56)
	_ghost_label.add_theme_font_size_override("normal_font_size", 14)
	vb.add_child(_ghost_label)


func _on_presence(chapter_id: String, online: int) -> void:
	_online = online
	_panel.visible = true
	# "online" includes me; show others walking alongside.
	var others: int = max(0, online - 1)
	if others <= 0:
		_presence_label.text = "此路你独行（暂无同行者）"
	else:
		_presence_label.text = "此刻 %d 位朝圣者与你同行" % others


func _on_net_stats(latency_ms: int, quality: String) -> void:
	_set_net(latency_ms, quality)


func _set_net(latency_ms: int, quality: String) -> void:
	_panel.visible = true
	_net_label.visible = true
	var label := {"good": "通畅", "fair": "一般", "poor": "不稳"}.get(quality, quality)
	var col := {"good": Color(0.6, 0.9, 0.7), "fair": Color(0.9, 0.85, 0.5),
		"poor": Color(0.9, 0.55, 0.55)}.get(quality, Color(0.7, 0.7, 0.8))
	_net_label.add_theme_color_override("font_color", col)
	if latency_ms >= 0:
		_net_label.text = "实时连接：%s（%d ms）" % [label, latency_ms]
	else:
		_net_label.text = "实时连接：%s" % label


func _on_ghosts(chapter_id: String, ghosts: Array) -> void:
	_panel.visible = true
	var markers: Array = []
	for g in ghosts:
		if String(g.get("kind", "")) == "marker" and String(g.get("message", "")) != "":
			markers.append("[color=#cfd6ea]%s[/color] —— [i]%s[/i]" % [
				String(g.get("display_name", "朝圣者")), String(g.get("message", ""))])
	if markers.is_empty():
		_ghost_label.text = "[color=#7a8090]前人的足迹隐约可见……[/color]"
	else:
		_ghost_label.text = "\n".join(PackedStringArray(markers.slice(0, 3)))
