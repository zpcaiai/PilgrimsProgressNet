extends Area3D
class_name SleepField
## The drowse of the Enchanted Ground. While the player lingers inside, a heavy
## sleep gathers (a darkening overlay). Watchfulness slows it; a companion
## nearby rouses the pilgrim. If the drowse completes, the pilgrim "sleeps" and
## is set back to the field's near edge with a watchfulness penalty.

var threshold: float = 10.0
var entry_point: Vector3 = Vector3.ZERO
var _player: PlayerController = null
var _drowse: float = 0.0
var _overlay: ColorRect
var _layer: CanvasLayer


func setup(size: Vector3, edge_point: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	entry_point = edge_point
	# Children's Journey: far more time before the drowse takes you.
	if GameState.is_child_mode():
		threshold = 22.0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	# Tinted ground to read as "enchanted".
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.1, size.z)
	mesh.mesh = bm
	mesh.position = Vector3(0, -size.y * 0.5 + 0.06, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.45, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.2, 0.4)
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	add_child(mesh)
	# Sleep overlay.
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.05, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body is PlayerController:
		_player = body


func _on_exit(body: Node) -> void:
	if body == _player:
		_player = null


func _companion_near() -> bool:
	for c in get_tree().get_nodes_in_group("companion"):
		if _player != null and c is Node3D and (c as Node3D).global_position.distance_to(_player.global_position) < 6.0:
			return true
	return false


func _process(delta: float) -> void:
	var target_alpha := 0.0
	if _player != null:
		var rate := 1.0 - SpiritualStateManager.watchfulness * 0.006
		rate = clampf(rate, 0.25, 1.0)
		if _companion_near():
			rate *= 0.4
			_drowse = max(0.0, _drowse - delta * 0.5)  # the friend's voice rouses
		_drowse += delta * rate
		SpiritualStateManager.modify_state("weariness", 0) # touch, keeps state live
		if _drowse >= threshold:
			_fall_asleep()
		target_alpha = clampf(_drowse / threshold * 0.9, 0.0, 0.9)
	else:
		_drowse = max(0.0, _drowse - delta * 1.5)
		target_alpha = clampf(_drowse / threshold * 0.9, 0.0, 0.9)
	if is_instance_valid(_overlay):
		_overlay.color.a = lerp(_overlay.color.a, target_alpha, delta * 3.0)


func _fall_asleep() -> void:
	_drowse = 0.0
	SpiritualStateManager.apply_effects({"watchfulness": -10, "weariness": 10})
	GameState.set_flag("slept_on_enchanted_ground", true)
	EventBus.toast("You drift to sleep... and wake further back than you began.")
	if _player != null:
		_player.teleport(entry_point)
