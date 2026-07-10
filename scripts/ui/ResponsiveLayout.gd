extends RefCounted
class_name ResponsiveLayout


static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return Vector2(1280, 720)
	return node.get_viewport().get_visible_rect().size


static func window_size(node: Node) -> Vector2:
	var size := Vector2(DisplayServer.window_get_size())
	if size.x <= 0.0 or size.y <= 0.0:
		return viewport_size(node)
	return size


static func is_mobile(node: Node) -> bool:
	var s := window_size(node)
	return minf(s.x, s.y) <= 700.0


static func margin(node: Node) -> float:
	var s := window_size(node)
	if minf(s.x, s.y) <= 380.0:
		return 14.0
	return 24.0 if is_mobile(node) else 32.0


static func safe_size(node: Node) -> Vector2:
	var s := viewport_size(node)
	var m := margin(node)
	return Vector2(maxf(160.0, s.x - m * 2.0), maxf(160.0, s.y - m * 2.0))


static func fit_fullscreen(control: Control, host: Node) -> Vector2:
	if control == null:
		return Vector2.ZERO
	var size := viewport_size(host)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = size
	return size


static func fit_center_panel(panel: Control, host: Node, max_size: Vector2,
			min_size: Vector2 = Vector2(280, 240)) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var viewport := viewport_size(host)
	var avail := safe_size(host)
	var mobile := is_mobile(host)
	var min_w := minf(min_size.x, avail.x)
	var min_h := minf(min_size.y, avail.y)
	var w := avail.x if mobile else clampf(minf(max_size.x, avail.x), min_w, avail.x)
	var h := avail.y if mobile else clampf(minf(max_size.y, avail.y), min_h, avail.y)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(
		floor((viewport.x - w) * 0.5),
		floor((viewport.y - h) * 0.5)
	)
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


static func set_modal_action(button: Button, min_height: float = 48.0) -> void:
	if button == null:
		return
	set_button_wrap(button)
	button.set_meta("modal_action", true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = maxf(min_height, button.custom_minimum_size.y)


static func place_panel_action(button: Button, panel: Control, height: float,
			inset: float = 16.0) -> void:
	if button == null or panel == null or not (button.get_parent() is Control):
		return
	var panel_rect := panel.get_global_rect()
	var parent_rect := (button.get_parent() as Control).get_global_rect()
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.position = panel_rect.position - parent_rect.position + Vector2(inset, panel_rect.size.y - height - inset)
	button.size = Vector2(maxf(120.0, panel_rect.size.x - inset * 2.0), height)
	button.move_to_front()


static func place_viewport_action(button: Button, host: Node, height: float,
			inset: float = 18.0) -> void:
	if button == null or not (button.get_parent() is Control):
		return
	var bounds := viewport_size(host)
	var parent_rect := (button.get_parent() as Control).get_global_rect()
	button.set_meta("viewport_action", true)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.position = Vector2(inset, bounds.y - height - inset) - parent_rect.position
	button.size = Vector2(maxf(120.0, bounds.x - inset * 2.0), height)
	button.move_to_front()


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
