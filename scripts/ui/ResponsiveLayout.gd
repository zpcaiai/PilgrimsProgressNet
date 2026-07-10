extends RefCounted
class_name ResponsiveLayout


static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return Vector2(1280, 720)
	return node.get_viewport().get_visible_rect().size


static func is_mobile(node: Node) -> bool:
	var s := viewport_size(node)
	return DisplayServer.is_touchscreen_available() or minf(s.x, s.y) <= 640.0


static func margin(node: Node) -> float:
	var s := viewport_size(node)
	if minf(s.x, s.y) <= 380.0:
		return 14.0
	return 24.0 if is_mobile(node) else 32.0


static func safe_size(node: Node) -> Vector2:
	var s := viewport_size(node)
	var m := margin(node)
	return Vector2(maxf(160.0, s.x - m * 2.0), maxf(160.0, s.y - m * 2.0))


static func fit_center_panel(panel: Control, host: Node, max_size: Vector2,
		min_size: Vector2 = Vector2(280, 240)) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var avail := safe_size(host)
	if is_mobile(host):
		var m := margin(host)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = m
		panel.offset_top = m
		panel.offset_right = -m
		panel.offset_bottom = -m
		return avail
	var min_w := minf(min_size.x, avail.x)
	var min_h := minf(min_size.y, avail.y)
	var w := clampf(minf(max_size.x, avail.x), min_w, avail.x)
	var h := clampf(minf(max_size.y, avail.y), min_h, avail.y)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-w * 0.5, -h * 0.5)
	panel.size = Vector2(w, h)
	return panel.size


static func apply_text_wrap(label: Control, arbitrary: bool = false) -> void:
	if label == null:
		return
	var mode := TextServer.AUTOWRAP_ARBITRARY if arbitrary else TextServer.AUTOWRAP_WORD_SMART
	if label is Label:
		(label as Label).autowrap_mode = mode
		(label as Label).clip_text = false
		(label as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	elif label is RichTextLabel:
		(label as RichTextLabel).autowrap_mode = mode


static func set_button_wrap(button: Button) -> void:
	if button == null:
		return
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.clip_text = false


static func normalize_tree(root: Node, mobile: bool = false) -> void:
	if root == null:
		return
	if root is Label or root is RichTextLabel:
		apply_text_wrap(root as Control, mobile)
	elif root is Button:
		var button := root as Button
		set_button_wrap(button)
		if mobile:
			button.custom_minimum_size.y = maxf(44.0, button.custom_minimum_size.y)
	for child in root.get_children():
		normalize_tree(child, mobile)
