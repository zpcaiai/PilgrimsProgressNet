extends CharacterBody3D
class_name SymbolicEnemy
## A symbolic enemy — fear, shame, despair. It does not drain HP; it attacks
## the pilgrim's inner state and Resolve. It is overcome by the right response
## (faith_guard, prayer, promise) which reduces its "influence" to zero.

signal defeated(enemy_id: String)

var enemy_id: String = "fear_shade"
var display_name: String = "Fear Shade"
var enemy_type: String = "fear"
var influence: float = 60.0
var max_influence: float = 60.0
var move_speed: float = 2.6
var attack_range: float = 2.2
var attack_cooldown: float = 2.5
var weaknesses: Dictionary = {}
var attack_effects: Dictionary = {"fear": 10}
var color: Color = Color(0.3, 0.3, 0.5)

var gravity: float = 18.0
var _cooldown: float = 0.0
var _player: Node3D = null
var _bar: Sprite3D = null


func load_from_data(id: String) -> void:
	var path := "res://data/enemies/" + id + ".json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_apply_data(parsed)


func _apply_data(d: Dictionary) -> void:
	enemy_id = String(d.get("id", enemy_id))
	display_name = String(d.get("display_name", display_name))
	enemy_type = String(d.get("enemy_type", enemy_type))
	influence = float(d.get("influence", influence))
	max_influence = influence
	move_speed = float(d.get("move_speed", move_speed))
	attack_range = float(d.get("attack_range", attack_range))
	attack_cooldown = float(d.get("attack_cooldown", attack_cooldown))
	weaknesses = d.get("weaknesses", {})
	attack_effects = d.get("attack_effects", attack_effects)
	if d.has("color"):
		var c: Array = d["color"]
		if c.size() >= 3:
			color = Color(c[0], c[1], c[2])
	# Children's Journey: foes are weaker, slower, and strike less often.
	if GameState.is_child_mode():
		influence = max(1.0, influence * 0.5)
		max_influence = influence
		move_speed *= 0.8
		attack_cooldown *= 1.6


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	_build_visual()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	# Visual: a painted figure billboard when one exists for this foe (e.g.
	# Apollyon, Giant Despair), else the emissive capsule greybox.
	var fig := AssetLib.figure(display_name)
	if fig != null:
		add_child(CharacterBillboard.make(fig, 2.1))
	else:
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.45
		capsule.height = 1.7
		mesh.mesh = capsule
		mesh.position = Vector3(0, 0.9, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
		mesh.material_override = mat
		add_child(mesh)
	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 2.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.outline_size = 6
	add_child(label)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _player == null or not is_instance_valid(_player):
		move_and_slide()
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	if dist > attack_range:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0
		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = attack_cooldown
			_attack()
	move_and_slide()


func _attack() -> void:
	SpiritualStateManager.apply_effects(attack_effects)
	var combats := get_tree().get_nodes_in_group("player_combat")
	if combats.size() > 0:
		combats[0].take_hit(attack_effects, enemy_type)
	EventBus.toast(display_name + " presses in against you.")


func get_weakness_multiplier(source_type: String) -> float:
	return float(weaknesses.get(source_type, 1.0))


func receive_counter(source_type: String, amount: float) -> void:
	var dealt := amount * get_weakness_multiplier(source_type)
	influence -= dealt
	if influence <= 0.0:
		on_defeated()


func on_defeated() -> void:
	defeated.emit(enemy_id)
	EventBus.toast(display_name + " loses its grip on you.")
	queue_free()
