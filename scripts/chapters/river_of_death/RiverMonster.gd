extends Node3D
class_name RiverMonster
## The creature of the River of Death — a serpentine leviathan, half-submerged,
## that surfaces to BAR the crossing and LUNGES at the pilgrim's heart (fear,
## despair). It is symbolic and never lethal: it cannot drain life, only press
## the inner state. When faith outweighs fear — or Hopeful's encouragement and
## the remembered promise take hold — it sinks back beneath the water and the
## way opens. Spawned by ImportedSceneBinder from the ENEMY_RiverMonster marker.

const STRIKE_RANGE := 4.6
const INTERCEPT_LEAD := 3.0      # how far ahead of the pilgrim it plants itself
const GLIDE_SPEED := 2.4
const WATER_Y := 0.9             # the river surface it rides at
const Z_MIN := -16.0             # stays within the deep channel
const Z_MAX := 1.0
const X_LIMIT := 20.0

var _player: Node3D = null
var _swimmer: Node3D = null      # the part that undulates
var _head: Node3D = null
var _humps: Array = []
var _t: float = 0.0
var _cooldown: float = 2.0
var _attack_cooldown: float = 2.8
var _receding: bool = false
var _press_time: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	position.y = WATER_Y
	if GameState.is_child_mode():
		_attack_cooldown = 4.2
	_build_visual()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _foe_mat(c: Color, emis: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission = c.lightened(0.1)
	m.emission_energy_multiplier = emis
	return m


func _build_visual() -> void:
	_swimmer = Node3D.new()
	add_child(_swimmer)
	var scale_c := Color(0.10, 0.16, 0.17)
	var body_mat := _foe_mat(scale_c, 0.35)

	# Head: an elongated maw facing +Z (the root yaws to aim it at the pilgrim).
	_head = Node3D.new()
	_head.position = Vector3(0, 0.1, 2.2)
	_swimmer.add_child(_head)
	var skull := MeshInstance3D.new()
	var sk := SphereMesh.new()
	sk.radius = 0.85
	sk.height = 1.7
	skull.mesh = sk
	skull.scale = Vector3(1.0, 0.8, 1.7)
	skull.material_override = body_mat
	_head.add_child(skull)
	# Jaw
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(1.0, 0.28, 1.5)
	jaw.mesh = jm
	jaw.position = Vector3(0, -0.45, 0.5)
	jaw.material_override = body_mat
	_head.add_child(jaw)
	# Two cold glowing eyes.
	var eye_mat := _foe_mat(Color(0.9, 0.85, 0.4), 2.4)
	for sx in [-0.42, 0.42]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.16
		em.height = 0.32
		eye.mesh = em
		eye.position = Vector3(sx, 0.28, 0.7)
		eye.material_override = eye_mat
		_head.add_child(eye)
	# Brow horns sweeping back.
	for sx in [-0.4, 0.4]:
		var horn := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.14
		cm.height = 0.9
		horn.mesh = cm
		horn.position = Vector3(sx, 0.5, -0.1)
		horn.rotation = Vector3(deg_to_rad(-50), 0, 0)
		horn.material_override = body_mat
		_head.add_child(horn)

	# Coiled back humps trailing behind (-Z), each a little lower / smaller, so the
	# beast reads as a long serpent looping through the surface.
	var z := 0.9
	var r := 0.95
	for i in range(5):
		var hump := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = r
		hm.height = r * 2.0
		hump.mesh = hm
		hump.position = Vector3(0, -0.05 - i * 0.04, z)
		hump.material_override = body_mat
		_swimmer.add_child(hump)
		_humps.append(hump)
		z -= r * 1.35
		r *= 0.82
	# Tail tip.
	var tail := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.02
	tm.bottom_radius = 0.32
	tm.height = 1.6
	tail.mesh = tm
	tail.position = Vector3(0, -0.2, z)
	tail.rotation = Vector3(deg_to_rad(90), 0, 0)
	tail.material_override = body_mat
	_swimmer.add_child(tail)


func _process(delta: float) -> void:
	_t += delta
	# Undulate: each hump rides a travelling sine wave; the whole beast bobs on
	# the surface. (Runs even while receding, so the sink looks alive.)
	for i in range(_humps.size()):
		var h: MeshInstance3D = _humps[i]
		if is_instance_valid(h):
			var base_y := -0.05 - i * 0.04
			h.position.y = base_y + sin(_t * 3.0 - i * 0.7) * 0.18
			h.position.x = sin(_t * 2.0 - i * 0.9) * 0.25
	if is_instance_valid(_swimmer):
		_swimmer.position.y = sin(_t * 1.6) * 0.08

	if _receding:
		return
	if _player == null or not is_instance_valid(_player):
		return

	# --- recede when faith prevails (or mercy is remembered) -> the way opens ---
	var fear := float(SpiritualStateManager.fear)
	var faith := float(SpiritualStateManager.faith)
	_press_time += delta
	var player_past: bool = _player.global_position.z <= -15.0
	if GameState.has_flag("crossed_river") or player_past \
			or GameState.is_child_mode() \
			or GameState.has_flag("river_memory_recalled") \
			or (faith > fear + 6.0) or fear <= 16.0 \
			or _press_time >= 26.0:
		_recede()
		return

	# --- intercept: plant itself just ahead of the pilgrim, barring the lane ---
	var pp: Vector3 = _player.global_position
	var tx: float = clampf(pp.x, -X_LIMIT, X_LIMIT)
	var tz: float = clampf(pp.z - INTERCEPT_LEAD, Z_MIN, Z_MAX)
	var target := Vector3(tx, WATER_Y, tz)
	var to_t := target - global_position
	to_t.y = 0.0
	if to_t.length() > 0.2:
		var step: float = minf(GLIDE_SPEED * delta, to_t.length())
		global_position += to_t.normalized() * step
	global_position.y = WATER_Y

	# Face the pilgrim so the maw is turned toward him.
	var to_p: Vector3 = pp - global_position
	to_p.y = 0.0
	if to_p.length() > 0.05:
		var yaw := atan2(to_p.x, to_p.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 5.0, 0.0, 1.0))

	# --- attack the heart on cooldown when the pilgrim is within reach ---
	_cooldown -= delta
	if to_p.length() <= STRIKE_RANGE and _cooldown <= 0.0:
		_cooldown = _attack_cooldown
		_attack()


