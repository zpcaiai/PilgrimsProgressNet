extends Area3D
class_name ArrowPressureZone
## The pressure approaching the Wicket Gate. While the player is inside, any
## ArrowEmitters in the chapter (built from VFX_ArrowEmitter_* markers) target the
## player and fire; standing still gets you hit, which raises fear/shame. Built by
## ImportedSceneBinder from COL_ArrowPressureZone. Non-lethal, urgency only.

var _player: Node3D = null


func setup(size: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _emitters() -> Array:
	return get_tree().get_nodes_in_group("arrow_emitter")


func _on_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	for e in _emitters():
		if e.has_method("setup"):
			e.call("setup", body)
		e.set("active", true)


func _on_exit(body: Node) -> void:
	if body == _player:
		_player = null
		for e in _emitters():
			e.set("active", false)
