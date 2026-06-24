extends Area3D
class_name MudZone
## A hazard zone. While the player stands in it, movement is slowed and
## negative spiritual states tick up. Deep mud can drive the pilgrim toward
## collapse. Built procedurally via setup().

var movement_multiplier: float = 0.7
var effects_per_tick: Dictionary = {"despair": 1, "weariness": 1}
var tick_interval: float = 2.0
var is_deep: bool = false
var _player: PlayerController = null
var _accum: float = 0.0
var _tick_count: int = 0


## True while the pilgrim is standing in this mud (read by MudSystem to drive
## the visual sinking + footprints).
func is_occupied() -> bool:
	return _player != null


func setup(size: Vector3, deep: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	is_deep = deep
	add_to_group("mud_zone")
	if deep:
		movement_multiplier = 0.45
		effects_per_tick = {"despair": 2, "fear": 1, "hope": -1}
	# Collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	# Visual (translucent surface; tint overrides the default muck colour)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.15, size.z)
	mesh.mesh = bm
	mesh.position = Vector3(0, -size.y * 0.5 + 0.08, 0)
	var mat := StandardMaterial3D.new()
	if tint.a > 0.0:
		mat.albedo_color = tint
	else:
		mat.albedo_color = Color(0.18, 0.22, 0.18, 0.85) if deep else Color(0.3, 0.32, 0.26, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mesh.material_override = mat
	add_child(mesh)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body is PlayerController:
		_player = body
		_player.terrain_multiplier = movement_multiplier


func _on_exit(body: Node) -> void:
	if body == _player and _player != null:
		_player.terrain_multiplier = 1.0
		_player = null
		_accum = 0.0
		_tick_count = 0


func _process(delta: float) -> void:
	if _player == null:
		return
	_accum += delta
	if _accum >= tick_interval:
		_accum = 0.0
		SpiritualStateManager.apply_effects(effects_per_tick)
		_tick_count += 1
		if _tick_count % 2 == 1:
			EventBus.toast("绝望从泥里渗上来，脚步更沉。")
