extends Area3D
class_name FalseGround
## Ground that looks solid but collapses shortly after the player steps on it,
## dropping them and spiking despair/fear. High discernment reveals a warning
## shimmer before the player commits.

var collapse_delay: float = 0.8
var fall_effects: Dictionary = {"despair": 8, "fear": 5}
var _triggered: bool = false
var _mesh: MeshInstance3D
var _warning: MeshInstance3D


func setup(size: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.28)
	_mesh.material_override = mat
	add_child(_mesh)
	# Warning shimmer (only visible to the discerning)
	_warning = MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(size.x, 0.05, size.z)
	_warning.mesh = wm
	_warning.position = Vector3(0, size.y * 0.5 + 0.05, 0)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.9, 0.4, 0.4, 0.5)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(1.0, 0.5, 0.5)
	wmat.emission_energy_multiplier = 1.0
	_warning.material_override = wmat
	_warning.visible = false
	add_child(_warning)
	body_entered.connect(_on_enter)


func _process(_delta: float) -> void:
	if is_instance_valid(_warning):
		_warning.visible = SpiritualStateManager.discernment >= 30 and not _triggered


func _on_enter(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	await get_tree().create_timer(collapse_delay).timeout
	if is_instance_valid(_mesh):
		_mesh.visible = false
	# Disable collision so the player drops.
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	SpiritualStateManager.apply_effects(fall_effects)
	EventBus.toast("脚下的地忽然塌陷！")