func _attack() -> void:
	# A lunge: the head darts forward and snaps back.
	if is_instance_valid(_head):
		var base := _head.position
		var tw := create_tween()
		tw.tween_property(_head, "position", base + Vector3(0, -0.2, 1.4), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_head, "position", base, 0.32).set_trans(Tween.TRANS_SINE)

	# Symbolic, non-lethal: it presses fear / despair and steals a little hope. The
	# rising fear makes the water (RiverWaterZone) pull harder — so the crossing
	# stalls — but life is never drained, and faith reverses it.
	var effects := {"fear": 7, "despair": 4, "hope": -4}
	SpiritualStateManager.apply_effects(effects)
	var combats := get_tree().get_nodes_in_group("player_combat")
	if combats.size() > 0 and combats[0].has_method("take_hit"):
		combats[0].take_hit(effects, "fear")
	_spawn_splash(14, global_position + Vector3(0, 0, 0.5))
	EventBus.toast("河怪缠住你，冰冷的水没过胸口。抓住信心，向前一步。(The river-beast coils close; cold water rises. Take faith, and step on.)")


## Sink beneath the water and dissolve away — faith has carried the pilgrim past.
func _recede() -> void:
	if _receding:
		return
	_receding = true
	GameState.set_flag("river_monster_passed", true)
	EventBus.toast("你想起那城仍未挪移；河怪在水下退去，去路敞开了。(You remember the City has not moved; the beast sinks away, and the way opens.)")
	# A great cold splash as faith drives it under and the water closes over it.
	_spawn_splash(46, global_position)
	if not Settings.reduce_motion:
		Juice.shake(0.28)
	var tw := create_tween()
	tw.tween_property(self, "position:y", WATER_Y - 3.5, 2.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector3(0.6, 0.6, 0.6), 2.4)
	tw.tween_callback(queue_free)


## A burst of water: droplets thrown up + an expanding ripple disc on the surface.
## Parented to the chapter (not self), so it outlives the monster's own freeing.
func _spawn_splash(amount: int, at: Vector3) -> void:
	var host := get_parent()
	if host == null:
		host = self
	# Droplets
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.95
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 52.0
	p.initial_velocity_min = 2.6
	p.initial_velocity_max = 5.8
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var dm := SphereMesh.new()
	dm.radius = 0.08
	dm.height = 0.16
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.72, 0.86, 0.96)
	dmat.emission_enabled = true
	dmat.emission = Color(0.4, 0.62, 0.82)
	dmat.emission_energy_multiplier = 0.5
	dm.material = dmat
	p.mesh = dm
	host.add_child(p)
	p.global_position = Vector3(at.x, WATER_Y + 0.1, at.z)
	var tree := get_tree()
	if tree != null:
		tree.create_timer(1.5).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())
	# Expanding ripple disc (a thin flat cylinder), fading as it spreads.
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.8
	rm.bottom_radius = 0.8
	rm.height = 0.04
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.6, 0.8, 0.95, 0.45)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = Color(0.5, 0.72, 0.92)
	rmat.emission_energy_multiplier = 0.35
	ring.material_override = rmat
	host.add_child(ring)
	ring.global_position = Vector3(at.x, WATER_Y, at.z)
	var clear := rmat.albedo_color
	clear.a = 0.0
	var grow: float = 5.0 if amount > 30 else 2.6
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(grow, 1.0, grow), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "material_override:albedo_color", clear, 0.8)
	tw.tween_callback(ring.queue_free)
