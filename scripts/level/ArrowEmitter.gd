extends Node3D
class_name ArrowEmitter
## Fires symbolic "arrows of accusation" toward the player. They are avoidable;
## standing still gets you hit. A hit raises fear/shame briefly. Meant to create
## urgency at the Wicket Gate, not to punish.

var fire_interval: float = 1.6
var arrow_speed: float = 11.0
var effects_on_hit: Dictionary = {"fear": 5, "shame": 3}
var pressure_level: int = 0
var active: bool = true
var _timer: float = 0.0
var _player: Node3D = null

const ARROW_TYPES := {
	"fear": {
		"effects": {"fear": 8},
		"line": "惧怕之箭：你真的能进去吗？",
		"color": Color(0.95, 0.34, 0.22),
	},
	"shame": {
		"effects": {"shame": 8, "hope": -2},
		"line": "羞耻之箭：你不配靠近。",
		"color": Color(0.72, 0.28, 0.18),
	},
	"doubt": {
		"effects": {"doubt": 8, "faith": -2},
		"line": "疑惑之箭：这条路是真的吗？",
		"color": Color(0.42, 0.36, 0.9),
	},
	"delay": {
		"effects": {"weariness": 6, "perseverance": -2},
		"line": "拖延之箭：以后再叩门也不迟。",
		"color": Color(0.95, 0.62, 0.18),
	},
	"self_righteousness": {
		"effects": {"pride": 7, "humility": -2},
		"line": "自义之箭：你已经比别人好多了。",
		"color": Color(0.95, 0.86, 0.35),
	},
}


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
	var arrow_type := _pick_arrow_type()
	var spec: Dictionary = ARROW_TYPES[arrow_type]
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
	mat.emission = spec["color"]
	mat.emission_energy_multiplier = 1.9
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
			if _player_shield_blocks(body, arrow_type):
				pressure_level = maxi(0, pressure_level - 14)
			else:
				pressure_level = mini(100, pressure_level + 12)
				SpiritualStateManager.apply_effects(spec["effects"])
				EventBus.toast("%s  压力 %d/100" % [String(spec["line"]), pressure_level])
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


func _pick_arrow_type() -> String:
	var keys := ARROW_TYPES.keys()
	return String(keys[randi() % keys.size()])


func _player_shield_blocks(body: Node, arrow_type: String) -> bool:
	for child in body.get_children():
		if child.has_method("is_active") and child.has_method("absorb_arrow") and child.is_active():
			child.absorb_arrow(arrow_type)
			return true
	return false
