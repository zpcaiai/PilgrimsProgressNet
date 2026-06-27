extends Node3D
class_name ArrowEmitter
## Fires symbolic "arrows of accusation" toward the player. They are avoidable;
## standing still gets you hit. A hit raises fear/shame briefly. Meant to create
## urgency at the Wicket Gate, not to punish.

var fire_interval: float = 1.6
var arrow_speed: float = 11.0
var effects_on_hit: Dictionary = {"fear": 5, "shame": 3}
var active: bool = true
var _timer: float = 0.0
var _player: Node3D = null


func setup(target_player: Node3D) -> void:
	_player = target_player
	# Children's Journey: arrows are rarer and slower, easy to walk past.
	if GameState.is_child_mode():
		fire_interval *= 1.9
		arrow_speed *= 0.8


func _process(delta: float) -> void:
	if not active or _player == null or not is_instance_valid(_player):
		return
	_timer += delta
	if _timer >= fire_interval:
		_timer = 0.0
		_fire()


func _fire() -> void:
	var arrow := Area3D.new()
	arrow.collision_layer = 0
	arrow.collision_mask = 1
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.9)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.2, 0.5)
	mat.emission_energy_multiplier = 1.0
	mesh.material_override = mat
	arrow.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.9)
	col.shape = box
	arrow.add_child(col)
	add_child(arrow)
	arrow.global_position = global_position
	var dir := (_player.global_position + Vector3(0, 0.9, 0) - global_position).normalized()
	arrow.look_at(_player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	arrow.body_entered.connect(func(body):
		if body.is_in_group("player"):
			SpiritualStateManager.apply_effects(effects_on_hit)
			EventBus.toast("一支控告之箭击中了你。")
			arrow.queue_free()
	)
	# Move the arrow over its lifetime.
	var lifetime := 3.0
	var tween := create_tween()
	tween.tween_property(arrow, "global_position", global_position + dir * arrow_speed * lifetime, lifetime)
	tween.tween_callback(_free_arrow.bind(arrow))


func _free_arrow(arrow: Node) -> void:
	if is_instance_valid(arrow):
		arrow.queue_free()
