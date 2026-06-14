extends Area3D
class_name SafeStone
## Solid footing. Cancels mud penalty and slowly relieves despair while the
## player rests on it. A small island of breathing room.

var _player: PlayerController = null
var _accum: float = 0.0
var relief_interval: float = 3.0


func setup(radius: float = 1.4) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.5
	col.shape = shape
	add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.4
	mesh.mesh = cyl
	mesh.position = Vector3(0, 0.2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.45, 0.55)
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	add_child(mesh)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body is PlayerController:
		_player = body


func _on_exit(body: Node) -> void:
	if body == _player:
		_player = null
		_accum = 0.0


func _process(delta: float) -> void:
	if _player == null:
		return
	_player.terrain_multiplier = 1.0
	_accum += delta
	if _accum >= relief_interval:
		_accum = 0.0
		SpiritualStateManager.modify_state("despair", -1)
