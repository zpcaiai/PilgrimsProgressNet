extends CanvasLayer
## FloatingNumbers — transient floating combat text (damage / effect numbers that
## rise and fade over a 3D point). Autoloaded as `FloatingNumbers`.
##   FloatingNumbers.spawn(enemy.global_position + Vector3.UP * 2.0, "−12", col)

var _items: Array = []


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS


func spawn(world_pos: Vector3, text: String, color: Color = Color(1, 0.9, 0.5), size: int = 26) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_items.append({"label": lbl, "world": world_pos, "age": 0.0, "life": 1.15, "drift": randf_range(-26.0, 26.0)})


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	for i in range(_items.size() - 1, -1, -1):
		var e: Dictionary = _items[i]
		e["age"] += delta
		var lbl: Label = e["label"]
		if not is_instance_valid(lbl) or e["age"] >= e["life"] or cam == null:
			if is_instance_valid(lbl):
				lbl.queue_free()
			_items.remove_at(i)
			continue
		if cam.is_position_behind(e["world"]):
			lbl.visible = false
			continue
		lbl.visible = true
		var t: float = e["age"] / e["life"]
		var sp := cam.unproject_position(e["world"])
		lbl.position = sp + Vector2(float(e["drift"]) * t - lbl.size.x * 0.5, -46.0 * t - 12.0)
		lbl.modulate.a = 1.0 - smoothstep(0.55, 1.0, t)
